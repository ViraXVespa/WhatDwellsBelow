extends Object

## Food profiles and the food stat fill, shared by item make (progress_make) and the consumable helpers. Leaf: no preloads.

const FOOD_PROF := {
	"ration": {"heal": "food_ration_heal", "heal0": 40.0, "secs": "food_ration_secs", "secs0": 8.0, "bonus": "def", "amt": "food_ration_bonus", "amt0": 1.0, "nk": "gear.ration"},
	"trail_bread": {"heal": "food_bread_heal", "heal0": 28.0, "secs": "food_bread_secs", "secs0": 12.0, "bonus": "move_spd", "amt": "food_bread_bonus", "amt0": 0.05, "nk": "progress_make.trail_bread"},
	"stew": {"heal": "food_stew_heal", "heal0": 56.0, "secs": "food_stew_secs", "secs0": 6.0, "bonus": "hp", "amt": "food_stew_bonus", "amt0": 4.0, "nk": "gear.stew"},
	"moldy_bread": {"heal": "food_moldy_heal", "heal0": 14.0, "secs": "food_moldy_secs", "secs0": 8.0, "bonus": "", "amt": "food_moldy_bonus", "amt0": 0.0, "nk": "gear.moldy_bread"},
}

static func decorate_food(it: Dictionary) -> Dictionary:
	var fid: String = str(it.get("food", "ration"))
	var key: String = "trail_bread" if fid == "bread" else fid
	var prof: Dictionary = FOOD_PROF.get(key, FOOD_PROF["ration"])
	it["heal"] = bal_f(str(prof["heal"]), float(prof["heal0"]))
	it["heal_secs"] = bal_f(str(prof["secs"]), float(prof["secs0"]))
	it["bonus_id"] = str(prof["bonus"])
	it["bonus_amt"] = bal_f(str(prof["amt"]), float(prof["amt0"]))
	var nk: String = str(prof["nk"])
	if nk != "" and (key == "stew" or key == "moldy_bread"):
		it["nk"] = [nk]
		it["name"] = App.tr(nk)
	return it

static func bal_f(key: String, fallback: float) -> float:
	if App.bal == null:
		return fallback
	var v: Variant = App.bal.get(key)
	if v == null:
		return fallback
	return float(v)
