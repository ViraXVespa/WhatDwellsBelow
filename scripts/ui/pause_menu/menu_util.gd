extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")

static func cap(_ui: Node, text: String, size: int = 18, col: Color = ThemeS.INK) -> Label:
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
	value_text: Callable = Callable(),
) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_child(cap(ui, title, 18, ThemeS.INK))
	var value_lab: Label = null
	if show_value:
		top.add_spacer(false)
		var shown: String = str(value_text.call(value)) if value_text.is_valid() else ("%.2f" % value)
		value_lab = cap(ui, shown, 16, ThemeS.INK_SOFT)
		top.add_child(value_lab)
	row.add_child(top)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(slider_w, 32.0 * ThemeS.text_scale())
	slider.focus_mode = Control.FOCUS_ALL
	ThemeS.skin_slider(slider)
	if value_lab != null and value_text.is_valid():
		slider.value_changed.connect(func(v: float) -> void:
			value_lab.text = str(value_text.call(v))
		)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row

static func paint_tip(ui: CanvasLayer) -> void:
	var kind: String = str(ui.tip_kind)
	if kind == "skill" or kind == "perm" or kind == "run":
		PauseSkills.paint_tip(ui)
		return
	if ui.tip_lab == null:
		return
	if ui.tip_host:
		ui.tip_host.visible = false
