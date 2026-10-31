extends Object

## Split from smoke_p7.gd: campaign_check, _campaign_body, _campaign_snap....

const LiveSmoke := preload("res://scripts/debug/playtest/live_smoke.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")
const PlaytestSim := preload("res://scripts/debug/playtest/sim.gd")
const Store := preload("res://scripts/data/save_store.gd")

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

static func _files_snap(slot: String) -> Dictionary:
	var pri: String = Store.primary_path(slot)
	var bak: String = Store.backup_path(slot)
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

static func _files_restore(snap: Dictionary) -> void:
	_restore_save(str(snap.get("pri_path", "")), bool(snap.get("had_pri", false)), str(snap.get("pri", "")))
	_restore_save(str(snap.get("bak_path", "")), bool(snap.get("had_bak", false)), str(snap.get("bak", "")))
