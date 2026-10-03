extends Object

const UiText := preload("res://scripts/ui/ui_text.gd")

const PROMPT_GOLD := Color(0.86, 0.80, 0.66)
const PROMPT_OUTLINE := Color(0.05, 0.03, 0.02)
const PROMPT_OUTLINE_SIZE := 5

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
	outline: bool = true,
) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if autowrap else TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
		l.add_theme_constant_override("outline_size", 6)
	return l

static func btn(t: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = UiText.min_size(0.0, 44.0)
	b.add_theme_font_size_override("font_size", font_px(20))
	b.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
	b.add_theme_stylebox_override("normal", sb(Color(0.22, 0.16, 0.12), Color(0.5, 0.38, 0.2)))
	b.add_theme_stylebox_override("hover", sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", sb(Color(0.16, 0.12, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", sb(Color(0.12, 0.1, 0.09), Color(0.28, 0.24, 0.2)))
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(cb)
	return b

static func skill_row_sb(lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if lit:
		s.bg_color = Color(0.26, 0.19, 0.12, 0.72)
		s.border_color = Color(0.95, 0.78, 0.35)
	else:
		s.bg_color = Color(0.16, 0.12, 0.09, 0.18)
		s.border_color = Color(0.32, 0.24, 0.16, 0.4)
	s.set_border_width_all(2)
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
			return "Staff"
		"bow":
			return "Longbow"
		"str":
			return "Strength"
		"mag":
			return "Magic"
		"rng":
			return "Ranged"
		"def":
			return "Defense"
		"hp":
			return "Hitpoints"
		"mine":
			return "Mining"
		"wood":
			return "Woodcutting"
		"smith":
			return "Smithing"
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
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
