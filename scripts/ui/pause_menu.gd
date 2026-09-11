extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const T := preload("res://scripts/data/tunables.gd")
const PauseInv := preload("res://scripts/ui/pause_inv.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const PauseSettings := preload("res://scripts/ui/pause_settings.gd")
const GearAct := preload("res://scripts/ui/gear_board_act.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Util := preload("res://scripts/ui/pause_menu_util.gd")
const View := preload("res://scripts/ui/pause_menu_view.gd")
const Pad := preload("res://scripts/ui/menu_pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Disp := preload("res://scripts/display_mode.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const Split := preload("res://scripts/ui/split_menu.gd")

const TAB_SETTINGS := 0
const TAB_INV := 1
const TAB_SKILLS := 2

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
var tab_wrap: HBoxContainer
var tab_scroll: ScrollContainer
var tab_left: Control
var tab_right: Control
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
var gear_hover: bool = false
var gear_tip: Label
var gear_tip_host: PanelContainer
var gear_stats: Control
var gear_stats_title: Label
var gear_hint: Control
var gear_page_left: Control
var gear_page_right: Control


func _ready() -> void:
	View.build(self)


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
	tab = TAB_SETTINGS
	sys_page = "main"
	pending = false
	pending_id = ""
	rebind_action = ""
	inv_sel = "slot:weapon"
	gear_mode = "inv"
	gear_sub = false
	gear_sub_slot = ""
	gear_hover = false
	set_meta("gear_tip_restore", false)
	Util.hide_tip(self)
	Board.hide_tip(self)
	Board._flag(self, "gear_hover", false)
	Board._flag(self, "gear_tip_ready", false)
	_rebuild()


func show_inventory() -> void:
	if not open:
		show_menu()
	if tab != TAB_INV:
		tab = TAB_INV
		sys_page = "main"
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
	gear_hover = false
	set_meta("gear_tip_restore", false)
	Confirm.close(self)
	var old: Node = get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()
	if gear_tip_host:
		gear_tip_host.visible = false
	Util.hide_tip(self)
	Board.hide_tip(self)
	Board._flag(self, "gear_hover", false)
	Board._flag(self, "gear_tip_ready", false)
	App.ui_open = false
	get_tree().paused = false
	App.save_now()
	App.swallow_close_pad()
	App.wake_web_pad()
	Disp.consume_web_esc()


func _wipe(n: Node) -> void:
	while n.get_child_count() > 0:
		var c: Node = n.get_child(0)
		n.remove_child(c)
		c.queue_free()


func _store_tip_restore() -> void:
	var host: Control = gear_tip_host
	set_meta("gear_tip_restore", host != null and host.visible)


func _rebuild() -> void:
	Util.hide_tip(self)
	Board.hide_tip(self)
	Board._flag(self, "gear_hover", false)
	Board._flag(self, "gear_tip_ready", false)
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
	gear_page_left = null
	gear_page_right = null
	var names: PackedStringArray = PackedStringArray(["Settings", "Inventory", "Skills"])
	for i: int in 3:
		var ii: int = i
		var b: Button = ThemeS.btn(names[i], func():
			if tab == TAB_INV and ii != TAB_INV:
				_store_tip_restore()
			tab = ii
			sys_page = "main"
			_rebuild()
		)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = UiText.min_size(160.0, 44.0)
		if i == tab:
			var ink := Color(0.92, 0.84, 0.62)
			b.add_theme_color_override("font_color", ink)
			b.add_theme_color_override("font_hover_color", ink)
			b.add_theme_color_override("font_focus_color", ink)
			b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
			b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
			b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
			b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
		tabs.add_child(b)
	PromptView.fill(tab_left, [{"action": "tab_left"}], 16, Color(0.72, 0.66, 0.52))
	PromptView.fill(tab_right, [{"action": "tab_right"}], 16, Color(0.72, 0.66, 0.52))
	match tab:
		TAB_SETTINGS:
			_system()
		TAB_INV:
			_inv()
		_:
			_skills()
	_paint_menu_hint()
	call_deferred("_focus")
	if tab_scroll and tabs.get_child_count() > tab:
		tab_scroll.ensure_control_visible(tabs.get_child(tab) as Control)


func _paint_menu_hint() -> void:
	if tab == TAB_INV:
		return
	PromptView.footer(self)


func _cycle_tab(dir: int) -> void:
	if tab == TAB_INV:
		_store_tip_restore()
	tab = posmod(tab + dir, 3)
	sys_page = "main"
	pending = false
	pending_id = ""
	rebind_action = ""
	_rebuild()


func _focus() -> void:
	if tab == TAB_INV:
		var hit: Control = _inv_find_sel()
		if hit and not hit.is_queued_for_deletion():
			hit.grab_focus()
			Board._flag(self, "gear_booting", false)
			if bool(get_meta("gear_tip_restore", false)):
				Board._arm_tip(self)
			else:
				Board.hide_tip(self)
				Board._flag(self, "gear_tip_ready", false)
			Board.refresh(self)
			return
	if focus_btn and not focus_btn.is_queued_for_deletion() and not tabs.is_ancestor_of(focus_btn):
		focus_btn.grab_focus()
		return
	for n: Node in box.find_children("*", "Control", true, false):
		if n.is_queued_for_deletion():
			continue
		if n is BaseButton or n is Range:
			var c: Control = n as Control
			if c.focus_mode == Control.FOCUS_NONE:
				continue
			if n is BaseButton and (n as BaseButton).disabled:
				continue
			c.grab_focus()
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
	var l: Label = Util.cap(self, text, size, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = UiText.min_size(520.0, 26.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	Util.paint_tip(self)


func _on_skill_blur(from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	call_deferred("_blur_tip")


func _blur_tip() -> void:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	Util.hide_tip(self)


func _hide_tip() -> void:
	Util.hide_tip(self)


func _paint_tip() -> void:
	Util.paint_tip(self)


func _system() -> void:
	PauseSettings.build(self)


func _slider_row(title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	return Util.slider_row(self, title, value, lo, hi, step, on_change)


func _confirm(fn: Callable, id: String = "anon") -> void:
	Util.confirm(self, fn, id)


func _st(msg: String) -> void:
	if status:
		status.text = msg
	App.sfx("ui")


func _settings_host() -> Node:
	return box.get_node_or_null("settings_host") if box else null


func _back() -> void:
	if Confirm.is_open(self):
		Confirm.close(self)
		return
	if gear_sub:
		GearAct.close_sub(self)
		return
	if tab == TAB_SETTINGS:
		var host: Node = _settings_host()
		if host and Split.back(host):
			return
	close_ui()


func _process(delta: float) -> void:
	if open and Disp.consume_web_esc():
		_back()
	if open and tab == TAB_INV:
		GearAct.tick_x(self, delta)


func _input(event: InputEvent) -> void:
	if not open:
		return
	if Confirm.is_open(self):
		if Pad.is_back(event):
			Confirm.close(self)
			get_viewport().set_input_as_handled()
		return
	var td := Pad.tab_delta(event)
	if td != 0:
		_cycle_tab(td)
		get_viewport().set_input_as_handled()
		return
	if Pad.is_back(event):
		_back()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if tab == TAB_INV:
		if GearAct.input_tick(self, event):
			get_viewport().set_input_as_handled()
			return
