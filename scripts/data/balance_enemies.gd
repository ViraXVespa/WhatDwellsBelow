extends Object

const IDS: PackedStringArray = [
	"slime", "goblin", "orc", "skeleton", "bat", "spider",
	"archer", "shaman", "imp", "wolf", "beetle", "wisp",
]


static func defaults() -> Dictionary:
	return {
		"slime": {"hp": 48.0, "dmg": 6.0, "spd": 2.2, "range": 0.95, "def": 2.0},
		"goblin": {"hp": 64.0, "dmg": 8.0, "spd": 3.15, "range": 1.15, "def": 1.0},
		"orc": {"hp": 116.0, "dmg": 12.0, "spd": 2.05, "range": 1.35, "def": 8.0},
		"skeleton": {"hp": 72.0, "dmg": 9.0, "spd": 2.7, "range": 1.2, "def": 3.0},
		"bat": {"hp": 40.0, "dmg": 7.0, "spd": 4.05, "range": 0.9, "def": 0.0},
		"spider": {"hp": 56.0, "dmg": 8.0, "spd": 3.25, "range": 1.05, "def": 2.0},
		"archer": {"hp": 52.0, "dmg": 7.0, "spd": 2.85, "range": 6.2, "def": 1.0},
		"shaman": {"hp": 60.0, "dmg": 11.0, "spd": 2.35, "range": 3.4, "def": 2.0},
		"imp": {"hp": 44.0, "dmg": 10.0, "spd": 3.55, "range": 4.2, "def": 0.0},
		"wolf": {"hp": 68.0, "dmg": 10.0, "spd": 3.85, "range": 1.1, "def": 2.0},
		"beetle": {"hp": 104.0, "dmg": 9.0, "spd": 1.85, "range": 1.05, "def": 10.0},
		"wisp": {"hp": 36.0, "dmg": 8.0, "spd": 2.95, "range": 5.4, "def": 0.0},
	}


static func parse_key(name: String) -> Array:
	if not name.begins_with("e_"):
		return []
	var cut := name.substr(2)
	var us := cut.rfind("_")
	if us <= 0:
		return []
	return [cut.substr(0, us), cut.substr(us + 1)]


static func fill(stats: Dictionary) -> void:
	if not stats.is_empty():
		return
	var src := defaults()
	for id in src.keys():
		stats[id] = (src[id] as Dictionary).duplicate()


static func read_stat(stats: Dictionary, name: String) -> float:
	var ek := parse_key(name)
	if ek.size() != 2:
		return 0.0
	var id := str(ek[0])
	var key := str(ek[1])
	if stats.has(id) and (stats[id] as Dictionary).has(key):
		return float((stats[id] as Dictionary)[key])
	return 0.0


static func write_stat(stats: Dictionary, name: String, value: float) -> bool:
	var ek := parse_key(name)
	if ek.size() != 2:
		return false
	var id := str(ek[0])
	var key := str(ek[1])
	if not stats.has(id):
		stats[id] = {}
	(stats[id] as Dictionary)[key] = value
	return true


static func append_schema(rows: Array) -> void:
	for id in IDS:
		rows.append(["e_%s_hp" % id, 5.0, 200.0, 1.0])
		rows.append(["e_%s_dmg" % id, 1.0, 80.0, 1.0])
		rows.append(["e_%s_spd" % id, 0.4, 8.0, 0.05])
		rows.append(["e_%s_range" % id, 0.4, 12.0, 0.05])
		rows.append(["e_%s_def" % id, 0.0, 40.0, 1.0])
