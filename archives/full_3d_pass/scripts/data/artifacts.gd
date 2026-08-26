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
	var hp_before := run.hp
	run._apply_armor_non_hp()
	if id == "second_wind":
		run.hp = minf(run.max_hp, hp_before + 20.0)
	var row := by_id(id)
	return str(row.get("name", id))
