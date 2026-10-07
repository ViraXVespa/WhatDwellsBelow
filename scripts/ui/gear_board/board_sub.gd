extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Kit := preload("res://scripts/data/gear_rules/rules_kit.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const ForgeUI := preload("res://scripts/ui/gear_board/anvil_forge.gd")
const Open := preload("res://scripts/ui/gear_board/sub_open.gd")

static func _act():
	return load("res://scripts/ui/gear_board/board_act.gd")

static func _anvil():
	return load("res://scripts/ui/gear_board/anvil.gd")

static func _is_anvil(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "anvil"

static func lock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null:
			continue
		if not c.has_meta("gear_old_focus"):
			c.set_meta("gear_old_focus", c.focus_mode)
		c.focus_mode = Control.FOCUS_NONE

static func unlock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.has_meta("gear_old_focus"):
			continue
		c.focus_mode = int(c.get_meta("gear_old_focus")) as Control.FocusMode
		c.remove_meta("gear_old_focus")

static func open_sub(ui: CanvasLayer, slot: String) -> void:
	Open.open_sub(ui, slot)

static func _open_forge(ui: CanvasLayer, box: Control, slot: String) -> void:
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	var first: Control = ForgeUI.fill(ui, box, slot)
	_add_strip(box, ForgeUI.hint_parts(ui))
	if first and first.focus_mode != Control.FOCUS_NONE:
		ui.focus_btn = first if first is Button else null
		first.grab_focus()
	Board.refresh(ui)

static func _add_strip(box: Control, parts: Array) -> void:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 16)
	PromptView.fill(strip, parts)
	box.add_child(strip)

static func _paint_opt(b: Button, it: Dictionary) -> void:
	ThemeS.paint_plate(b, Icons.rarity_fill(it), Icons.rarity_border(it), false)

static func close_sub(ui: CanvasLayer) -> void:
	var Act = _act()
	var keep := str(ui.gear_sub_slot)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	unlock_bg(ui)
	Board.clear_sub(ui)
	Act.swallow_cancel()
	App.sfx("ui_cancel")
	_after_sub(ui, "slot:" + (keep if keep != "" else "weapon"), false)

static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	Open.pick(ui, slot, row)

static func _after_sub(ui: CanvasLayer, sel: String, do_rebuild: bool) -> void:
	var Act = _act()
	ui.inv_sel = sel
	var tree := ui.get_tree()
	if tree == null:
		Board.clear_sub(ui)
		if do_rebuild:
			Act.rebuild(ui)
		else:
			Board.refresh(ui)
		return
	tree.process_frame.connect(func():
		if not is_instance_valid(ui):
			return
		Board.clear_sub(ui)
		if do_rebuild:
			Act.rebuild(ui)
		else:
			ui.call_deferred("_focus")
			Board.refresh(ui)
	, CONNECT_ONE_SHOT)

static func _unequip_or_keep(ui: CanvasLayer, slot: String, it: Dictionary) -> void:
	var Act = _act()
	if Act.locked_slot(slot):
		Act.st(ui, App.tr("common.weapon_and_tool_stay_equipped"))
		return
	if Kit.is_starter(App.prog, it) or str(it.get("kit_src", "")) == "starter":
		Act.st(ui, App.tr("board_sub.starters_stay_on_the_slot"))
		return
	if Act.town_kit(ui):
		App.prog.slots[slot] = {}
		App.prog.hold_pick[slot] = -1
		Act.st(ui, App.tr("board_sub.unequipped"))
		App.save_now()
		return
	Act.st(ui, App.prog.unequip_slot(slot))

static func _apply_inv(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	var Act = _act()
	if src == "bag":
		Act.st(ui, App.prog.equip_uid(int(it.get("uid", 0))))
		ui.inv_sel = "slot:" + slot
		return
	Act.st(ui, App.tr("board_sub.can_t_use_that_here"))
