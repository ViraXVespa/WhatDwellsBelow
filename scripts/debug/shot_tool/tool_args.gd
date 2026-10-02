extends RefCounted

## Postcard shot CLI arg readers. Leaf module.

const FLAG := "--wdb-shot"
const CliArgs := preload("res://scripts/debug/cli_args.gd")

static var _cached: int = -1

static func args() -> PackedStringArray:
	return CliArgs.args()

static func _flag_on() -> bool:
	return FLAG in args()

static func active() -> bool:
	if _cached < 0:
		_cached = 1 if _flag_on() else 0
	return _cached == 1

static func _arg_int(key: String, fallback: int) -> int:
	return CliArgs.int_arg(key, fallback)

static func _arg_val(flag: String) -> String:
	var prefix: String = flag + "="
	for a: String in args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return ""

static func _arg_str(key: String, fallback: String) -> String:
	var prefix: String = key + "="
	for a: String in args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return s.substr(prefix.length())
	return fallback

static func scene_name() -> String:
	var s: String = _arg_str("--wdb-shot-scene", "dungeon")
	if s == "camp" or s == "hub":
		return "camp"
	return "dungeon"

static func run_seed() -> int:
	var n: int = _arg_int("--wdb-shot-seed", 42)
	if n == 0:
		return 1
	return n

static func floor_n() -> int:
	return maxi(1, _arg_int("--wdb-shot-floor", 1))

static func out_path() -> String:
	var p: String = _arg_str("--wdb-shot-out", "")
	if p != "":
		return p
	return ProjectSettings.globalize_path("user://wdb_shot.png")

static func scale_pct() -> int:
	return clampi(_arg_int("--wdb-shot-scale", 100), 1, 100)

static func settle_sec() -> float:
	var ms: int = maxi(0, _arg_int("--wdb-shot-settle-ms", 1000))
	return float(ms) / 1000.0

static func hud_on() -> bool:
	return _arg_int("--wdb-shot-hud", 1) != 0

static func poses() -> PackedStringArray:
	var raw: String = _arg_val("--wdb-shot-poses")
	if raw.is_empty():
		return PackedStringArray()
	return raw.split(";")

static func zoom() -> float:
	var raw: String = _arg_val("--wdb-shot-zoom")
	if raw.is_empty():
		return 1.0
	return maxf(0.01, raw.to_float())

static func has_player_pos() -> bool:
	return not _arg_val("--wdb-shot-px").is_empty() or not _arg_val("--wdb-shot-pz").is_empty()

static func player_x() -> float:
	return _arg_val("--wdb-shot-px").to_float()

static func player_z() -> float:
	return _arg_val("--wdb-shot-pz").to_float()

static func cam_x() -> float:
	return _arg_val("--wdb-shot-cx").to_float()

static func cam_z() -> float:
	return _arg_val("--wdb-shot-cz").to_float()

static func steps_path() -> String:
	return _arg_str("--wdb-shot-steps", "")

static func frames_dir() -> String:
	var d: String = _arg_str("--wdb-shot-frames", "")
	if d != "":
		return d
	return out_path().get_base_dir()

static func show_window() -> bool:
	return _arg_int("--wdb-shot-show", 0) != 0

static func no_pixels() -> bool:
	return _arg_int("--wdb-shot-nopix", 0) != 0

static func win_size() -> Vector2i:
	return Vector2i(maxi(0, _arg_int("--wdb-shot-width", 0)), maxi(0, _arg_int("--wdb-shot-height", 0)))
