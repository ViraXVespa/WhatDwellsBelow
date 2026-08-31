extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")
const PauseInv := preload("res://scripts/ui/pause_inv.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")

const SKILL_NAMES := {
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

const SLOT_NAMES := {
	"weapon": "Weapon",
	"tool": "Tool",
	"potion": "Potion",
	"food": "Food",
	"head": "Head",
	"body": "Body",
	"legs": "Legs",
}

const BAG_COLS := 7

var open: bool = false
var tab: int = 0
var box: VBoxContainer
var tabs: HBoxContainer
var scroll: ScrollContainer
var status: Label
var focus_btn: Control
var pending: bool = false
var pending_id: String = ""
var pending_fn: Callable
var rebind_action: String = ""
var sys_page: String = "main"
var tip_host: PanelContainer
var tip_lab: Label
var tip_id: String = ""
var tip_kind: String = ""
var tip_from: Control = null
var inv_sel: String = ""
var inv_detail: Label
var inv_btn_use: Button
var inv_btn_equip: Button
var inv_btn_unequip: Button
var inv_btn_drop: Button


func _ready() -> void:
	layer = 55
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.78)
	add_child(dim)
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.13, 0.1, 0.08, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	add_child(panel)
	var edge: ColorRect = ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	add_child(edge)
	tabs = HBoxContainer.new()
	tabs.position = Vector2(244, 60)
	tabs.size = Vector2(1432, 56)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(244, 128)
	scroll.size = Vector2(1432, 880)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.follow_focus = true
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1400, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_make_tip()


func _make_tip() -> void:
	tip_host = PanelContainer.new()
	tip_host.visible = false
	tip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_host.z_index = 20
	tip_host.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	tip_lab = Label.new()
	tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lab.custom_minimum_size = Vector2(380, 0)
	tip_lab.add_theme_font_size_override("font_size", 18)
	tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	tip_lab.add_theme_constant_override("outline_size", 6)
	tip_host.add_child(tip_lab)
	add_child(tip_host)


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
	inv_sel = "slot:weapon"
	_hide_tip()
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	_hide_tip()
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()


func _rebuild() -> void:
	_hide_tip()
	for c: Node in tabs.get_children():
		c.queue_free()
	for c2: Node in box.get_children():
		c2.queue_free()
	focus_btn = null
	status = null
	inv_detail = null
	inv_btn_use = null
	inv_btn_equip = null
	inv_btn_unequip = null
	inv_btn_drop = null
	var names: PackedStringArray = PackedStringArray(["Inventory", "Skills", "System"])
	for i: int in 3:
		var ii: int = i
		var b: Button = ThemeS.btn(names[i], func():
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
	if tab == 0:
		var hit: Control = _inv_find_sel()
		if hit:
			hit.grab_focus()
			return
	if focus_btn:
		focus_btn.grab_focus()
		return
	for n: Node in find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


func _cap(text: String, size: int = 18, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	var l: Label = Label.new()
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
	PauseInv.build(self)


func _inv_find_sel() -> Control:
	return PauseInv.find_sel(self)


func _inv_use() -> void:
	PauseInv.use_item(self)


func _inv_equip() -> void:
	PauseInv.equip_item(self)


func _inv_unequip() -> void:
	PauseInv.unequip_item(self)


func _inv_drop() -> void:
	PauseInv.drop_item(self)


func kind_extract_note(it: Dictionary) -> String:
	return PauseInv.extract_note(it)


func _skills() -> void:
	PauseSkills.build(self)


func _on_skill_focus(id: String, kind: String, from: Control) -> void:
	if from is PanelContainer:
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(true))
	tip_id = id
	tip_kind = kind
	tip_from = from
	_paint_tip()


func _on_skill_blur(from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	call_deferred("_blur_tip")


func _blur_tip() -> void:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	_hide_tip()


func _hide_tip() -> void:
	tip_id = ""
	tip_kind = ""
	tip_from = null
	if tip_host:
		tip_host.visible = false


func _paint_tip() -> void:
	PauseSkills.paint_tip(self)


func _system() -> void:
	if sys_page == "rebind":
		_rebind()
		return
	box.add_child(_cap("System", 24, Color(0.95, 0.8, 0.45)))
	var char_btn: Button = ThemeS.btn("Character: %s" % App.character_type, func():
		var nxt: String = "female" if App.character_type == "male" else "male"
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
		for raw: Variant in binds:
			if raw is Dictionary:
				var d: Dictionary = raw
				var act: String = str(d.get("action", d.get("id", "")))
				var lab: String = str(d.get("label", act))
				var cur: String = str(d.get("bind", d.get("key", "")))
				var a2: String = act
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
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(720, 0)
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_cap(title, 20, Color(0.9, 0.84, 0.7)))
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


func _confirm(fn: Callable, id: String = "anon") -> void:
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
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
		get_viewport().set_input_as_handled()
