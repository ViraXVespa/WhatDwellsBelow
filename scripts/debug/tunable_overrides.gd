extends Object

## Debug-only balance overrides (design/tunables.md). `path` holds only the keys whose value differs from the shipped
## default (balance/vars_*.gd, enemies.gd). Shared code reaches this file through Dbg.script("tunable_overrides"), so a
## release build (or --wdb-release) never reads it, and saves never carry balance values. Values clamp to the schema range.

const PATH := "user://debug_tunables.json"
## Player settings that live on App.bal but save as their own top-level save keys (store_data.gd DEF).
const PREFS: PackedStringArray = ["aim_line_on", "aim_line_opacity"]

static var path := PATH

static func _ranges(bal: Object) -> Dictionary:
	var out := {}
	for row: Array in bal.schema():
		out[str(row[0])] = Vector2(float(row[1]), float(row[2]))
	return out

## Applies the file to `bal`; returns how many keys were set.
static func apply(bal: Object) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return 0
	var rng := _ranges(bal)
	var n := 0
	for k: Variant in (parsed as Dictionary).keys():
		var key := str(k)
		if not rng.has(key) or key in PREFS:
			continue
		var r: Vector2 = rng[key]
		bal.setv(key, clampf(float((parsed as Dictionary)[k]), r.x, r.y))
		n += 1
	return n

## Writes every non-default key of `bal` (removes the file when none differ); returns the key count.
static func save(bal: Object) -> int:
	var def: Object = (load("res://scripts/data/balance.gd") as GDScript).new()
	var d := {}
	for row: Array in bal.schema():
		var key := str(row[0])
		if key in PREFS:
			continue
		var v: float = bal.getv(key)
		if not is_equal_approx(v, def.getv(key)):
			d[key] = v
	if d.is_empty():
		reset()
		return 0
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t", true))
	return d.size()

static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Debug-menu "Reset to defaults": a fresh balance (player aim-line settings kept) and no override file.
static func reset_bal() -> void:
	var fresh: Object = (load("res://scripts/data/balance.gd") as GDScript).new()
	for k: String in PREFS:
		fresh.set(k, App.bal.get(k))
	App.bal = fresh
	reset()
