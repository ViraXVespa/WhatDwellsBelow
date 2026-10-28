extends Object

## Debug-desktop JSONL spool under user://playtest/db. Web and release builds skip it.
## An explicit directory (the phase-7 fixture) still writes. The game does not link SQLite.

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Make := preload("res://scripts/data/progress/progress_make.gd")

const DB_DIR := "user://playtest/db"
const FIXTURE_DIR := "user://playtest/smoke-curve"
const WEAPONS: PackedStringArray = ["great_axe", "staff", "longbow"]

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

static func owned_levels() -> Dictionary:
	var starter: int = Make._area_ilvl()
	var out: Dictionary = {
		"great_axe": starter,
		"staff": starter,
		"longbow": starter,
	}
	if App.prog == null:
		return out
	var best: Dictionary = {"great_axe": -1, "staff": -1, "longbow": -1}
	_consider_owned(best, App.prog.slots.get("weapon", {}))
	_consider_list(best, App.prog.bag)
	_consider_list(best, App.prog.bank_items)
	_consider_list(best, App.prog.holds.get("weapon", []))
	for wpn: String in WEAPONS:
		if int(best.get(wpn, -1)) >= 0:
			out[wpn] = int(best[wpn])
	return out

static func pick_weapon(levels: Dictionary, dir_path: String) -> String:
	var band: Dictionary = _read_json(_dir(dir_path).path_join("weapon_band.json"))
	var shared: int = int(levels.get("great_axe", 1))
	var staff_lv: int = int(levels.get("staff", 1))
	var bow_lv: int = int(levels.get("longbow", 1))
	if staff_lv < shared:
		shared = staff_lv
	if bow_lv < shared:
		shared = bow_lv
	var level: int = shared
	if not _level_has_rows(band, level):
		level = shared - 1
	if level < 0 or not _level_has_rows(band, level):
		return _seed_weapon(band)
	return _furthest_behind(band, level)

static func clear_dir(dir_path: String) -> void:
	var abs_path: String = _dir(dir_path)
	for leaf: String in ["runs.jsonl", "decisions.jsonl", "weapon_band.json", "curve.sqlite"]:
		var path: String = abs_path.path_join(leaf)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

static func _consider_list(best: Dictionary, raw: Variant) -> void:
	if not (raw is Array):
		return
	for piece: Variant in raw:
		_consider_owned(best, piece)

static func _consider_owned(best: Dictionary, raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	var it: Dictionary = raw
	if str(it.get("slot", "")) != "weapon":
		return
	if str(it.get("rarity", "white")) == "white":
		return
	var wpn: String = str(it.get("weapon", ""))
	if not best.has(wpn):
		return
	var lv: int = int(it.get("ilvl", 0))
	if lv > int(best[wpn]):
		best[wpn] = lv

static func _level_has_rows(band: Dictionary, level: int) -> bool:
	for wpn: String in WEAPONS:
		if int(_band_bucket(band, wpn, level).get("runs", 0)) > 0:
			return true
	return false

static func _seed_weapon(band: Dictionary) -> String:
	var fewest: String = str(WEAPONS[0])
	var fewest_n: int = _total_runs(band, fewest)
	for wpn: String in WEAPONS:
		var n: int = _total_runs(band, wpn)
		if n == 0:
			return wpn
		if n < fewest_n:
			fewest = wpn
			fewest_n = n
	return fewest

static func _furthest_behind(band: Dictionary, level: int) -> String:
	var max_death: float = 0.0
	var max_dur: float = 0.0
	var max_dmg: float = 0.0
	for wpn: String in WEAPONS:
		var bucket: Dictionary = _band_bucket(band, wpn, level)
		var runs: int = int(bucket.get("runs", 0))
		if runs <= 0:
			continue
		var death_rate: float = float(bucket.get("deaths", 0)) / float(runs)
		var mean_dur: float = float(bucket.get("duration", 0.0)) / float(runs)
		var mean_dmg: float = float(bucket.get("dmg_taken", 0.0)) / float(runs)
		if death_rate > max_death:
			max_death = death_rate
		if mean_dur > max_dur:
			max_dur = mean_dur
		if mean_dmg > max_dmg:
			max_dmg = mean_dmg
	var chosen: String = ""
	var chosen_missing: bool = false
	var chosen_score: float = -1.0
	var chosen_runs: int = 0
	for wpn2: String in WEAPONS:
		var cur: Dictionary = _band_bucket(band, wpn2, level)
		var runs2: int = int(cur.get("runs", 0))
		var missing: bool = runs2 <= 0
		var score: float = 0.0
		if not missing:
			var death_rate2: float = float(cur.get("deaths", 0)) / float(runs2)
			var mean_dur2: float = float(cur.get("duration", 0.0)) / float(runs2)
			var mean_dmg2: float = float(cur.get("dmg_taken", 0.0)) / float(runs2)
			if max_death > 0.0:
				score += death_rate2 / max_death
			if max_dur > 0.0:
				score += mean_dur2 / max_dur
			if max_dmg > 0.0:
				score += mean_dmg2 / max_dmg
		var better: bool = chosen == ""
		if not better and missing and not chosen_missing:
			better = true
		elif not better and missing == chosen_missing:
			if missing:
				if runs2 < chosen_runs:
					better = true
			elif score > chosen_score:
				better = true
			elif is_equal_approx(score, chosen_score) and runs2 < chosen_runs:
				better = true
		if better:
			chosen = wpn2
			chosen_missing = missing
			chosen_score = score
			chosen_runs = runs2
	return chosen

static func _total_runs(band: Dictionary, wpn: String) -> int:
	var by_v: Variant = band.get(wpn, {})
	if not (by_v is Dictionary):
		return 0
	var n: int = 0
	for key: Variant in (by_v as Dictionary).keys():
		var cur_v: Variant = (by_v as Dictionary).get(key, {})
		if cur_v is Dictionary:
			n += int((cur_v as Dictionary).get("runs", 0))
	return n

static func _band_bucket(band: Dictionary, wpn: String, level: int) -> Dictionary:
	var by_v: Variant = band.get(wpn, {})
	if not (by_v is Dictionary):
		return {}
	var cur_v: Variant = (by_v as Dictionary).get(str(level), {})
	if cur_v is Dictionary:
		return cur_v
	return {}

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
