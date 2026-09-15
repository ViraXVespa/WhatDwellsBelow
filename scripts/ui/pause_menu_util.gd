extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")


static func cap(_ui: Node, text: String, size: int = 18, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	# No outline: matches prior pause chrome look.
	return ThemeS.lab(text, size, col, HORIZONTAL_ALIGNMENT_LEFT, false, false)


static func slider_row(
	ui: Node,
	title: String,
	value: float,
	lo: float,
	hi: float,
	step: float,
	on_change: Callable,
	show_value: bool = true,
	slider_w: float = 300.0,
) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_child(cap(ui, title, 18, Color(0.9, 0.84, 0.7)))
	if show_value:
		top.add_spacer(false)
		top.add_child(cap(ui, "%.2f" % value, 16, Color(0.82, 0.76, 0.66)))
	row.add_child(top)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(slider_w, 32.0 * ThemeS.text_scale())
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


static func blur_tip(ui: CanvasLayer) -> void:
	ui.tip_from = null
	ui.tip_id = ""
	ui.tip_kind = ""


static func hide_tip(ui: CanvasLayer) -> void:
	blur_tip(ui)
	if ui.tip_host:
		ui.tip_host.visible = false


static func paint_tip(ui: CanvasLayer) -> void:
	var kind: String = str(ui.tip_kind)
	if kind == "skill" or kind == "perm" or kind == "run":
		PauseSkills.paint_tip(ui)
		return
	if ui.tip_lab == null:
		return
	if ui.tip_host:
		ui.tip_host.visible = false


static func confirm(ui: CanvasLayer, fn: Callable, id: String = "anon") -> void:
	ui.pending = true
	ui.pending_id = id
	ui.pending_fn = fn
