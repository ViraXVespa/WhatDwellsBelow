extends Object

## Split from theme.gd: skill_row_sb, skill_row, skill_name....

const UiText := preload("res://scripts/ui/ui_text.gd")
const Box := preload("res://scripts/ui/theme/box.gd")
const Ink := preload("res://scripts/ui/theme/ink.gd")

static func skill_row_sb(lit: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = Box._box(Ink.PAPER_DEEP, Ink.INK, 1, 3) if lit else Box._box(Ink.PAPER, Ink.RULE_QUIET, 1, 1)
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
