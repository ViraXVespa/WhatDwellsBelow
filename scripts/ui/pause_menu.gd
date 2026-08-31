extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")
const PauseInv := preload("res://scripts/ui/pause_inv.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const PauseSys := preload("res://scripts/ui/pause_system.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board.gd")

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
var gear_mode: String = "inv"
var gear_stat_page: int = 0
var gear_tip_mode: int = 1
var gear_sub: bool = false
var gear_sub_slot: String = ""
var gear_x_hold: float = 0.0
var gear_x_fired: bool = false
var gear_tip: Label
var gear_tip_host: PanelContainer
var gear_stats: Control
var gear_stats_title: Label
var gear_hint: Label


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
	gear_mode = "inv"
	gear_sub = false
	gear_sub_slot = ""
	_hide_tip()
	_rebuild()


func close_ui() -> void:
	open = false
	visible = false
	pending = false
	pending_id = ""
	rebind_action = ""
	sys_page = "main"
	gear_sub = false
	gear_sub_slot = ""
	var old: Node = get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	if gear_tip_host:
		gear_tip_host.visible = false
	_hide_tip()
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()


func _wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.free()


func _rebuild() -> void:
	_hide_tip()
	gear_sub = false
	gear_sub_slot = ""
	var old: Node = get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	_wipe(tabs)
	_wipe(box)
	focus_btn = null
	status = null
	inv_detail = null
	inv_btn_use = null
	inv_btn_equip = null
	inv_btn_unequip = null
	inv_btn_drop = null
	gear_tip = null
	gear_stats = null
	gear_stats_title = null
	gear_hint = null
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
		if hit and not hit.is_queued_for_deletion():
			hit.grab_focus()
			return
	if focus_btn and not focus_btn.is_queued_for_deletion():
		focus_btn.grab_focus()
		return
	for n: Node in find_children("*", "Button", true, false):
		if n.is_queued_for_deletion():
			continue
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
	PauseSys.build(self)


func _rebind() -> void:
	PauseSys.rebind(self)


func _slider_row(title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	return PauseSys.slider_row(self, title, value, lo, hi, step, on_change)


func _confirm(fn: Callable, id: String = "anon") -> void:
	PauseSys.confirm(self, fn, id)


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _process(delta: float) -> void:
	if open and tab == 0:
		GearAct.tick_x(self, delta)


func _input(event: InputEvent) -> void:
	if not open:
		return
	if rebind_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if App.has_method("rebind"):
				App.rebind(rebind_action, event)
			rebind_action = ""
			App.save_now()
			_rebuild()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			if App.has_method("rebind"):
				App.rebind(rebind_action, event)
			rebind_action = ""
			App.save_now()
			_rebuild()
			get_viewport().set_input_as_handled()
			return
	if tab == 0 and GearAct.handle_event(self, event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if App.archives_ui and bool(App.archives_ui.get("open")):
		return
	if tab == 0:
		if GearAct.handle_event(self, event):
			get_viewport().set_input_as_handled()
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
		if GearAct.swallowing():
			get_viewport().set_input_as_handled()
			return
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
