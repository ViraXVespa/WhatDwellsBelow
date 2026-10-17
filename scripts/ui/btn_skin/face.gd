extends Object

## Split from btn_skin.gd: _face, ring, _slot_face....

const Tok := preload("res://scripts/ui/ui_tokens.gd")

static func _face(p: Dictionary, role: String, lit: bool) -> Dictionary:
	var r: int = int(p["radius"])
	var fill: Color = p["primary_fill"] if role == "primary" else p["fill"]
	var edge: Color = p["primary_edge"] if role == "primary" else p["edge"]
	var word: Color = p["word"]
	if role == "danger":
		edge = p["danger_edge"]
		word = p["danger_word"]
	if lit:
		fill = p["primary_fill"]
		edge = p["glow"]
		word = p["word_hi"]
	var normal: StyleBoxFlat = box(fill, edge, 2 if lit else 1, 4 if lit else 3, r)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 2)
	var hover: StyleBoxFlat = box(p["hover"], p["edge_hi"], 1, 3, r)
	var press: StyleBoxFlat = box(p["press"], p["edge_hi"], 1, 1, r)
	press.content_margin_top = 8
	press.content_margin_bottom = 4
	var off: StyleBoxFlat = box(p["off"], p["edge_off"], 1, 1, r)
	return {
		"boxes": {"normal": normal, "hover": hover, "pressed": press, "hover_pressed": press, "focus": ring(p), "disabled": off},
		"words": {"font_color": word, "font_hover_color": p["word_hi"], "font_focus_color": p["word_hi"],
			"font_pressed_color": p["word_hi"], "font_hover_pressed_color": p["word_hi"], "font_disabled_color": p["word_off"]},
	}

## Focus ring drawn over the current state: no fill, bright edge and a soft glow, so gamepad focus always reads.
static func ring(p: Dictionary) -> StyleBoxFlat:
	var w: int = int(p.get("ring", 2))
	var s: StyleBoxFlat = box(Color(0, 0, 0, 0), p["glow"], w, w, int(p["radius"]))
	s.draw_center = false
	s.shadow_color = Color(p["glow"].r, p["glow"].g, p["glow"].b, 0.55)
	s.shadow_size = 5
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s

static func _slot_face(p: Dictionary, fill: Color, border: Color, on: bool) -> Dictionary:
	var r: int = int(p["radius"])
	var face: Color = p["slot"]
	if fill.a > 0.05 and (fill.r + fill.g + fill.b) < 2.7:
		face = face.lerp(Color(fill.r, fill.g, fill.b, face.a), 0.30)
	var edge: Color = border if border.a > 0.4 else p["slot_edge"]
	var se: Color = p["slot_edge"]
	return {
		"boxes": {
			"normal": box(face, p["glow"] if on else edge, 2 if on else 1, 3 if on else 2, r),
			"hover": box(face.lightened(0.12), p["edge_hi"], 1, 2, r),
			"pressed": box(face.darkened(0.12), p["edge_hi"], 1, 1, r),
			"focus": ring(p),
			"disabled": box(Color(face.r, face.g, face.b, 0.22), Color(se.r, se.g, se.b, 0.35), 1, 1, r),
		},
		"words": {"font_color": Tok.INK, "font_hover_color": Tok.INK, "font_focus_color": Tok.INK},
	}

static func box(bg: Color, edge: Color, width: int, foot: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.border_width_bottom = foot
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
