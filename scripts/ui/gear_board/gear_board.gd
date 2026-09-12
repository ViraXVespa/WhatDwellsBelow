extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Act := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Floor := preload("res://scripts/ui/gear_board/gear_board_floor.gd")
const Tip := preload("res://scripts/ui/gear_board/gear_board_tip.gd")
const Build := preload("res://scripts/ui/gear_board/gear_board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Host := preload("res://scripts/ui/gear_board/gear_board_host.gd")

static var pending_kit: Dictionary = {}


static func ensure_host(ui: CanvasLayer) -> void:

	Host.ensure_host(ui)

static func is_loadout(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "loadout"



static func _on(ui: CanvasLayer, key: String) -> bool:
	return Tip.on(ui, key)



static func _flag(ui: CanvasLayer, key: String, v: bool) -> void:
	ui.set_meta(key, v)
	if ui.get(key) != null:
		ui.set(key, v)



static func _arm_tip(ui: CanvasLayer) -> void:
	_flag(ui, "gear_tip_ready", true)



static func _slot_key(n: Node) -> String:
	if n == null or not n.has_meta("inv_key"):
		return ""
	return str(n.get_meta("inv_key"))



static func tip_from_focus(ui: CanvasLayer) -> void:
	var tree := ui.get_tree()
	if tree == null:
		return
	tree.process_frame.connect(func():
		if not is_instance_valid(ui):
			return
		var f: Control = ui.get_viewport().gui_get_focus_owner()
		var key := _slot_key(f)
		if key.begins_with("slot:") or key.begins_with("opt:") or key.begins_with("bag:"):
			ui.inv_sel = key
			_arm_tip(ui)
			place_tip(ui)
	, CONNECT_ONE_SHOT)



static func _watch_hover(ui: CanvasLayer, b: Control, key: String) -> void:

	Host._watch_hover(ui, b, key)

static func hide_tip(ui: CanvasLayer) -> void:
	Tip.hide_tip(ui)



static func ensure_tip(ui: CanvasLayer) -> void:
	Tip.ensure_tip(ui)



static func place_tip(ui: CanvasLayer) -> void:
	Tip.place_tip(ui)



static func _paint_hint(ui: CanvasLayer) -> void:
	var extra: Array = []
	if str(ui.get("gear_mode")) == "anvil":
		extra = load("res://scripts/ui/gear_board/gear_board_anvil.gd").hint_parts(ui)
	else:
		extra = Text.hint_parts(ui)
	PromptView.footer(ui, extra)



static func build(ui: CanvasLayer, mode: String) -> void:

	Host.build(ui, mode)

static func _slot_col(ui: CanvasLayer, slots: Array, mid: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER if mid else BoxContainer.ALIGNMENT_BEGIN
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for key: Variant in slots:
		var b: Button = slot_btn(ui, str(key))
		col.add_child(b)
		if ui.focus_btn == null and str(key) == "weapon":
			ui.focus_btn = b
	return col



static func slot_btn(ui: CanvasLayer, slot: String) -> Button:

	return Host.slot_btn(ui, slot)

static func stats_card(ui: CanvasLayer) -> PanelContainer:
	return Build.build_stats_card(ui)



static func bag_grid(ui: CanvasLayer) -> void:

	Host.bag_grid(ui)

static func bag_cell(ui: CanvasLayer, it: Dictionary) -> Button:

	return Host.bag_cell(ui, it)

static func find_sel(ui: CanvasLayer) -> Control:

	return Host.find_sel(ui)

static func refresh(ui: CanvasLayer) -> void:

	Host.refresh(ui)

static func selected(ui: CanvasLayer) -> Dictionary:
	return Text.selected(ui)



static func selected_slot(ui: CanvasLayer) -> String:
	return Text.selected_slot(ui)



static func clear_sub(ui: CanvasLayer) -> void:
	var old: Node = ui.get_node_or_null("gear_sub_panel")
	while old:
		old.name = "gear_sub_dead"
		old.queue_free()
		old = ui.get_node_or_null("gear_sub_panel")



static func apply_pending() -> void:

	Host.apply_pending()
