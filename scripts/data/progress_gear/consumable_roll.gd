extends Object

## Split from consumable.gd: roll_three, roll_potion, preview_food....

const Affix := preload("res://scripts/data/affixes.gd")
const Make := preload("res://scripts/data/progress_gear/progress_make.gd")
const Food := preload("res://scripts/data/progress_gear/food_prof.gd")

const BREWS: PackedStringArray = ["pale", "green", "amber", "ink", "milk", "red"]

static func roll_three(p: Object) -> Array:
	var out: Array = []
	for _i: int in 3:
		out.append(roll_potion(p))
	return out

static func roll_potion(p: Object) -> Dictionary:
	var charges: int = _irange("potion_charges_min", "potion_charges_max", 1, 4)
	var it: Dictionary = Make.make_potion(p, charges)
	it["heal"] = _frange("potion_heal_min", "potion_heal_max", 40.0, 140.0)
	it["heal_secs"] = _frange("potion_speed_min", "potion_speed_max", 0.0, 6.0)
	it["cooldown"] = _frange("potion_cd_min", "potion_cd_max", 4.0, 12.0)
	var brew: String = BREWS[randi() % BREWS.size()]
	it["brew"] = brew
	it["nk"] = ["potion." + brew]
	it["name"] = App.tr("potion." + brew)
	if randf() < _f("potion_bonus_chance", 0.35):
		var defs: Array = Affix.defs()
		if defs.size() > 0:
			var row: Dictionary = defs[randi() % defs.size()]
			it["bonus_id"] = str(row.get("id", ""))
			if str(row.get("kind", "")) == Affix.KIND_PCT:
				it["bonus_amt"] = _f("potion_bonus_pct", 0.04)
			else:
				it["bonus_amt"] = _f("potion_bonus_flat", 2.0)
			it["bonus_secs"] = _frange("potion_bonus_secs_min", "potion_bonus_secs_max", 3.0, 6.0)
	return it

## A food dict for a vendor row. Does not spend a uid.
static func preview_food(fid: String) -> Dictionary:
	var key: String = "trail_bread" if fid == "bread" else fid
	var prof: Dictionary = Food.FOOD_PROF.get(key, Food.FOOD_PROF["ration"])
	var nk: String = str(prof["nk"])
	var it: Dictionary = {"kind": "food", "slot": "food", "food": fid, "nk": [nk], "name": App.tr(nk), "stack": 1}
	return decorate_food(it)

static func decorate_food(it: Dictionary) -> Dictionary:
	return Food.decorate_food(it)

static func _irange(lo_key: String, hi_key: String, lo0: int, hi0: int) -> int:
	var lo: int = int(_f(lo_key, float(lo0)))
	var hi: int = int(_f(hi_key, float(hi0)))
	if hi < lo:
		var swap: int = lo
		lo = hi
		hi = swap
	if hi == lo:
		return lo
	return lo + (randi() % (hi - lo + 1))

static func _frange(lo_key: String, hi_key: String, lo0: float, hi0: float) -> float:
	var lo: float = _f(lo_key, lo0)
	var hi: float = _f(hi_key, hi0)
	if hi < lo:
		var swap: float = lo
		lo = hi
		hi = swap
	return lo + randf() * (hi - lo)

static func _f(key: String, fallback: float) -> float:
	return Food.bal_f(key, fallback)
