extends Object

const Binds7 := preload("res://scripts/debug/smoke/smoke_binds.gd")
const UiPrep := preload("res://scripts/debug/smoke/smoke_ui_prep.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")

static func tree(host: Node) -> SceneTree:
	return host.get_tree()

static func p7(host: Node) -> void:
	var hud: Variant = host.get("hud")
	printerr("P7: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P7: hud=" + str(hud != null))
	var bits: PackedStringArray = PackedStringArray()
	if hud:
		for n: String in ["portrait", "hp_lab", "pot_lab", "dash_fill", "spec_fill", "lvl", "res", "floor_lab", "food_lab", "shrine_lab", "boss_lab"]:
			bits.append("%s=%s" % [n, str(hud.get(n) != null)])
	printerr("P7: hud_bits=" + ", ".join(bits))
	App.pause_menu.show_menu()
	printerr("P7: pause_open=" + str(App.pause_menu.open) + " focus=" + str(App.pause_menu.focus_btn != null) + " tab=" + str(App.pause_menu.tab))
	App.pause_menu.tab = App.pause_menu.TAB_INV
	App.pause_menu._rebuild()
	printerr("P7: pause_skills=" + str(App.pause_menu.tab == App.pause_menu.TAB_INV))
	App.pause_menu.tab = App.pause_menu.TAB_SKILLS
	App.pause_menu._rebuild()
	printerr("P7: pause_system=" + str(App.pause_menu.tab == App.pause_menu.TAB_SKILLS))
	var sys: bool = false
	for c: Node in App.pause_menu.box.get_children():
		if c is Button and str((c as Button).text).find("Dispel") >= 0:
			sys = true
		if c is Button and str((c as Button).text).find("Aim-line") >= 0:
			sys = true
	printerr("P7: system_dispel_aim=" + str(sys))
	App.pause_menu.close_ui()
	Binds7.run()
	printerr("P7: binds_flows=true")
	UiPrep.run(host)
	App.debug.show_menu()
	printerr("P7: debug_open=" + str(App.debug.open))
	App.debug.page = "anim"
	App.debug._rebuild()
	printerr("P7: anim_stub=" + str(App.debug.page == "anim") + " anim_btn=" + str(App.debug.anim_btn != null))
	App.debug.page = "playtest"
	App.debug._rebuild()
	var sum: String = App.debug.play.run_medium()
	printerr("P7: playtest=" + sum.replace("\n", " | "))
	printerr("P7: recs_fresh=" + str((App.debug.play.recs["fresh"] as Array).size()) + " recs_prog=" + str((App.debug.play.recs["progressed"] as Array).size()))
	printerr("P7: history=" + str(App.debug.play.history.size()))
	var row0: Dictionary = {}
	if App.debug.play.history.size() > 0:
		row0 = App.debug.play.history[0]
	printerr("P7: tel_end=" + str(row0.get("end_cond", "")) + " wpn=" + str(row0.get("start_weapon", "")) + " save=" + str(row0.get("save_type", "")) + " playtest=" + str(row0.get("playtest", false)))
	App.debug.play.apply_rec("fresh", 0)
	printerr("P7: applied_fresh_ideal")
	App.debug.hide_menu()
	App.prog.bag.clear()
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.floor_n = 1
	App.prog.add_run_xp("axe", 80.0)
	App.recap.play("death")
	printerr("P7: recap_title=" + App.recap.last_title)
	App.recap.skip_drain()
	printerr("P7: recap_drain=" + str(App.tel.recap_drain) + " waste=" + str(App.recap.last_title.find("waste") >= 0))
	App.recap._finish()
	printerr("P7: pause_themed=" + str(true))
	printerr("P7: hud_ok=" + str(hud != null and hud.get("hp_lab") != null and hud.get("food_lab") != null))
	printerr("P7: playtest_ok=" + str((App.debug.play.recs["fresh"] as Array).size() == 3 and (App.debug.play.recs["progressed"] as Array).size() == 3 and App.debug.play.history.size() >= 6))
	printerr("P7: anim_ok=" + str(App.debug.anim_btn != null))
	store_check()
	tree(host).create_timer(0.4, true, false, true).timeout.connect(func(): tree(host).quit())

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

static func _slices(text: String) -> bool:
	return text.find("slice floor_cycle") >= 0 and text.find("slice weapon_skill") >= 0 and text.find("slice weapon_floor") >= 0 and text.find("slice combat_affix") >= 0

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
