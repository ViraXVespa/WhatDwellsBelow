extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Act := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")


static func footer(ui: CanvasLayer) -> void:
	var row: HBoxContainer = StepRow.make("Floor:", func(): Act.floor_step(ui, -1), func(): Act.floor_step(ui, 1))
	var enter: Button = ThemeS.btn("Enter dungeon", func(): Act.enter(ui))
	enter.set_meta("inv_key", "enter")
	ui.set_meta("loadout_floor_row", row)
	ui.set_meta("loadout_floor_lab", StepRow.value_of(row))
	ui.set_meta("loadout_deep_lab", StepRow.suffix_of(row))
	ui.set_meta("loadout_floor_minus", StepRow.minus_of(row))
	ui.set_meta("loadout_floor_plus", StepRow.plus_of(row))
	ui.set_meta("loadout_enter", enter)
	ui.box.add_child(row)
	ui.box.add_child(enter)
	ui.inv_sel = "enter"
	ui.focus_btn = enter
	sync(ui)


static func sync(ui: CanvasLayer) -> void:
	if str(ui.get("gear_mode")) != "loadout":
		return
	var f := int(ui.loadout_floor)
	var deep := int(App.prog.deepest)
	var row: HBoxContainer = null
	if ui.has_meta("loadout_floor_row"):
		var raw: Variant = ui.get_meta("loadout_floor_row")
		if raw is HBoxContainer:
			row = raw
	if row:
		var vp := ui.get_viewport()
		var was: Control = vp.gui_get_focus_owner() if vp else null
		StepRow.paint(row, str(f), "(Deepest floor: %d)" % deep, f <= 1, f >= deep)
		_wire(ui)
		_restore(ui, was)
		return
	_wire(ui)


static func _meta(ui: CanvasLayer, key: String) -> Control:
	if not ui.has_meta(key):
		return null
	var n: Variant = ui.get_meta(key)
	return n if n is Control else null


static func _slot(ui: CanvasLayer, slot: String) -> Control:
	if ui.box == null:
		return null
	var want := "slot:" + slot
	for n: Node in ui.box.find_children("*", "Control", true, false):
		if n.is_queued_for_deletion():
			continue
		if str(n.get_meta("inv_key", "")) == want:
			return n as Control
	return null


static func _nb(from: Control, dir: String, to: Control) -> void:
	if from == null:
		return
	var p := NodePath()
	if to != null and is_instance_valid(to) and to.focus_mode != Control.FOCUS_NONE:
		p = from.get_path_to(to)
	match dir:
		"l":
			from.focus_neighbor_left = p
		"r":
			from.focus_neighbor_right = p
		"u":
			from.focus_neighbor_top = p
		"d":
			from.focus_neighbor_bottom = p


static func _live(minus: Control, plus: Control, prefer_plus: bool) -> Control:
	if prefer_plus:
		if plus != null and plus.focus_mode != Control.FOCUS_NONE:
			return plus
		if minus != null and minus.focus_mode != Control.FOCUS_NONE:
			return minus
	else:
		if minus != null and minus.focus_mode != Control.FOCUS_NONE:
			return minus
		if plus != null and plus.focus_mode != Control.FOCUS_NONE:
			return plus
	return null


static func _wire(ui: CanvasLayer) -> void:
	var minus := _meta(ui, "loadout_floor_minus")
	var plus := _meta(ui, "loadout_floor_plus")
	var enter := _meta(ui, "loadout_enter")
	var potion := _slot(ui, "potion")
	var legs := _slot(ui, "legs")
	var food := _slot(ui, "food")
	var left_step := _live(minus, plus, false)
	var right_step := _live(minus, plus, true)
	var any_step := right_step if right_step else left_step
	_nb(potion, "d", left_step if left_step else enter)
	_nb(legs, "d", right_step if right_step else enter)
	_nb(food, "d", right_step if right_step else enter)
	if minus:
		_nb(minus, "u", potion if potion else legs)
		_nb(minus, "d", enter)
		_nb(minus, "r", plus if plus and plus.focus_mode != Control.FOCUS_NONE else enter)
		_nb(minus, "l", potion)
	if plus:
		_nb(plus, "u", legs if legs else food)
		_nb(plus, "d", enter)
		_nb(plus, "l", minus if minus and minus.focus_mode != Control.FOCUS_NONE else (legs if legs else potion))
		_nb(plus, "r", enter)
	if enter:
		_nb(enter, "u", any_step if any_step else legs)


static func _restore(ui: CanvasLayer, was: Control) -> void:
	var minus := _meta(ui, "loadout_floor_minus")
	var plus := _meta(ui, "loadout_floor_plus")
	var enter := _meta(ui, "loadout_enter")
	if was != minus and was != plus:
		return
	var pick: Control = null
	if was == plus:
		pick = minus if minus and minus.focus_mode != Control.FOCUS_NONE else enter
	else:
		pick = plus if plus and plus.focus_mode != Control.FOCUS_NONE else enter
	if pick and is_instance_valid(pick):
		pick.grab_focus()
