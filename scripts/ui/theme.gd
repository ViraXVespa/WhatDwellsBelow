extends Object

const UiText := preload("res://scripts/ui/ui_text.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")
const BtnSkin := preload("res://scripts/ui/btn_skin.gd")

const Skill := preload("res://scripts/ui/theme/skill.gd")
const Paint := preload("res://scripts/ui/theme/paint.gd")
const Box := preload("res://scripts/ui/theme/box.gd")
const Ink := preload("res://scripts/ui/theme/ink.gd")
const INK := Ink.INK
const INK_SOFT := Ink.INK_SOFT
const INK_FAINT := Ink.INK_FAINT
const PAPER := Ink.PAPER
const PAPER_DEEP := Ink.PAPER_DEEP
const PAPER_HOVER: Color = Tok.PAPER_HOVER
const PAPER_LIFT: Color = Tok.PAPER_LIFT
const RULE := Ink.RULE
const RULE_QUIET := Ink.RULE_QUIET
const DANGER := Ink.DANGER
const DANGER_RULE: Color = Tok.DANGER_RULE
const PROMPT_GOLD: Color = Tok.INK_SOFT
const OUTLINE: Color = Tok.OUTLINE
const PROMPT_OUTLINE: Color = Tok.OUTLINE
const PROMPT_OUTLINE_SIZE: int = Tok.PROMPT_OUTLINE_SIZE

static var _ink: Font

static func ink_font() -> Font:
	if _ink != null:
		return _ink
	var loaded: Resource = load("res://assets/ui/journal/ink.ttf")
	if not loaded is Font:
		push_error("ink font missing: res://assets/ui/journal/ink.ttf")
		assert(loaded is Font, "ink font missing: res://assets/ui/journal/ink.ttf")
	_ink = loaded as Font
	return _ink
static func text_scale() -> float:
	return UiText.applied()

static func font_px(size: int) -> int:
	return UiText.font_px(size)

## Full-rect anchors with both-way grow (overlay / backdrop fill).
static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH

static func lab(
	t: String,
	size: int,
	col: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	autowrap: bool = true,
	outline: bool = false,
) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if autowrap else TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_override("font", ink_font())
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Tok.OUTLINE)
		l.add_theme_constant_override("outline_size", Tok.OUTLINE_SIZE)
	return l

static func btn(t: String, cb: Callable, enabled: bool = true, role: String = "secondary") -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = UiText.min_size(0.0, 44.0)
	b.add_theme_font_override("font", ink_font())
	b.add_theme_font_size_override("font_size", font_px(20))
	_apply(b, role, false)
	b.disabled = not enabled
	if enabled and not cb.is_null():
		b.pressed.connect(cb)
	BtnSkin.watch(b, "btn", [role])
	return b

static func paint_tab(b: Button, on: bool, role: String = "secondary") -> void:
	Paint.paint_tab(b, on, role)

static func paint_bookmark(b: Button, on: bool) -> void:
	Paint.paint_bookmark(b, on)

static func paint_plate(b: Button, face: Color, border: Color, on: bool = false) -> void:
	Paint.paint_plate(b, face, border, on)

static func _ink_box(bg: Color, border: Color, width: int, foot: int) -> StyleBoxFlat:
	return Paint._ink_box(bg, border, width, foot)

static func skill_row_sb(lit: bool) -> StyleBoxFlat:
	return Skill.skill_row_sb(lit)

static func skill_row() -> PanelContainer:
	return Skill.skill_row()

static func skill_name(id: String) -> String:
	return Skill.skill_name(id)

static func skill_tip(id: String, lv: int) -> String:
	return Skill.skill_tip(id, lv)

static func sb(bg: Color, border: Color) -> StyleBoxFlat:
	var face := PAPER
	if Box._wash(bg):
		face = PAPER.lerp(Color(bg.r, bg.g, bg.b, 1.0), 0.4)
		face.a = 0.98
	elif bg.a < 0.45:
		face.a = maxf(bg.a, 0.22)
	var edge: Color = border if Box._signal(border) else RULE
	return Box._box(face, edge, 1, 1)

static func skin_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", Box._box(PAPER_DEEP, RULE, 1, 1))
	slider.add_theme_stylebox_override("grabber_area", Box._box(INK, INK, 0, 0))
	slider.add_theme_icon_override("grabber", _knob_tex())
	slider.add_theme_icon_override("grabber_highlight", _knob_tex())
	slider.add_theme_icon_override("grabber_disabled", _knob_tex())
	slider.add_theme_constant_override("center_grabber", 1)

## Text colour per button state; `disabled` is set only when given.
static func text_tones(c: Control, normal: Color, hover: Color, focus: Color, pressed: Color, disabled: Variant = null) -> void:
	c.add_theme_color_override("font_color", normal)
	c.add_theme_color_override("font_hover_color", hover)
	c.add_theme_color_override("font_focus_color", focus)
	c.add_theme_color_override("font_pressed_color", pressed)
	if disabled != null:
		c.add_theme_color_override("font_disabled_color", disabled)

static func skin_check(box: CheckBox) -> void:
	text_tones(box, INK, INK, INK, INK, INK_FAINT)
	box.add_theme_icon_override("unchecked", _tick_tex(false))
	box.add_theme_icon_override("checked", _tick_tex(true))
	box.add_theme_icon_override("unchecked_disabled", _tick_tex(false))
	box.add_theme_icon_override("checked_disabled", _tick_tex(true))
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		box.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	box.add_theme_stylebox_override("focus", Box._box(Color(0, 0, 0, 0), INK, 0, 3))

static func _apply(b: Button, role: String, lit: bool) -> void:
	var face := PAPER
	var edge := RULE
	var word := INK_SOFT
	var width := 1
	if role == "primary":
		face = PAPER_DEEP
		word = INK
		width = 2
	elif role == "danger":
		edge = DANGER_RULE
		word = DANGER
		width = 2
	if lit and role == "danger":
		face = PAPER_DEEP
		word = DANGER
		edge = DANGER
	elif lit:
		face = PAPER_DEEP
		word = INK
		edge = INK
		width = 1
	var hover: Color = PAPER_LIFT if lit or role == "primary" else PAPER_HOVER
	var foot: int = 4 if lit else width
	var focus_edge: Color = DANGER if role == "danger" else INK
	text_tones(b, word, word, focus_edge, word, INK_FAINT)
	b.add_theme_stylebox_override("normal", Box._box(face, edge, width, foot))
	b.add_theme_stylebox_override("hover", Box._box(hover, edge, width, 4))
	b.add_theme_stylebox_override("pressed", Box._box(PAPER_DEEP, edge, width, 4))
	b.add_theme_stylebox_override("focus", Box._box(hover, focus_edge, 1, 4))
	b.add_theme_stylebox_override("disabled", Box._box(PAPER, RULE_QUIET, 1, 1))

static var _mark_off: Texture2D = null
static var _mark_on: Texture2D = null
static var _knob_tex_v: Texture2D = null

static func _tick_tex(on: bool) -> Texture2D:
	if on and _mark_on != null:
		return _mark_on
	if not on and _mark_off != null:
		return _mark_off
	var tex: Texture2D = _stamp(18, false, on)
	if on:
		_mark_on = tex
	else:
		_mark_off = tex
	return tex

static func _knob_tex() -> Texture2D:
	if _knob_tex_v != null:
		return _knob_tex_v
	_knob_tex_v = _stamp(16, true, true)
	return _knob_tex_v

static func _stamp(n: int, disc: bool, ink: bool) -> Texture2D:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid: float = float(n) * 0.5 - 0.5
	var lim: float = mid - 1.0
	for y: int in n:
		for x: int in n:
			var dx: float = float(x) - mid
			var dy: float = float(y) - mid
			var inside: bool = false
			if disc:
				inside = dx * dx + dy * dy <= lim * lim
			else:
				inside = x >= 1 and y >= 1 and x < n - 1 and y < n - 1
			if not inside:
				continue
			var rim: bool = false
			if disc:
				rim = absf(dx) > lim - 2.0 or absf(dy) > lim - 2.0
			else:
				rim = x < 3 or y < 3 or x >= n - 3 or y >= n - 3
			var mark: bool = ink and absf(dx) < 3.2 and absf(dy) < 3.2
			var px := PAPER
			if rim:
				px = RULE
			if mark:
				px = INK
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)
