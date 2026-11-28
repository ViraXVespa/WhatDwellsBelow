extends Object

## XP curve and skill levels: pure math on App.bal and the progress skill dicts. Leaf: the combat_xp and stat helpers use it.

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
