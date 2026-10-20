extends Object

## Split from theme.gd: _box, _wash, _signal.

static func _box(bg: Color, border: Color, width: int, foot: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.border_width_bottom = foot
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _wash(c: Color) -> bool:
	return (c.g > c.r + 0.06 and c.g > 0.22) or (c.b > c.r + 0.08 and c.b > 0.25)

static func _signal(c: Color) -> bool:
	var green: bool = c.g > c.r + 0.12 and c.g > 0.45
	var blue: bool = c.b > c.r + 0.15 and c.b > 0.5
	var red: bool = c.r > c.g + 0.25 and c.r > 0.55
	return green or blue or red
