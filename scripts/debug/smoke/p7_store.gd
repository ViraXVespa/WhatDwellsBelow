extends Object

## Split from smoke_p7.gd: store_check, _curve, _slices.

const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")

static func store_check() -> void:
	if OS.has_feature("web"):
		printerr("P7: curve_skip=web")
		return
	var spool: String = PlaytestDb.fixture_dir()
	PlaytestDb.clear_dir(spool)
	App.floor_n = 2
	App.tel.reset("human", false)
	App.tel.tick(12.5, false)
	App.tel.note_damage_taken(9.0, 2.0, 20.0)
	App.tel.note_kill_levels(4, 2)
	App.tel.note_kill_levels(4, 2)
	App.tel.note_kill_levels(1, 3)
	App.tel.note_death_levels(4, 2)
	App.tel.note_skill_change("axe", 1, 2)
	App.tel.note_end("death", "grunt")
	var row: Dictionary = PlaytestDb.append_finish(App.tel, spool, false)
	PlaytestDb.note_weapon_band(row, spool)
	var rid: String = str(row.get("run_id", ""))
	var now_wall: int = int(Time.get_unix_time_from_system())
	var events: Array = [
		{"ev": "decide", "run_id": rid, "wall": 0, "why": "old"},
		{"ev": "step", "run_id": rid, "wall": now_wall, "n": 2},
	]
	PlaytestDb.append_decisions(rid, events, spool)
	var abs_dir: String = ProjectSettings.globalize_path(spool)
	var run_path: String = abs_dir.path_join("runs.jsonl")
	var line: String = ""
	for part: String in FileAccess.get_file_as_string(run_path).split("\n"):
		if part.strip_edges() != "":
			line = part
			break
	var parsed: Variant = JSON.parse_string(line)
	var fields_ok: bool = parsed is Dictionary
	if fields_ok:
		var got: Dictionary = parsed
		for key_name: String in ["run_id", "seed", "save_kind", "skill_lv", "gear", "floors", "changes", "kill_delta", "death_delta"]:
			if not got.has(key_name):
				fields_ok = false
		var skills: Variant = got.get("skill_lv", {})
		if not (skills is Dictionary) or (skills as Dictionary).size() != 11:
			fields_ok = false
		var floors: Variant = got.get("floors", [])
		if not (floors is Array) or (floors as Array).is_empty():
			fields_ok = false
	var dec_ok: bool = false
	for part: String in FileAccess.get_file_as_string(abs_dir.path_join("decisions.jsonl")).split("\n"):
		if part.strip_edges() == "":
			continue
		var ev: Variant = JSON.parse_string(part)
		if ev is Dictionary and str(ev.get("run_id", "")) == rid and int(ev.get("n", 0)) == 2:
			dec_ok = true
	printerr("P7: spool_fields=" + str(fields_ok) + " decisions=" + str(dec_ok))
	if not fields_ok or not dec_ok:
		printerr("ERROR: Failed playtest curve spool")
		return
	var first: Dictionary = _curve(abs_dir, PackedStringArray())
	if int(first.get("code", 1)) != 0 or not _slices(str(first.get("text", ""))) or str(first.get("text", "")).find("db runs=1 decisions=2") < 0:
		printerr("P7: curve_out=" + str(first.get("text", "")))
		printerr("ERROR: Failed playtest curve print")
		return
	var imported: Dictionary = _curve(abs_dir, PackedStringArray(["--sqlite", "--keep-days", "30"]))
	var spool_gone: bool = not FileAccess.file_exists(run_path) and not FileAccess.file_exists(abs_dir.path_join("decisions.jsonl"))
	var band_kept: bool = FileAccess.file_exists(abs_dir.path_join("weapon_band.json"))
	var db_kept: bool = FileAccess.file_exists(abs_dir.path_join("curve.sqlite"))
	if int(imported.get("code", 1)) != 0 or not spool_gone or not band_kept or not db_kept or str(imported.get("text", "")).find("db runs=1 decisions=1") < 0:
		printerr("P7: sqlite_out=" + str(imported.get("text", "")))
		printerr("ERROR: Failed playtest curve sqlite")
		return
	App.tel.run_id = "fixture-store-2"
	PlaytestDb.append_run(PlaytestDb.row_from_tel(App.tel), spool)
	var again: Dictionary = _curve(abs_dir, PackedStringArray(["--sqlite", "--keep-days", "30"]))
	var second_gone: bool = not FileAccess.file_exists(run_path)
	if int(again.get("code", 1)) != 0 or not second_gone or str(again.get("text", "")).find("db runs=2 decisions=1") < 0:
		printerr("P7: sqlite2_out=" + str(again.get("text", "")))
		printerr("ERROR: Failed playtest curve sqlite again")
		return
	var cleaned: Dictionary = _curve(abs_dir, PackedStringArray(["--cleanup", "--keep-days", "30"]))
	if int(cleaned.get("code", 1)) != 0 or str(cleaned.get("text", "")).find("db runs=2 decisions=1") < 0:
		printerr("P7: cleanup_out=" + str(cleaned.get("text", "")))
		printerr("ERROR: Failed playtest curve cleanup")
		return
	printerr("P7: curve_ok=true")

static func _curve(abs_dir: String, extra: PackedStringArray) -> Dictionary:
	var py: String = ProjectSettings.globalize_path("res://tools/perf.py")
	var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var args: PackedStringArray = PackedStringArray(["-u", py, "curve", "--root", root, "--dir", abs_dir])
	args.append_array(extra)
	var out: Array = []
	var code: int = OS.execute("python", args, out, true, false)
	var text := ""
	for line: Variant in out:
		if text != "":
			text += "\n"
		text += str(line)
	return {"code": code, "text": text}

static func _slices(text: String) -> bool:
	return text.find("slice floor_cycle") >= 0 and text.find("slice weapon_skill") >= 0 and text.find("slice weapon_floor") >= 0 and text.find("slice combat_affix") >= 0
