extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")


static func make(caption: String, on_down: Callable, on_up: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap: Label = _row_lab(caption, 20, Color(0.92, 0.84, 0.62))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(cap)
	var minus: Button = ThemeS.btn("−", on_down)
	row.add_child(minus)
	var nlab: Label = _row_lab("", 22, Color(0.95, 0.82, 0.5))
	nlab.custom_minimum_size = Vector2(48, 44)
	row.add_child(nlab)
	var plus: Button = ThemeS.btn("+", on_up)
	row.add_child(plus)
	var suf: Label = _row_lab("", 20, Color(0.82, 0.76, 0.66))
	suf.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(suf)
	row.set_meta("step_caption", cap)
	row.set_meta("step_minus", minus)
	row.set_meta("step_value", nlab)
	row.set_meta("step_plus", plus)
	row.set_meta("step_suffix", suf)
	return row


static func paint(row: HBoxContainer, value_text: String, suffix: String, at_lo: bool, at_hi: bool) -> void:
	var nlab: Label = value_of(row)
	if nlab:
		nlab.text = value_text
	var suf: Label = suffix_of(row)
	if suf:
		suf.text = suffix
		suf.visible = suffix != ""
	var minus: Button = minus_of(row)
	var plus: Button = plus_of(row)
	var vp := row.get_viewport()
	var was: Control = vp.gui_get_focus_owner() if vp else null
	_arm(minus, at_lo)
	_arm(plus, at_hi)
	_restore(minus, plus, was)


static func minus_of(row: HBoxContainer) -> Button:
	return _meta_btn(row, "step_minus")


static func plus_of(row: HBoxContainer) -> Button:
	return _meta_btn(row, "step_plus")


static func value_of(row: HBoxContainer) -> Label:
	return _meta_lab(row, "step_value")


static func suffix_of(row: HBoxContainer) -> Label:
	return _meta_lab(row, "step_suffix")


static func bind_side(row: HBoxContainer, left: Control, right: Control, up: Control, down: Control) -> void:
	var minus: Button = minus_of(row)
	var plus: Button = plus_of(row)
	var left_step: Control = _live(minus, plus, false)
	var right_step: Control = _live(minus, plus, true)
	if minus:
		_nb(minus, "l", left)
		_nb(minus, "r", plus if plus and plus.focus_mode != Control.FOCUS_NONE else right)
		_nb(minus, "u", up)
		_nb(minus, "d", down)
	if plus:
		_nb(plus, "l", minus if minus and minus.focus_mode != Control.FOCUS_NONE else left)
		_nb(plus, "r", right)
		_nb(plus, "u", up)
		_nb(plus, "d", down)
	if left:
		_nb(left, "r", left_step if left_step else right)
	if right:
		_nb(right, "l", right_step if right_step else left)
	if up:
		_nb(up, "d", left_step if left_step else (right_step if right_step else down))
	if down:
		_nb(down, "u", right_step if right_step else (left_step if left_step else up))


static func _row_lab(t: String, font_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(0, 44)
	return l


static func _meta_btn(row: HBoxContainer, key: String) -> Button:
	if row == null or not row.has_meta(key):
		return null
	var n: Variant = row.get_meta(key)
	return n if n is Button else null


static func _meta_lab(row: HBoxContainer, key: String) -> Label:
	if row == null or not row.has_meta(key):
		return null
	var n: Variant = row.get_meta(key)
	return n if n is Label else null


static func _arm(b: Control, off: bool) -> void:
	if b == null:
		return
	if b is Button:
		(b as Button).disabled = off
	b.focus_mode = Control.FOCUS_NONE if off else Control.FOCUS_ALL


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


static func _restore(minus: Control, plus: Control, was: Control) -> void:
	if was != minus and was != plus:
		return
	var pick: Control = null
	if was == plus:
		pick = minus if minus and minus.focus_mode != Control.FOCUS_NONE else plus
	else:
		pick = plus if plus and plus.focus_mode != Control.FOCUS_NONE else minus
	if pick and is_instance_valid(pick) and pick.focus_mode != Control.FOCUS_NONE:
		pick.grab_focus()
