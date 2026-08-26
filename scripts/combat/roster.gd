extends Object

## Twelve normal enemy types. Floor pools guarantee ≥5 types per floor.

const IDS: PackedStringArray = [
	"slime", "goblin", "orc", "skeleton",
	"bat", "spider", "archer", "shaman",
	"imp", "wolf", "beetle", "wisp",
]

const POOLS: Array = [
	["slime", "goblin", "bat", "spider", "archer"],
	["goblin", "skeleton", "wolf", "shaman", "beetle"],
	["orc", "skeleton", "spider", "imp", "archer"],
	["orc", "wolf", "shaman", "wisp", "beetle"],
	["slime", "orc", "imp", "wisp", "bat"],
]

const PRE := ["Gra", "Zul", "Mor", "Vex", "Thal", "Kor", "Ash", "Brul", "Fen", "Nyx", "Drak", "Ul"]
const MID := ["", "a", "o", "ul", "an", "or", "i", "ee", "u"]
const SUF := ["tok", "nash", "goth", "fang", "rath", "ek", "ba", "moth", "vik", "zul", "orn", "ith"]


static func floor_types(floor_n: int) -> PackedStringArray:
	var i := (maxi(1, floor_n) - 1) % 5
	return PackedStringArray(POOLS[i])


static func def(id: String) -> Dictionary:
	var all := _all()
	var d: Dictionary = all[id] if all.has(id) else all["goblin"]
	d = d.duplicate()
	if App.bal:
		d.hp = App.bal.getv("e_%s_hp" % id) if App.bal.getv("e_%s_hp" % id) > 0.0 else float(d.hp)
		var dv := App.bal.getv("e_%s_dmg" % id)
		if dv > 0.0:
			d.dmg = dv
		var sv := App.bal.getv("e_%s_spd" % id)
		if sv > 0.0:
			d.spd = sv
		var rv := App.bal.getv("e_%s_range" % id)
		if rv > 0.0:
			d.range = rv
		d.def = App.bal.getv("e_%s_def" % id)
	return d


static func make_name(rng: RandomNumberGenerator) -> String:
	return PRE[rng.randi() % PRE.size()] + MID[rng.randi() % MID.size()] + SUF[rng.randi() % SUF.size()]


static func cycle_tint(cycle: int) -> Color:
	match cycle % 4:
		1:
			return Color(1.12, 0.82, 0.78)
		2:
			return Color(0.82, 0.88, 1.16)
		3:
			return Color(0.88, 1.12, 0.84)
		_:
			return Color(1, 1, 1)


static func _all() -> Dictionary:
	return {
		"slime": {"role": "melee", "move": "hop", "hp": 24.0, "dmg": 6.0, "spd": 2.2, "range": 0.95, "def": 2.0, "size": 1.25, "arc": 100.0},
		"goblin": {"role": "melee", "move": "walk", "hp": 32.0, "dmg": 8.0, "spd": 3.15, "range": 1.15, "def": 1.0, "size": 1.5, "arc": 90.0},
		"orc": {"role": "melee", "move": "walk", "hp": 58.0, "dmg": 12.0, "spd": 2.05, "range": 1.35, "def": 8.0, "size": 1.85, "arc": 110.0},
		"skeleton": {"role": "melee", "move": "walk", "hp": 36.0, "dmg": 9.0, "spd": 2.7, "range": 1.2, "def": 3.0, "size": 1.6, "arc": 95.0},
		"bat": {"role": "melee", "move": "fly", "hp": 20.0, "dmg": 7.0, "spd": 4.05, "range": 0.9, "def": 0.0, "size": 1.15, "arc": 80.0},
		"spider": {"role": "melee", "move": "walk", "hp": 28.0, "dmg": 8.0, "spd": 3.25, "range": 1.05, "def": 2.0, "size": 1.35, "arc": 120.0},
		"archer": {"role": "ranged", "move": "walk", "hp": 26.0, "dmg": 7.0, "spd": 2.85, "range": 6.2, "def": 1.0, "size": 1.5, "arc": 14.0},
		"shaman": {"role": "mage", "move": "walk", "hp": 30.0, "dmg": 11.0, "spd": 2.35, "range": 3.4, "def": 2.0, "size": 1.55, "arc": 360.0},
		"imp": {"role": "mage", "move": "fly", "hp": 22.0, "dmg": 10.0, "spd": 3.55, "range": 4.2, "def": 0.0, "size": 1.2, "arc": 360.0},
		"wolf": {"role": "melee", "move": "walk", "hp": 34.0, "dmg": 10.0, "spd": 3.85, "range": 1.1, "def": 2.0, "size": 1.45, "arc": 70.0},
		"beetle": {"role": "melee", "move": "hop", "hp": 52.0, "dmg": 9.0, "spd": 1.85, "range": 1.05, "def": 10.0, "size": 1.4, "arc": 80.0},
		"wisp": {"role": "ranged", "move": "fly", "hp": 18.0, "dmg": 8.0, "spd": 2.95, "range": 5.4, "def": 0.0, "size": 1.1, "arc": 16.0},
	}
