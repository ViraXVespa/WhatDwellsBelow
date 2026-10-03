extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const InvView := preload("res://scripts/ui/pause_inv/inv_view.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const PauseSettings := preload("res://scripts/ui/pause_settings.gd")
const Util := preload("res://scripts/ui/pause_menu/menu_util.gd")
const View := preload("res://scripts/ui/pause_menu/pause_menu_view.gd")
const Pad := preload("res://scripts/ui/menu_pad.gd")
const UiSession := preload("res://scripts/ui/ui_session.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Disp := preload("res://scripts/display_mode.gd")
const Flow := preload("res://scripts/ui/pause_menu/menu_flow.gd")

const TAB_SETTINGS := 0
const TAB_INV := 1

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
	Flow.toggle(self)

func show_menu() -> void:
	Flow.show_menu(self)

func show_inventory() -> void:
	Flow.show_inventory(self)

func close_ui() -> void:
	Flow.close_ui(self)

func _wipe(n: Node) -> void:
	Flow._wipe(self, n)

func _store_tip_restore() -> void:
	Flow._store_tip_restore(self)

func _rebuild() -> void:
	Flow._rebuild(self)

func _paint_menu_hint() -> void:
	Flow._paint_menu_hint(self)

func _cycle_tab(dir: int) -> void:
	Flow._cycle_tab(self, dir)

func _focus() -> void:
	Flow._focus(self)

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
	InvView.build(self)

func _inv_find_sel() -> Control:
	return InvView.find_sel(self)

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

func _system() -> void:
	PauseSettings.build(self)

func _st(msg: String) -> void:
	UiSession.status(self, msg)

func _settings_host() -> Node:
	return box.get_node_or_null("settings_host") if box else null

func _back() -> void:
	Flow._back(self)

func _process(delta: float) -> void:
	Flow._process(self, delta)

func _input(event: InputEvent) -> void:
	Flow._input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	Flow._unhandled_input(self, event)
