extends Object

## Dungeon generation map dump. Flag: --wdb-dungeon-map-smoke
## Optional: --wdb-dungeon-map-seed=42 --wdb-dungeon-map-floor=1 --wdb-dungeon-map-scale=8
## Lines: MAP: key=value  (and MAP: ascii= rows). Not a numbered phase.

const FLAG := "--wdb-dungeon-map-smoke"
const Dump := preload("res://scripts/debug/dungeon_map_dump.gd")

static var _cached := -1

static func _flag_on() -> bool:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return FLAG in user
	return FLAG in OS.get_cmdline_args()


static func active() -> bool:
	if _cached < 0:
		_cached = 1 if _flag_on() else 0
	return _cached == 1


static func _args() -> PackedStringArray:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return user
	return OS.get_cmdline_args()


static func _arg_int(key: String, fallback: int) -> int:
	var prefix: String = key + "="
	for a: String in _args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return int(s.substr(prefix.length()))
	return fallback


static func run_seed() -> int:
	var n: int = _arg_int("--wdb-dungeon-map-seed", 42)
	if n == 0:
		return 1
	return n


static func floor_n() -> int:
	return maxi(1, _arg_int("--wdb-dungeon-map-floor", 1))


static func ascii_scale() -> int:
	return clampi(_arg_int("--wdb-dungeon-map-scale", 8), 4, 16)


static func dump_floor(host: Node) -> void:
	Dump.dump_floor(host)
