extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")

var open := false
var tab := 0
var box: VBoxContainer
var tabs: HBoxContainer
var status: Label
var focus_btn: Button
var pending := false
var pending_id := ""
var pending_fn: Callable
var rebind_action := ""
var sys_page := "main"


func _ready() -> void:
	layer = 55
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.78)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	add_child(edge)
	tabs = HBoxContainer.new()
	tabs.position = Vector2(244, 60)
	tabs.size = Vector2(1432, 56)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(244, 128)
	scroll.size = Vector2(1432, 880)
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1400, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)


func toggle() -> void:
	if open:
		close_ui()
	else:
		show_menu()


func show_menu() -> void:
	open = true
	visible = true
	App.ui_open = true
	get_tree().paused = true
	tab = 0
	sys_page = "main"
	pending = false
	pending_id = ""
	rebind_action = ""
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()


func _rebuild() -> void:
	for c in tabs.get_children():
		c.queue_free()
	for c in box.get_children():
		c.queue_free()
	focus_btn = null
	status = null
	var names := ["Inventory", "Skills", "System"]
	for i in 3:
		var ii := i
		var b := ThemeS.btn(names[i], func():
			tab = ii
			sys_page = "main"
			_rebuild()
		)
		if i == tab:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		tabs.add_child(b)
		if focus_btn == null:
			focus_btn = b
	match tab:
		0:
			_inv()
		1:
			_skills()
		_:
			_system()
	call_deferred("_focus")


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()
		return
	for n in find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


func _cap(text: String, size := 18, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(520, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _inv() -> void:
	box.add_child(_cap("Carried  %dg   %d ore   %d wood   bag %d/%d" % [
		App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)
	], 22, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Equipped", 20, Color(0.88, 0.82, 0.7)))
	for s in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		var line := "%s  —  empty" % str(s)
		if not it.is_empty():
			line = "%s  —  %s" % [str(s), str(it.get("name", s))]
			var extra := str(it.get("desc", ""))
			if extra != "":
				line += "   " + extra
		box.add_child(_cap(line, 18, Color(0.86, 0.8, 0.68)))
	box.add_child(_cap("Bag", 20, Color(0.88, 0.82, 0.7)))
	if App.prog.bag.is_empty():
		box.add_child(_cap("Nothing in the bag.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for it in App.prog.bag:
			var nm := str(it.get("name", "item"))
			if bool(it.get("hold", false)):
				nm += "  (hold)"
			box.add_child(_cap(nm, 18, Color(0.86, 0.8, 0.68)))
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _skills() -> void:
	var names := {
		"axe": "Great Axe",
		"staff": "Staff",
		"bow": "Longbow",
		"str": "Strength",
		"mag": "Magic",
		"rng": "Ranged",
		"def": "Defense",
		"hp": "Hitpoints",
		"mine": "Mining",
		"wood": "Woodcutting",
		"smith": "Smithing",
	}
	box.add_child(_cap("Combat Level %d" % App.prog.combat_lv(), 24, Color(0.95, 0.8, 0.45)))
	var span := maxf(1.0, App.bal.xp_level)
	for id in App.prog.SKILLS:
		var wrap := VBoxContainer.new()
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_theme_constant_override("separation", 4)
		box.add_child(wrap)
		var runx := float(App.prog.skills_run.get(id, 0.0))
		var perm := float(App.prog.skills_perm.get(id, 0.0))
		var lv := App.prog.skill_lv(id)
		wrap.add_child(_cap("%s	Lv %d	run %.0f	perm %.0f" % [
			names.get(id, id), lv, runx, perm
		], 18, Color(0.9, 0.84, 0.7)))
		var track := ColorRect.new()
		track.custom_minimum_size = Vector2(720, 16)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.color = Color(0.18, 0.14, 0.1)
		wrap.add_child(track)
		var fill := ColorRect.new()
		var into := fmod(runx + perm, span)
		fill.position = Vector2.ZERO
		fill.size = Vector2(720.0 * clampf(into / span, 0.0, 1.0), 16)
		fill.color = Color(0.72, 0.56, 0.28)
		track.add_child(fill)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _system() -> void:
	if sys_page == "rebind":
		_rebind()
		return
	box.add_child(_cap("System", 24, Color(0.95, 0.8, 0.45)))
	var char_btn := ThemeS.btn("Character: %s" % App.character_type, func():
		var nxt := "female" if App.character_type == "male" else "male"
		if App.has_method("set_character"):
			App.set_character(nxt)
		else:
			App.character_type = nxt
		App.save_now()
		_rebuild()
	)
	box.add_child(char_btn)
	box.add_child(_slider_row("Master volume", App.vol_master, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("master", v)
	))
	box.add_child(_slider_row("Music volume", App.vol_music, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("music", v)
	))
	box.add_child(_slider_row("SFX volume", App.vol_sfx, 0.0, 1.0, 0.01, func(v: float):
		App.set_volume("sfx", v)
	))
	box.add_child(_slider_row("Camera zoom", App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float):
		App.cam_zoom = v
	))
	box.add_child(_slider_row("HUD scale", App.hud_scale, 0.7, 1.4, 0.05, func(v: float):
		App.hud_scale = v
	))
	box.add_child(ThemeS.btn("Aim line: %s" % ("On" if App.bal.aim_line_on else "Off"), func():
		App.bal.aim_line_on = not App.bal.aim_line_on
		App.save_now()
		_rebuild()
	))
	box.add_child(_slider_row("Aim line opacity", App.bal.aim_line_opacity, 0.05, 1.0, 0.05, func(v: float):
		App.bal.aim_line_opacity = v
	))
	if App.in_dungeon:
		box.add_child(ThemeS.btn("Dispel Avatar", func():
			_confirm(func():
				close_ui()
				App.end_run("dispel")
			, "dispel")
		))
	box.add_child(ThemeS.btn("Archives", func():
		if App.archives_ui and App.archives_ui.has_method("show_browser"):
			App.archives_ui.show_browser()
	))
	box.add_child(ThemeS.btn("Rebind controls", func():
		sys_page = "rebind"
		_rebuild()
	))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_st("Binds reset.")
		))
	box.add_child(ThemeS.btn("Patreon", func():
		OS.shell_open("https://www.patreon.com/cw/ViraXVespa")
	))
	box.add_child(ThemeS.btn("Delete Save Data", func():
		_confirm(func():
			App.wipe_save()
			close_ui()
			App.go_title()
		, "wipe")
	))
	status = _cap("A again to confirm a marked action. B cancels.", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)
	box.add_child(ThemeS.btn("Close  (B)", close_ui))


func _rebind() -> void:
	box.add_child(_cap("Rebind controls", 24, Color(0.95, 0.8, 0.45)))
	box.add_child(_cap("Highlight an action, press A, then the new key or button.", 18, Color(0.82, 0.76, 0.66)))
	var binds: Array = []
	if App.has_method("collect_binds"):
		binds = App.collect_binds()
	if binds.is_empty():
		box.add_child(_cap("No bind list exposed.", 18, Color(0.7, 0.66, 0.6)))
	else:
		for raw in binds:
			if raw is Dictionary:
				var d: Dictionary = raw
				var act := str(d.get("action", d.get("id", "")))
				var lab := str(d.get("label", act))
				var cur := str(d.get("bind", d.get("key", "")))
				var a2 := act
				box.add_child(ThemeS.btn("%s   [%s]" % [lab, cur], func():
					rebind_action = a2
					_st("Press a key or button for %s." % lab)
				))
	if App.has_method("reset_binds"):
		box.add_child(ThemeS.btn("Reset binds", func():
			App.reset_binds()
			App.save_now()
			_rebuild()
		))
	box.add_child(ThemeS.btn("Back", func():
		sys_page = "main"
		rebind_action = ""
		_rebuild()
	))
	status = _cap("", 16, Color(0.78, 0.74, 0.66))
	box.add_child(status)


func _slider_row(title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(720, 0)
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_cap(title, 20, Color(0.9, 0.84, 0.7)))
	var sl := HSlider.new()
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


func _confirm(fn: Callable, id := "anon") -> void:
	if not pending or pending_id != id:
		pending = true
		pending_id = id
		pending_fn = fn
		_st("A again to confirm. B cancels.")
		return
	pending = false
	pending_id = ""
	fn.call()


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _input(event: InputEvent) -> void:
	if not open or rebind_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if App.has_method("rebind"):
			App.rebind(rebind_action, event)
		rebind_action = ""
		App.save_now()
		_rebuild()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return
	if event.is_action_pressed("tab_right"):
		tab = (tab + 1) % 3
		sys_page = "main"
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_left"):
		tab = (tab + 2) % 3
		sys_page = "main"
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if pending:
			pending = false
			pending_id = ""
			App.sfx("ui_cancel")
			_st("Cancelled.")
		elif sys_page == "rebind":
			sys_page = "main"
			rebind_action = ""
			App.sfx("ui_cancel")
			_rebuild()
		else:
			App.sfx("ui_cancel")
			close_ui()
		get_viewport().set_input_as_handled()