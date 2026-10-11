extends Object

## Control skins outside the pause journal: neutral (hub plates, recap, anvil), title (title, news, archives) and
## per-object ones a frame names (crystal). Palettes: ui_tokens.gd SKINS. A host picks its skin with meta
## "btn_skin" or a btn_skin() method (the progress panel asks its active frame: FrameBase.btn_skin). No skin found
## (the pause journal) = the paper look stays. ThemeS.btn / paint_tab / paint_plate / lab and Plate.plate / edge
## call watch(); the control is restyled when it enters the tree (or at once if it already has). Buttons a frame
## dresses itself (UiBuild.button_base) keep their frame look.

const Tok := preload("res://scripts/ui/ui_tokens.gd")

static func watch(c: Control, kind: String, data: Array = []) -> void:
	c.set_meta("skin_kind", kind)
	c.set_meta("skin_data", data)
	if c.is_inside_tree():
		restyle(c)
	elif not c.has_meta("skin_wait"):
		c.set_meta("skin_wait", true)
		c.ready.connect(restyle.bind(c), CONNECT_ONE_SHOT)

## The skin name for a control: the nearest ancestor that names one, else "".
static func skin_of(c: Node) -> String:
	var n: Node = c.get_parent()
	while n != null:
		if n.has_meta("btn_skin"):
			return str(n.get_meta("btn_skin"))
		if n.has_method("btn_skin"):
			return str(n.call("btn_skin"))
		n = n.get_parent()
	return ""

static func palette(name: String) -> Dictionary:
	if name == "":
		return {}
	assert(Tok.SKINS.has(name), "unknown control skin " + name)
	return Tok.SKINS.get(name, {})

static func restyle(c: Control) -> void:
	if not is_instance_valid(c):
		return
	var p: Dictionary = palette(skin_of(c))
	if p.is_empty():
		return
	var kind: String = str(c.get_meta("skin_kind", ""))
	var data: Array = c.get_meta("skin_data", [])
	match kind:
		"btn":
			if not c.has_meta("frame_dressed"):
				button(c as Button, p, str(data[0]) if data.size() > 0 else "secondary", false)
		"tab":
			button(c as Button, p, str(data[1]) if data.size() > 1 else "secondary", bool(data[0]))
		"plate":
			slot(c as Button, p, data[0], data[1], bool(data[2]))
		"label":
			if p.has("words"):
				var src: Color = data[0]
				var inks: Array = [Tok.INK, Tok.INK_SOFT, Tok.INK_FAINT]
				for i: int in inks.size():
					if src.is_equal_approx(inks[i]):
						c.add_theme_color_override("font_color", p["words"][i])
		"plate_rect":
			if p.has("panel"):
				(c as ColorRect).color = p["panel"]
		"edge_rect":
			if p.has("panel_edge"):
				(c as ColorRect).color = p["panel_edge"]

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

## Focus ring drawn over the current state: no fill, bright edge and a soft glow, so gamepad focus always reads.
static func ring(p: Dictionary) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(Color(0, 0, 0, 0), p["glow"], 2, 2, int(p["radius"]))
	s.draw_center = false
	s.shadow_color = Color(p["glow"].r, p["glow"].g, p["glow"].b, 0.45)
	s.shadow_size = 5
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s

## A button face set. lit = the selected tab/option.
static func button(b: Button, p: Dictionary, role: String, lit: bool) -> void:
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
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover_pressed", press)
	b.add_theme_stylebox_override("focus", ring(p))
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", p["word_hi"])
	b.add_theme_color_override("font_focus_color", p["word_hi"])
	b.add_theme_color_override("font_pressed_color", p["word_hi"])
	b.add_theme_color_override("font_hover_pressed_color", p["word_hi"])
	b.add_theme_color_override("font_disabled_color", p["word_off"])

## Gear slot / item cell: the frame's slot face, tinted by rarity, rarity edge when it has one.
static func slot(b: Button, p: Dictionary, fill: Color, border: Color, on: bool) -> void:
	var r: int = int(p["radius"])
	var face: Color = p["slot"]
	if fill.a > 0.05 and (fill.r + fill.g + fill.b) < 2.7:
		face = face.lerp(Color(fill.r, fill.g, fill.b, face.a), 0.30)
	var edge: Color = border if border.a > 0.4 else p["slot_edge"]
	var lit: Color = face.lightened(0.12)
	b.add_theme_stylebox_override("normal", box(face, p["glow"] if on else edge, 2 if on else 1, 3 if on else 2, r))
	b.add_theme_stylebox_override("hover", box(lit, p["edge_hi"], 1, 2, r))
	b.add_theme_stylebox_override("pressed", box(face.darkened(0.12), p["edge_hi"], 1, 1, r))
	b.add_theme_stylebox_override("focus", ring(p))
	b.add_theme_stylebox_override("disabled", box(Color(face.r, face.g, face.b, 0.22), Color(p["slot_edge"].r, p["slot_edge"].g, p["slot_edge"].b, 0.35), 1, 1, r))
	b.add_theme_color_override("font_color", Tok.INK)
	b.add_theme_color_override("font_hover_color", Tok.INK)
	b.add_theme_color_override("font_focus_color", Tok.INK)

## Panel box for a skin with a panel colour (title card).
static func panel_box(name: String) -> StyleBoxFlat:
	var p: Dictionary = palette(name)
	var s: StyleBoxFlat = box(p["panel"], p["panel_edge"], 2, 2, int(p["radius"]) + 2)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	return s
