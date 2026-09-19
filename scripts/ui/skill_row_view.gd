extends Object

## Shared skill label + single-fill XP track (Brief item 6).

const ThemeS := preload("res://scripts/ui/theme.gd")

const TRACK_COL := Color(0.18, 0.14, 0.1)


static func skill_lab(text: String, size: int = 16, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	var l: Label = ThemeS.lab(text, size, col, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func make_track() -> ColorRect:
	var track: ColorRect = ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, 16)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = TRACK_COL
	track.clip_contents = true
	return track


static func single_fill(ratio: float, fill_col: Color) -> ColorRect:
	var track: ColorRect = make_track()
	var fill: ColorRect = ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_col
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	return track


static func row_single(text: String, ratio: float, fill_col: Color) -> PanelContainer:
	var shell: PanelContainer = ThemeS.skill_row()
	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	inner.add_child(skill_lab(text))
	inner.add_child(single_fill(ratio, fill_col))
	shell.add_child(inner)
	return shell
