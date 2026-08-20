class_name Artifacts
extends Object

## Demo run-bound relics. Instant apply, no bag, cannot extract.

const CATALOG := [
	{"id": "iron_appetite", "name": "Iron Appetite", "desc": "+15% damage. The hole likes a heavy swing.", "price": 55},
	{"id": "deep_pockets", "name": "Deep Pockets", "desc": "+25% gold from kills and smashables.", "price": 45},
	{"id": "quick_vein", "name": "Quick Vein", "desc": "+20% mining speed.", "price": 50},
	{"id": "second_wind", "name": "Second Wind", "desc": "+20 max HP this run.", "price": 60},
	{"id": "fleet_foot", "name": "Fleet Foot", "desc": "+12% move speed.", "price": 50},
	{"id": "short_fuse", "name": "Short Fuse", "desc": "Dash recovers 15% faster.", "price": 55},
	{"id": "heavy_hands", "name": "Heavy Hands", "desc": "Slam hits 20% harder.", "price": 50},
	{"id": "lucky_spark", "name": "Lucky Spark", "desc": "Mining sometimes pops extra ore.", "price": 40},
]


static func by_id(id: String) -> Dictionary:
	for row in CATALOG:
		if str(row.id) == id:
			return row
	return {}


static func pick(rng: RandomNumberGenerator, exclude: Array = []) -> Dictionary:
	var pool: Array = []
	for row in CATALOG:
		if not exclude.has(str(row.id)):
			pool.append(row)
	if pool.is_empty():
		pool = CATALOG.duplicate()
	return pool[rng.randi_range(0, pool.size() - 1)]


static func apply(run: RunState, id: String) -> String:
	if run == null or id == "":
		return ""
	if run.artifact_ids.has(id):
		return ""
	run.artifact_ids.append(id)
	match id:
		"second_wind":
			run.max_hp += 20.0
			run.hp = minf(run.max_hp, run.hp + 20.0)
		"fleet_foot":
			run.move_mult *= 1.12
		"short_fuse":
			run.dash_cd_mult *= 0.85
		"heavy_hands":
			run.slam_dmg_mult *= 1.2
		"iron_appetite":
			run.dmg_mult *= 1.15
		"deep_pockets":
			run.gold_mult *= 1.25
		"quick_vein":
			run.mine_mult *= 1.2
		"lucky_spark":
			run.lucky_mine = true
	var row := by_id(id)
	return str(row.get("name", id))
