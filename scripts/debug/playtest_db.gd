extends Object

## Debug-desktop JSONL spool under user://playtest/db. Web and release builds skip it.
## An explicit directory (the phase-7 fixture) still writes. The game does not link SQLite.

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")

const DB_DIR := "user://playtest/db"
const FIXTURE_DIR := "user://playtest/smoke-curve"

static func enabled() -> bool:
	return OS.is_debug_build() and not OS.has_feature("web")

static func db_dir() -> String:
	return DB_DIR

static func fixture_dir() -> String:
	return FIXTURE_DIR

static func append_finish(tel: Object, dir_path: String, bot: bool) -> Dictionary:
	if tel == null:
		return {}
	if dir_path == "" and not enabled():
		return {}
	var row: Dictionary = row_from_tel(tel)
	append_run(row, dir_path)
	if not bot:
		return row
	note_weapon_band(row, dir_path)
	if not PlaytestLog.off():
		append_decisions(str(row.get("run_id", "")), PlaytestLog.events, dir_path)
	return row

static func row_from_tel(tel: Object) -> Dictionary:
	var row: Dictionary = tel.call("to_dict")
	row["run_id"] = str(tel.get("run_id"))
	row["seed"] = int(App.run_seed)
	row["save_kind"] = str(tel.get("save_type"))
	if App.prog:
		row["skill_lv"] = App.prog.skill_snap()
		row["gear"] = App.prog.gear_snap()
	else:
		row["skill_lv"] = {}
		row["gear"] = []
	return row

static func append_run(row: Dictionary, dir_path: String) -> void:
	_append_line(_dir(dir_path).path_join("runs.jsonl"), JSON.stringify(row))

static func append_decisions(run_id: String, events: Array, dir_path: String) -> void:
	var wall_now: int = int(Time.get_unix_time_from_system())
	var path: String = _dir(dir_path).path_join("decisions.jsonl")
	for ev: Variant in events:
		if not (ev is Dictionary):
			continue
		var row: Dictionary = (ev as Dictionary).duplicate(true)
		if str(row.get("run_id", "")) == "":
			row["run_id"] = run_id
		if not row.has("wall"):
			row["wall"] = wall_now
		_append_line(path, JSON.stringify(row))

static func note_weapon_band(row: Dictionary, dir_path: String) -> void:
	var wpn: String = str(row.get("start_weapon", ""))
	if wpn == "":
		return
	var path: String = _dir(dir_path).path_join("weapon_band.json")
	var band: Dictionary = _read_json(path)
	if not band.has("great_axe"):
		band["great_axe"] = {}
	if not band.has("staff"):
		band["staff"] = {}
	if not band.has("longbow"):
		band["longbow"] = {}
	var by: Dictionary = band.get(wpn, {})
	if not (by is Dictionary):
		by = {}
	var key: String = str(_weapon_ilvl(row))
	var cur: Dictionary = by.get(key, {})
	if not (cur is Dictionary):
		cur = {}
	var deaths: int = 1 if _is_death(row) else 0
	by[key] = {
		"runs": int(cur.get("runs", 0)) + 1,
		"deaths": int(cur.get("deaths", 0)) + deaths,
		"duration": float(cur.get("duration", 0.0)) + float(row.get("duration", 0.0)),
		"dmg_taken": float(cur.get("dmg_taken", 0.0)) + float(row.get("dmg_taken", 0.0)),
	}
	band[wpn] = by
	_write_json(path, band)

static func clear_dir(dir_path: String) -> void:
	var abs_path: String = _dir(dir_path)
	for leaf: String in ["runs.jsonl", "decisions.jsonl", "weapon_band.json", "curve.sqlite"]:
		var path: String = abs_path.path_join(leaf)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

static func _weapon_ilvl(row: Dictionary) -> int:
	var gear: Variant = row.get("gear", [])
	if gear is Array:
		for piece: Variant in gear:
			if piece is Dictionary and str(piece.get("slot", "")) == "weapon":
				return int(piece.get("ilvl", 0))
	return 0

static func _is_death(row: Dictionary) -> bool:
	var cond: String = str(row.get("end_cond", ""))
	return cond == "death" or cond == "dispel"

static func _dir(dir_path: String) -> String:
	var picked: String = DB_DIR if dir_path == "" else dir_path
	var abs_path: String = picked
	if picked.begins_with("user://") or picked.begins_with("res://"):
		abs_path = ProjectSettings.globalize_path(picked)
	DirAccess.make_dir_recursive_absolute(abs_path)
	return abs_path

static func _append_line(path: String, line: String) -> void:
	var handle: FileAccess = null
	if FileAccess.file_exists(path):
		handle = FileAccess.open(path, FileAccess.READ_WRITE)
		if handle != null:
			handle.seek_end()
	else:
		handle = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		push_error("playtest_db write failed: " + path)
		return
	handle.store_string(line.strip_edges() + "\n")
	handle.close()

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {}
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	if parsed is Dictionary:
		return parsed
	return {}

static func _write_json(path: String, body: Dictionary) -> void:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		push_error("playtest_db write failed: " + path)
		return
	handle.store_string(JSON.stringify(body))
	handle.close()
