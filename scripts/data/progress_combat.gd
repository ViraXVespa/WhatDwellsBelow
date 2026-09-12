extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Stat := preload("res://scripts/data/progress_combat_stat.gd")
const Xp := preload("res://scripts/data/progress_combat_xp.gd")


static func skill_xp(p, id: String) -> float:
	return float(p.skills_run.get(id, 0.0)) + float(p.skills_perm.get(id, 0.0))

static func skill_lv(p, id: String) -> int:
	return level_from_xp(p, skill_xp(p, id))

static func xp_period() -> float:
	return maxf(1.0, App.bal.xp_double_every)

static func xp_unit() -> float:
	return maxf(1.0, App.bal.xp_level)

static func xp_to_reach(level: int) -> float:
	var lv := maxi(1, level)
	if lv <= 1:
		return 0.0
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	return unit * (pow(r, float(lv - 1)) - 1.0) / (r - 1.0)

static func level_from_xp(_p, total: float) -> int:
	var t := maxf(0.0, total)
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	var n := 1.0 + log(1.0 + t * (r - 1.0) / unit) / log(r)
	return maxi(1, int(n))

static func xp_to_next(p, total: float) -> float:
	var lv := level_from_xp(p, total)
	return maxf(0.0, xp_to_reach(lv + 1) - maxf(0.0, total))

static func xp_ratio(p, total: float) -> float:
	var lv := level_from_xp(p, total)
	var a := xp_to_reach(lv)
	var b := xp_to_reach(lv + 1)
	var span := b - a
	if span <= 0.0001:
		return 1.0
	return clampf((maxf(0.0, total) - a) / span, 0.0, 1.0)

static func add_run_xp(p, id: String, amt: float) -> void:
	Xp.add_run_xp(p, id, amt)

static func add_perm_xp(p, id: String, amt: float) -> void:
	var before := skill_lv(p, id)
	p.skills_perm[id] = float(p.skills_perm.get(id, 0.0)) + amt
	if skill_lv(p, id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, skill_lv(p, id)])

static func skill_dmg_mult(p, is_special := false) -> float:
	return Stat.skill_dmg_mult(p, is_special)

static func skill_def(p) -> float:
	return float(maxi(0, skill_lv(p, "def") - 1)) * App.bal.skill_def_per_lv

static func skill_hp(p) -> float:
	return float(maxi(0, skill_lv(p, "hp") - 1)) * App.bal.skill_hp_per_lv

static func tool_quality(p) -> float:
	var it: Dictionary = p.slots.get("tool", {})
	if it.is_empty():
		return 1.0
	var q: float = 1.0 + Stat.item_stat(it, Affix.ID_GATHER_SPD)
	q += Stat.item_stat(it, Affix.ID_GATHER_POW) * 0.08
	q += Stat.item_stat(it, Affix.ID_YIELD)
	if bool(it.get("hold", false)):
		q += 0.15
	return maxf(0.2, q)

static func skill_grant_hit(p, is_special := false) -> void:
	Stat.skill_grant_hit(p, is_special)

static func keep_fragments(p) -> void:
	var keep: float = App.bal.xp_keep
	for id in p.SKILLS:
		p.skills_perm[id] = float(p.skills_perm.get(id, 0.0)) + float(p.skills_run.get(id, 0.0)) * keep
		p.skills_run[id] = 0.0

static func survive_pair(p) -> float:
	return float(skill_lv(p, "def") + skill_lv(p, "hp"))

static func combat_score(p, wpn: String, sty: String) -> float:
	return (float(skill_lv(p, wpn) + skill_lv(p, sty)) + survive_pair(p)) / 4.0

static func combat_iv(p, wpn: String, sty: String) -> int:
	return maxi(1, int(round(combat_score(p, wpn, sty))))

static func melee_lv_f(p) -> float:
	return combat_score(p, "axe", "str")

static func magic_lv_f(p) -> float:
	return combat_score(p, "staff", "mag")

static func ranged_lv_f(p) -> float:
	return combat_score(p, "bow", "rng")

static func combat_lv_f(p) -> float:
	return maxf(melee_lv_f(p), maxf(magic_lv_f(p), ranged_lv_f(p)))

static func style_lv_f(p) -> float:
	if App.weapon == "staff":
		return magic_lv_f(p)
	if App.weapon == "longbow":
		return ranged_lv_f(p)
	return melee_lv_f(p)

static func set_counts(p) -> Dictionary:
	return Xp.set_counts(p)

static func set_stats(p) -> Dictionary:
	return Stat.set_stats(p)

static func item_stat(it: Dictionary, key: String) -> float:
	return Stat.item_stat(it, key)

static func gear_stat(p, key: String) -> float:
	return Xp.gear_stat(p, key)

static func set_bonus_text(p, set_id: String) -> String:
	return Xp.set_bonus_text(p, set_id)

static func sync_artifacts(p) -> void:
	App.run_artifacts.clear()
	for it in p.bag:
		if str(it.kind) == "artifact":
			App.run_artifacts.append(str(it.id))

static func refresh_player_hp(p) -> void:
	Xp.refresh_player_hp(p)
