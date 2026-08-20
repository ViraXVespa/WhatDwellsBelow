class_name Skills
extends Object

const MAX_LEVEL := 99


static func xp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	var total := 0.0
	for l in range(1, level):
		total += 60.0 + float(l) * 28.0
	return total


static func level_from_xp(xp: float) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl


static func axe_damage_mult() -> float:
	return 1.0 + 0.04 * float(maxi(0, Game.skill_level("great_axe") - 1))


static func mine_speed_mult() -> float:
	return 1.0 + 0.05 * float(maxi(0, Game.skill_level("mining") - 1))


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
