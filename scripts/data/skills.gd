class_name Skills
extends Object

const L2 := 90.0


static func xp_to_next(level: int) -> float:
	if level < 1:
		return L2
	var bands := int((level - 1) / 14)
	return L2 * pow(2.0, float(bands))


static func xp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	var total := 0.0
	for l in range(1, level):
		total += xp_to_next(l)
	return total


static func level_from_xp(xp: float) -> int:
	var lvl := 1
	var acc := 0.0
	while true:
		var need := xp_to_next(lvl)
		if xp < acc + need:
			return lvl
		acc += need
		lvl += 1
		if lvl > 10000:
			return lvl
	return lvl


static func axe_damage_mult(level: int) -> float:
	var lv := maxi(0, level - 1)
	return 1.0 + 0.04 * float(lv) + 0.004 * float(lv)


static func mine_speed_mult(level: int) -> float:
	return 1.0 + 0.05 * float(maxi(0, level - 1))


static func smith_cost_mult(level: int) -> float:
	return maxf(0.45, 1.0 - 0.03 * float(maxi(0, level - 1)))


static func smith_bar_time(level: int) -> float:
	return maxf(0.8, 2.4 - 0.08 * float(maxi(0, level - 1)))


static func smith_out_mult(level: int) -> float:
	return 1.0 + 0.01 * float(maxi(0, level - 1))


static func label(skill: String) -> String:
	match skill:
		"mining":
			return "Mining"
		"great_axe":
			return "Great Axe"
		"smithing":
			return "Smithing"
		_:
			return skill.capitalize()
