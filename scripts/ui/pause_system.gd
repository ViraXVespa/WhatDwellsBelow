extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")


static func build(ui: CanvasLayer) -> void:
	if ui.sys_page == "rebind":
		rebind(ui)
		return
	ui.box.add_child(ui._cap("System", 24, Color(0.95, 0.8, 0.45)))
	var char_btn: Button = ThemeS.btn("Character: %s" % App.character_type, func():
		var nxt: String = "female" if App.character_type == "male" else "male"
		if App.has_method("set_character"):
			App.set_character(nxt)
		else:
			App.character_type = nxt
		App.save_now()
		ui._rebuild()
	)
	ui.box.add_child(char_btn)
	ui.focus_btn = char_btn
	ui.box.add_child(slider_row(ui, "Master volume", App.vol_master, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("master", v)
	))
	ui.box.add_child(slider_row(ui, "Music volume", App.vol_music, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("music", v)
	))
	ui.box.add_child(slider_row(ui, "SFX volume", App.vol_sfx, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("sfx", v)
	))
	ui.box.add_child(slider_row(ui, "Camera zoom", App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float):
		if App.has_method("set_zoom"):
			App.set_zoom(v)
		else:
			App.cam_zoom = v
	))
	ui.box.add_child(slider_row(ui, "HUD scale", App.hud_scale, 0.7, 1.4, 0.05, func(v: float):
		if App.has_method("set_hud_scale"):
			App.set_hud_scale(v)
		else:
			App.hud_scale = v
	))
	ui.box.add_child(ThemeS.btn("Sprite filter: %s" % SpriteFilt.label(SpriteFilt.clamp_id(int(App.sprite_filter), false)), func():
		App.set_sprite_filter(SpriteFilt.cycle_sys(int(App.sprite_filter), 1), false)
		App.save_now()
		ui._rebuild()
	))
	ui.box.add_child(ThemeS.btn("Aim line: %s" % ("On" if App.bal.aim_line_on else "Off"), func():
		App.bal.aim_line_on = not App.bal.aim_line_on
		App.save_now()
		ui._rebuild()
	))
	ui.box.add_child(slider_row(ui, "Aim line opacity", App.bal.aim_line_opacity, 0.05, 1.0, 0.05, func(v: float):
		App.bal.aim_line_opacity = v
	))
	if App.in_dungeon:
		ui.box.add_child(ThemeS.btn("Dispel Avatar", func():
			confirm(ui, func():
				ui.close_ui()
				App.end_run("dispel")
			, "dispel")
		))
	ui.box.add_child(ThemeS.btn("Archives", func():
		if App.archives_ui and App.archives_ui.has_method("show_browser"):
			App.archives_ui.show_browser()
	))
	ui.box.add_child(ThemeS.btn("Rebind controls", func():
		ui.sys_page = "rebind"
		ui._rebuild()
	))
	if App.has_method("reset_binds"):
		ui.box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			ui._st("Binds reset.")
		))
	ui.box.add_child(ThemeS.btn("Patreon", func():
		OS.shell_open("https://www.patreon.com/cw/ViraXVespa")
	))
	ui.box.add_child(ThemeS.btn("Delete Save Data", func():
		confirm(ui, func():
			App.wipe_save()
			ui.close_ui()
			App.go_title()
		, "wipe")
	))
	ui.status = ui._cap("A again to confirm a marked action. B cancels.", 16, Color(0.78, 0.74, 0.66))
	ui.box.add_child(ui.status)
	ui.box.add_child(ThemeS.btn("Close  (B)", ui.close_ui))


static func rebind(ui: CanvasLayer) -> void:
	ui.box.add_child(ui._cap("Rebind controls", 24, Color(0.95, 0.8, 0.45)))
	ui.box.add_child(ui._cap("Highlight an action, press A, then the new key or button.", 18, Color(0.82, 0.76, 0.66)))
	var binds: Array = []
	if App.has_method("collect_binds"):
		binds = App.collect_binds()
	var first_btn: Button = null
	if binds.is_empty():
		ui.box.add_child(ui._cap("No bind list exposed.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for raw: Variant in binds:
			if raw is Dictionary:
				var d: Dictionary = raw
				var act: String = str(d.get("action", d.get("id", "")))
				var lab: String = str(d.get("label", act))
				var cur: String = str(d.get("bind", d.get("key", "")))
				var a2: String = act
				var row: Button = ThemeS.btn("%s   [%s]" % [lab, cur], func():
					ui.rebind_action = a2
					ui._st("Press a key or button for %s." % lab)
				)
				ui.box.add_child(row)
				if first_btn == null:
					first_btn = row
	if App.has_method("reset_binds"):
		ui.box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			ui._rebuild()
		))
	var back: Button = ThemeS.btn("Back", func():
		ui.sys_page = "main"
		ui.rebind_action = ""
		ui._rebuild()
	)
	ui.box.add_child(back)
	ui.focus_btn = first_btn if first_btn else back
	ui.status = ui._cap("", 16, Color(0.78, 0.74, 0.66))
	ui.box.add_child(ui.status)


static func slider_row(ui: CanvasLayer, title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(720, 0)
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(ui._cap(title, 20, Color(0.9, 0.84, 0.7)))
	var sl: HSlider = HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(720, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	wrap.add_child(sl)
	return wrap


static func confirm(ui: CanvasLayer, fn: Callable, id: String = "anon") -> void:
	if not ui.pending or ui.pending_id != id:
		ui.pending = true
		ui.pending_id = id
		ui.pending_fn = fn
		ui._st("A again to confirm. B cancels.")
		return
	ui.pending = false
	ui.pending_id = ""
	fn.call()
