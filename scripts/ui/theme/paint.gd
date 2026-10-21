extends Object

## Split from theme.gd: paint_tab, paint_bookmark, _bookmark_box....

const BtnSkin := preload("res://scripts/ui/btn_skin.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")
const Box := preload("res://scripts/ui/theme/box.gd")
const Ink := preload("res://scripts/ui/theme/ink.gd")

static func paint_tab(b: Button, on: bool, role: String = "secondary") -> void:
	var word: Color = Ink.INK if on else Ink.INK_SOFT
	var edge: Color = Ink.INK
	if role == "danger":
		word = Ink.DANGER
		edge = Ink.DANGER
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", Ink.INK)
	b.add_theme_color_override("font_focus_color", edge)
	b.add_theme_color_override("font_pressed_color", Ink.INK)
	b.add_theme_color_override("font_disabled_color", Ink.INK_FAINT)
	var paper: Color = Tok.BTN_PAPER
	var hover: Color = Tok.BTN_HOVER
	var foot: int = 3 if on else 1
	b.add_theme_stylebox_override("normal", _ink_box(paper, edge, 1, foot))
	b.add_theme_stylebox_override("hover", _ink_box(hover, edge, 1, maxi(foot, 2)))
	b.add_theme_stylebox_override("pressed", _ink_box(Ink.PAPER_DEEP, edge, 1, 3))
	b.add_theme_stylebox_override("focus", _ink_box(Ink.PAPER_DEEP, edge, 1, 3))
	b.add_theme_stylebox_override("disabled", _ink_box(paper, Ink.RULE_QUIET, 1, 1))
	BtnSkin.watch(b, "tab", [on, role])

static func paint_bookmark(b: Button, on: bool) -> void:
	var word: Color = Ink.INK if on else Ink.INK_SOFT
	var paper: Color = Color(0.86, 0.78, 0.64, 1.0) if on else Color(0.91, 0.85, 0.73, 1.0)
	var edge: Color = Ink.INK if on else Color(Ink.INK.r, Ink.INK.g, Ink.INK.b, 0.45)
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", Ink.INK)
	b.add_theme_color_override("font_focus_color", Ink.INK)
	b.add_theme_color_override("font_pressed_color", Ink.INK)
	b.add_theme_color_override("font_disabled_color", Ink.INK_FAINT)
	var normal: StyleBoxFlat = _bookmark_box(paper, edge, 2 if on else 0)
	var hover: StyleBoxFlat = _bookmark_box(Color(0.96, 0.91, 0.82, 1.0), Ink.INK, 2 if on else 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", _bookmark_box(Ink.PAPER_DEEP, Ink.INK, 2))
	b.add_theme_stylebox_override("focus", _bookmark_box(paper, Ink.INK, 2))
	b.add_theme_stylebox_override("disabled", _bookmark_box(paper, Ink.RULE_QUIET, 0))

static func _bookmark_box(bg: Color, edge: Color, underline: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = _ink_box(bg, edge, 1, 0)
	s.border_width_bottom = underline
	s.border_width_top = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s

static func paint_plate(b: Button, face: Color, border: Color, on: bool = false) -> void:
	var wash: Color = Color(0, 0, 0, 0)
	if Box._wash(face):
		wash = Color(face.r, face.g, face.b, 0.22)
	var edge: Color = border if Box._signal(border) else Color(Ink.INK.r, Ink.INK.g, Ink.INK.b, 0.55)
	var shown: Color = wash
	var rim: Color = Ink.INK if on else edge
	var foot: int = 3 if on else 1
	b.add_theme_stylebox_override("normal", _ink_box(shown, rim, 1, foot))
	b.add_theme_stylebox_override("hover", _ink_box(Color(Ink.INK.r, Ink.INK.g, Ink.INK.b, 0.06), Ink.INK, 1, 2))
	b.add_theme_stylebox_override("pressed", _ink_box(Color(Ink.INK.r, Ink.INK.g, Ink.INK.b, 0.1), Ink.INK, 1, 3))
	b.add_theme_stylebox_override("focus", _ink_box(Color(Ink.PAPER_DEEP.r, Ink.PAPER_DEEP.g, Ink.PAPER_DEEP.b, 0.72), Ink.INK, 1, 3))
	b.add_theme_stylebox_override("disabled", _ink_box(Color(0, 0, 0, 0), Color(Ink.INK.r, Ink.INK.g, Ink.INK.b, 0.22), 1, 1))
	BtnSkin.watch(b, "plate", [face, border, on])

static func _ink_box(bg: Color, border: Color, width: int, foot: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.border_width_bottom = foot
	s.set_corner_radius_all(0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s
