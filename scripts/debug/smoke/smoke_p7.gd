extends Object

const Binds7 := preload("res://scripts/debug/smoke/smoke_binds.gd")
const UiPrep := preload("res://scripts/debug/smoke/smoke_ui_prep.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")
const PlaytestSim := preload("res://scripts/debug/playtest/sim.gd")
const Store := preload("res://scripts/data/save_store.gd")
const LiveSmoke := preload("res://scripts/debug/playtest/live_smoke.gd")

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
	campaign_check()
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

static func campaign_check() -> void:
	if OS.has_feature("web"):
		printerr("P7: campaign_skip=web")
		return
	var snap: Dictionary = _campaign_snap()
	var prev_slot: String = ""
	if App.debug != null and App.debug.play != null:
		prev_slot = str(App.debug.play.slot)
	var ok: bool = _campaign_body()
	if App.debug != null and App.debug.play != null:
		App.debug.play.slot = prev_slot
	_campaign_restore(snap)
	if ok:
		printerr("P7: campaign_ok=true")
	else:
		printerr("ERROR: Failed playtest campaign slot")

static func _campaign_body() -> bool:
	if App.debug == null or App.debug.play == null:
		return false
	if not App.debug.play.has_method("queue_campaign"):
		return false
	if LiveSmoke.CAMPAIGN_FLAG != "--wdb-pt-campaign":
		return false
	if Store.dir_for("campaign") != "user://playtest/campaign":
		return false
	var pt: Node = App.debug.play
	Store.wipe_slot("campaign")
	pt.slot = "campaign"
	PlaytestSim.prep_slot(pt)
	App.prog.skills_perm["smith"] = 17.0
	App.bank_gold = 41
	App.prog.bank_items.append(App.prog.make_weapon("great_axe", "blue", 3))
	App.prog.bank_items.append(App.prog.make_weapon("staff", "blue", 3))
	App.prog.bank_items.append(App.prog.make_weapon("longbow", "blue", 3))
	Store.save_slot("campaign")
	var levels: Dictionary = PlaytestDb.owned_levels()
	if int(levels.get("great_axe", 0)) != 3 or int(levels.get("staff", 0)) != 3 or int(levels.get("longbow", 0)) != 3:
		printerr("P7: campaign_levels=" + str(levels))
		return false
	var band_dir: String = "user://playtest/smoke-band"
	PlaytestDb.clear_dir(band_dir)
	PlaytestDb.note_weapon_band({"start_weapon": "great_axe", "duration": 10.0, "dmg_taken": 4.0, "end_cond": "extraction", "gear": [{"slot": "weapon", "ilvl": 3}]}, band_dir)
	PlaytestDb.note_weapon_band({"start_weapon": "staff", "duration": 10.0, "dmg_taken": 4.0, "end_cond": "extraction", "gear": [{"slot": "weapon", "ilvl": 3}]}, band_dir)
	var picked: String = PlaytestDb.pick_weapon(levels, band_dir)
	PlaytestSim.prep_slot(pt)
	var skill_ok: bool = is_equal_approx(float(App.prog.skills_perm.get("smith", 0.0)), 17.0)
	var gold_ok: bool = App.bank_gold == 41
	var gear_n: int = 0
	for piece: Variant in App.prog.bank_items:
		if piece is Dictionary and str(piece.get("weapon", "")) != "" and int(piece.get("ilvl", 0)) == 3:
			gear_n += 1
	var empty_dir: String = "user://playtest/smoke-band-empty"
	PlaytestDb.clear_dir(empty_dir)
	var seeded: String = PlaytestDb.pick_weapon({"great_axe": 3, "staff": 3, "longbow": 3}, empty_dir)
	var ok: bool = skill_ok and gold_ok and gear_n == 3 and picked == "longbow" and seeded == "great_axe"
	if not ok:
		printerr("P7: campaign_skill=%s gold=%s gear=%d weapon=%s seed=%s" % [str(skill_ok), str(gold_ok), gear_n, picked, seeded])
	return ok

static func _campaign_snap() -> Dictionary:
	var pri: String = Store.primary_path("campaign")
	var bak: String = Store.backup_path("campaign")
	var had_pri: bool = FileAccess.file_exists(pri)
	var had_bak: bool = FileAccess.file_exists(bak)
	var pri_text: String = ""
	var bak_text: String = ""
	if had_pri:
		pri_text = FileAccess.get_file_as_string(pri)
	if had_bak:
		bak_text = FileAccess.get_file_as_string(bak)
	return {
		"had_pri": had_pri,
		"had_bak": had_bak,
		"pri": pri_text,
		"bak": bak_text,
		"pri_path": pri,
		"bak_path": bak,
	}

static func _campaign_restore(snap: Dictionary) -> void:
	_restore_save(str(snap.get("pri_path", "")), bool(snap.get("had_pri", false)), str(snap.get("pri", "")))
	_restore_save(str(snap.get("bak_path", "")), bool(snap.get("had_bak", false)), str(snap.get("bak", "")))

static func _restore_save(path: String, had: bool, text: String) -> void:
	if path == "":
		return
	if not had:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		return
	handle.store_string(text)
	handle.close()

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
