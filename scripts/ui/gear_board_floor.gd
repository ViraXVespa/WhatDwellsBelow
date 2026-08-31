extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Act := preload("res://scripts/ui/gear_board_act.gd")


static func footer(ui: CanvasLayer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var flab := _row_lab("Floor:", 20, Color(0.92, 0.84, 0.62))
	flab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(flab)
	var minus := ThemeS.btn("−", func(): Act.floor_step(ui, -1))
	row.add_child(minus)
	var nlab := _row_lab(str(int(ui.loadout_floor)), 22, Color(0.95, 0.82, 0.5))
	nlab.custom_minimum_size = Vector2(48, 44)
	row.add_child(nlab)
	var plus := ThemeS.btn("+", func(): Act.floor_step(ui, 1))
	row.add_child(plus)
	var dlab := _row_lab("(Deepest floor: %d)" % int(App.prog.deepest), 20, Color(0.82, 0.76, 0.66))
	dlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(dlab)
	var enter := ThemeS.btn("Enter dungeon", func(): Act.enter(ui))
	enter.set_meta("inv_key", "enter")
	ui.set_meta("loadout_floor_lab", nlab)
	ui.set_meta("loadout_deep_lab", dlab)
	ui.set_meta("loadout_floor_minus", minus)
	ui.set_meta("loadout_floor_plus", plus)
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
	var nlab := _meta(ui, "loadout_floor_lab")
	if nlab is Label:
		nlab.text = str(f)
	var dlab := _meta(ui, "loadout_deep_lab")
	if dlab is Label:
		dlab.text = "(Deepest floor: %d)" % deep
	var minus := _meta(ui, "loadout_floor_minus")
	var plus := _meta(ui, "loadout_floor_plus")
	var vp := ui.get_viewport()
	var was: Control = vp.gui_get_focus_owner() if vp else null
	_arm(minus, f <= 1)
	_arm(plus, f >= deep)
	_wire(ui)
	_restore(ui, was)


static func _row_lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(0, 44)
	return l


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


static func _arm(b: Control, off: bool) -> void:
	if b == null:
		return
	if b is Button:
		(b as Button).disabled = off
	b.focus_mode = Control.FOCUS_NONE if off else Control.FOCUS_ALL


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
