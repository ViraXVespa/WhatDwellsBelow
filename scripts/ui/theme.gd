extends Object

const UiText := preload("res://scripts/ui/ui_text.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")

const INK: Color = Tok.INK
const INK_SOFT: Color = Tok.INK_SOFT
const INK_FAINT: Color = Tok.INK_FAINT
const PAPER: Color = Tok.PAPER
const PAPER_DEEP: Color = Tok.PAPER_DEEP
const PAPER_HOVER: Color = Tok.PAPER_HOVER
const PAPER_LIFT: Color = Tok.PAPER_LIFT
const RULE: Color = Tok.RULE
const RULE_QUIET: Color = Tok.RULE_QUIET
const DANGER: Color = Tok.DANGER
const DANGER_RULE: Color = Tok.DANGER_RULE
const PROMPT_INK: Color = Tok.INK_SOFT
const PROMPT_GOLD: Color = Tok.INK_SOFT
const OUTLINE: Color = Tok.OUTLINE
const PROMPT_OUTLINE: Color = Tok.OUTLINE
const PROMPT_OUTLINE_SIZE: int = Tok.PROMPT_OUTLINE_SIZE

static var _ink: Font

static func ink_font() -> Font:
	if _ink != null:
		return _ink
	var face: SystemFont = SystemFont.new()
	face.font_names = PackedStringArray(["Ink Free", "Segoe Script", "Segoe Print"])
	face.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	face.hinting = TextServer.HINTING_NONE
	_ink = face
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
	if enabled:
		b.pressed.connect(cb)
	return b

static func paint_tab(b: Button, on: bool, role: String = "secondary") -> void:
	var word: Color = INK if on else INK_SOFT
	var edge: Color = INK
	if role == "danger":
		word = DANGER
		edge = DANGER
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", edge)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", INK_FAINT)
	var paper: Color = Tok.BTN_PAPER
	var hover: Color = Tok.BTN_HOVER
	var foot: int = 3 if on else 1
	b.add_theme_stylebox_override("normal", _ink_box(paper, edge, 1, foot))
	b.add_theme_stylebox_override("hover", _ink_box(hover, edge, 1, maxi(foot, 2)))
	b.add_theme_stylebox_override("pressed", _ink_box(PAPER_DEEP, edge, 1, 3))
	b.add_theme_stylebox_override("focus", _ink_box(PAPER_DEEP, edge, 1, 3))
	b.add_theme_stylebox_override("disabled", _ink_box(paper, RULE_QUIET, 1, 1))

static func paint_bookmark(b: Button, on: bool) -> void:
	var word: Color = INK if on else INK_SOFT
	var paper: Color = Color(0.86, 0.78, 0.64, 1.0) if on else Color(0.91, 0.85, 0.73, 1.0)
	var edge: Color = INK if on else Color(INK.r, INK.g, INK.b, 0.45)
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", INK_FAINT)
	var normal: StyleBoxFlat = _bookmark_box(paper, edge, 2 if on else 0)
	var hover: StyleBoxFlat = _bookmark_box(Color(0.96, 0.91, 0.82, 1.0), INK, 2 if on else 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", _bookmark_box(PAPER_DEEP, INK, 2))
	b.add_theme_stylebox_override("focus", _bookmark_box(paper, INK, 2))
	b.add_theme_stylebox_override("disabled", _bookmark_box(paper, RULE_QUIET, 0))

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

static func paint_plate(b: Button, fill: Color, border: Color, on: bool = false) -> void:
	var wash: Color = Color(0, 0, 0, 0)
	if _wash(fill):
		wash = Color(fill.r, fill.g, fill.b, 0.22)
	var edge: Color = border if _signal(border) else Color(INK.r, INK.g, INK.b, 0.55)
	var shown: Color = wash
	var rim: Color = INK if on else edge
	var foot: int = 3 if on else 1
	b.add_theme_stylebox_override("normal", _ink_box(shown, rim, 1, foot))
	b.add_theme_stylebox_override("hover", _ink_box(Color(INK.r, INK.g, INK.b, 0.06), INK, 1, 2))
	b.add_theme_stylebox_override("pressed", _ink_box(Color(INK.r, INK.g, INK.b, 0.1), INK, 1, 3))
	b.add_theme_stylebox_override("focus", _ink_box(Color(PAPER_DEEP.r, PAPER_DEEP.g, PAPER_DEEP.b, 0.72), INK, 1, 3))
	b.add_theme_stylebox_override("disabled", _ink_box(Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.22), 1, 1))

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

static func skill_row_sb(lit: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = _box(PAPER_DEEP, INK, 1, 3) if lit else _box(PAPER, RULE_QUIET, 1, 1)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	return s

static func skill_row() -> PanelContainer:
	var p := PanelContainer.new()
	p.focus_mode = Control.FOCUS_ALL
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = UiText.min_size(0.0, 52.0)
	p.add_theme_stylebox_override("panel", skill_row_sb(false))
	return p

static func skill_name(id: String) -> String:
	match id:
		"axe":
			return App.tr("common.great_axe")
		"staff":
			return App.tr("skill.staff")
		"bow":
			return App.tr("skill.bow")
		"str":
			return App.tr("skill.str")
		"mag":
			return App.tr("skill.mag")
		"rng":
			return App.tr("skill.rng")
		"def":
			return App.tr("skill.def")
		"hp":
			return App.tr("skill.hp")
		"mine":
			return App.tr("skill.mine")
		"wood":
			return App.tr("skill.wood")
		"smith":
			return App.tr("skill.smith")
	return id

static func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

static func skill_tip(id: String, lv: int) -> String:
	lv = maxi(1, lv)
	var ranks := maxi(0, lv - 1)
	var n := skill_name(id)
	var wpn := float(App.bal.skill_dmg_weapon)
	var sty := float(App.bal.skill_dmg_style)
	var spec := float(App.bal.skill_special_bonus)
	var now := ""
	var per := ""
	match id:
		"axe":
			if ranks <= 0:
				now = App.tr("common.now_no_damage_bonus_yet")
			else:
				now = App.tr("theme.now_great_axe_damage_great") % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = App.tr("theme.each_level_after_1_great") % [_pct(wpn), _pct(spec)]
		"staff":
			if ranks <= 0:
				now = App.tr("common.now_no_damage_bonus_yet")
			else:
				now = App.tr("theme.now_staff_damage_staff_special") % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = App.tr("theme.each_level_after_1_staff") % [_pct(wpn), _pct(spec)]
		"bow":
			if ranks <= 0:
				now = App.tr("common.now_no_damage_bonus_yet")
			else:
				now = App.tr("theme.now_longbow_damage_longbow_speci") % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = App.tr("theme.each_level_after_1_longbow") % [_pct(wpn), _pct(spec)]
		"str":
			if ranks <= 0:
				now = App.tr("common.now_no_style_bonus_yet")
			else:
				now = App.tr("theme.now_melee_style_damage_great") % _pct(ranks * sty)
			per = App.tr("common.each_level_after_1_style") % _pct(sty)
		"mag":
			if ranks <= 0:
				now = App.tr("common.now_no_style_bonus_yet")
			else:
				now = App.tr("theme.now_magic_style_damage_staff") % _pct(ranks * sty)
			per = App.tr("common.each_level_after_1_style") % _pct(sty)
		"rng":
			if ranks <= 0:
				now = App.tr("common.now_no_style_bonus_yet")
			else:
				now = App.tr("theme.now_ranged_style_damage_longbow") % _pct(ranks * sty)
			per = App.tr("common.each_level_after_1_style") % _pct(sty)
		"def":
			var dnow := float(ranks) * float(App.bal.skill_def_per_lv)
			if ranks <= 0:
				now = App.tr("theme.now_no_defense_bonus_yet")
			else:
				now = App.tr("theme.now_defense") % dnow
			per = App.tr("theme.each_level_after_1_defense") % float(App.bal.skill_def_per_lv)
		"hp":
			var hnow := int(round(float(ranks) * float(App.bal.skill_hp_per_lv)))
			if ranks <= 0:
				now = App.tr("theme.now_no_hitpoints_bonus_yet")
			else:
				now = App.tr("theme.now_max_hp") % hnow
			per = App.tr("theme.each_level_after_1_max") % int(round(float(App.bal.skill_hp_per_lv)))
		"mine":
			now = App.tr("theme.now_mining_success_chance") % _pct(float(lv) * float(App.bal.skill_gather))
			per = App.tr("theme.each_level_mining_success_chance") % _pct(float(App.bal.skill_gather))
		"wood":
			now = App.tr("theme.now_woodcutting_success_chance") % _pct(float(lv) * float(App.bal.skill_gather))
			per = App.tr("theme.each_level_woodcutting_success_c") % _pct(float(App.bal.skill_gather))
		"smith":
			var speed := 1.0 + float(ranks) * 0.12
			var extra := int(lv / 4.0)
			now = App.tr("theme.now_forge_cost_g_ore") % [lv * 2, lv, speed, extra]
			per = App.tr("theme.each_level_2g_1_ore")
		_:
			now = App.tr("theme.now_no_listed_bonus")
			per = App.tr("theme.no_per_level_bonus_is")
	return App.tr("theme.level") % [n, lv, now, per]

static func sb(bg: Color, border: Color) -> StyleBoxFlat:
	var fill := PAPER
	if _wash(bg):
		fill = PAPER.lerp(Color(bg.r, bg.g, bg.b, 1.0), 0.4)
		fill.a = 0.98
	elif bg.a < 0.45:
		fill.a = maxf(bg.a, 0.22)
	var edge: Color = border if _signal(border) else RULE
	return _box(fill, edge, 1, 1)

static func skin_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", _box(PAPER_DEEP, RULE, 1, 1))
	slider.add_theme_stylebox_override("grabber_area", _box(INK, INK, 0, 0))
	slider.add_theme_icon_override("grabber", _knob_tex())
	slider.add_theme_icon_override("grabber_highlight", _knob_tex())
	slider.add_theme_icon_override("grabber_disabled", _knob_tex())
	slider.add_theme_constant_override("center_grabber", 1)

static func skin_check(box: CheckBox) -> void:
	box.add_theme_color_override("font_color", INK)
	box.add_theme_color_override("font_hover_color", INK)
	box.add_theme_color_override("font_focus_color", INK)
	box.add_theme_color_override("font_pressed_color", INK)
	box.add_theme_color_override("font_disabled_color", INK_FAINT)
	box.add_theme_icon_override("unchecked", _tick_tex(false))
	box.add_theme_icon_override("checked", _tick_tex(true))
	box.add_theme_icon_override("unchecked_disabled", _tick_tex(false))
	box.add_theme_icon_override("checked_disabled", _tick_tex(true))
	box.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	box.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	box.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	box.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	box.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), INK, 0, 3))

static func _apply(b: Button, role: String, lit: bool) -> void:
	var fill := PAPER
	var edge := RULE
	var word := INK_SOFT
	var width := 1
	if role == "primary":
		fill = PAPER_DEEP
		word = INK
		width = 2
	elif role == "danger":
		edge = DANGER_RULE
		word = DANGER
		width = 2
	if lit and role == "danger":
		fill = PAPER_DEEP
		word = DANGER
		edge = DANGER
	elif lit:
		fill = PAPER_DEEP
		word = INK
		edge = INK
		width = 1
	var hover: Color = PAPER_LIFT if lit or role == "primary" else PAPER_HOVER
	var foot: int = 4 if lit else width
	var focus_edge: Color = DANGER if role == "danger" else INK
	b.add_theme_color_override("font_color", word)
	b.add_theme_color_override("font_hover_color", word)
	b.add_theme_color_override("font_focus_color", focus_edge)
	b.add_theme_color_override("font_pressed_color", word)
	b.add_theme_color_override("font_disabled_color", INK_FAINT)
	b.add_theme_stylebox_override("normal", _box(fill, edge, width, foot))
	b.add_theme_stylebox_override("hover", _box(hover, edge, width, 4))
	b.add_theme_stylebox_override("pressed", _box(PAPER_DEEP, edge, width, 4))
	b.add_theme_stylebox_override("focus", _box(hover, focus_edge, 1, 4))
	b.add_theme_stylebox_override("disabled", _box(PAPER, RULE_QUIET, 1, 1))

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
