extends RefCounted

## Primary + backup saves. Isolated live vs playtest slots.

static var _migrated := false

const LIVE := "user://live"
const FRESH := "user://playtest/fresh"
const PROG := "user://playtest/progressed"


static func dir_for(slot: String) -> String:
	if slot == "fresh":
		return FRESH
	if slot == "progressed":
		return PROG
	return LIVE


static func primary_path(slot: String) -> String:
	return dir_for(slot).path_join("save.json")


static func backup_path(slot: String) -> String:
	return dir_for(slot).path_join("save.bak.json")


static func ensure_dir(slot: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_for(slot)))


static func write_payload(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return {}
	var parsed: Variant = j.data
	if parsed is Dictionary:
		return parsed
	return {}


static func collect() -> Dictionary:
	return {
		"v": 1,
		"bal_rev": App.bal.BAL_REV,
		"character_type": App.character_type,
		"character_chosen": App.character_chosen,
		"cam_zoom": App.cam_zoom,
		"hud_scale": App.hud_scale,
		"vol_master": App.vol_master,
		"vol_music": App.vol_music,
		"vol_sfx": App.vol_sfx,
		"aim_line_on": App.bal.aim_line_on,
		"aim_line_opacity": App.bal.aim_line_opacity,
		"bank_gold": App.bank_gold,
		"bank_ore": App.bank_ore,
		"bank_wood": App.bank_wood,
		"bank_root": App.bank_root,
		"binds": App.collect_binds(),
		"debug_bal": App.bal.snapshot(),
		"prog": App.prog.to_meta(),
	}


static func apply(data: Dictionary) -> void:
	_migrated = false
	App.character_type = str(data.get("character_type", "male"))
	App.character_chosen = bool(data.get("character_chosen", false))
	App.cam_zoom = float(data.get("cam_zoom", 1.0))
	App.hud_scale = float(data.get("hud_scale", 1.0))
	App.vol_master = float(data.get("vol_master", 1.0))
	App.vol_music = float(data.get("vol_music", 0.7))
	App.vol_sfx = float(data.get("vol_sfx", 0.85))
	App.bal.aim_line_on = bool(data.get("aim_line_on", true))
	App.bal.aim_line_opacity = float(data.get("aim_line_opacity", 0.85))
	App.bank_gold = int(data.get("bank_gold", 0))
	App.bank_ore = int(data.get("bank_ore", 0))
	App.bank_wood = int(data.get("bank_wood", 0))
	App.bank_root = int(data.get("bank_root", 0))
	var db: Variant = data.get("debug_bal", {})
	if db is Dictionary:
		for k in (db as Dictionary).keys():
			App.bal.setv(str(k), float((db as Dictionary)[k]))
	var old_rev := int(data.get("bal_rev", 0))
	if App.bal.has_method("migrate_from") and App.bal.migrate_from(old_rev):
		_migrated = true
	var p: Variant = data.get("prog", {})
	if p is Dictionary:
		App.prog.from_meta(p)
	if not App.character_chosen and (App.bank_gold > 0 or App.bank_ore > 0 or App.prog.deepest > 1):
		App.character_chosen = true
	var binds: Variant = data.get("binds", [])
	if binds is Array and (binds as Array).size() > 0:
		App.apply_binds(binds)
	App.set_volume("master", App.vol_master)
	App.set_volume("music", App.vol_music)
	App.set_volume("sfx", App.vol_sfx)


static func _persist_if_migrated(slot: String) -> void:
	if not _migrated:
		return
	_migrated = false
	save_slot(slot)


static func save_slot(slot := "live") -> bool:
	ensure_dir(slot)
	var data := collect()
	var pri := primary_path(slot)
	var bak := backup_path(slot)
	if FileAccess.file_exists(pri):
		var old := read_payload(pri)
		if not old.is_empty():
			write_payload(bak, old)
	if not write_payload(pri, data):
		return false
	if not FileAccess.file_exists(bak):
		write_payload(bak, data)
	return true


static func load_slot(slot := "live") -> String:
	ensure_dir(slot)
	var pri := read_payload(primary_path(slot))
	if not pri.is_empty() and int(pri.get("v", 0)) >= 1:
		apply(pri)
		write_payload(backup_path(slot), pri)
		_persist_if_migrated(slot)
		return "primary"
	var bak := read_payload(backup_path(slot))
	if not bak.is_empty() and int(bak.get("v", 0)) >= 1:
		apply(bak)
		write_payload(primary_path(slot), bak)
		_persist_if_migrated(slot)
		return "backup"
	fresh_delver()
	return "fresh"


static func fresh_delver() -> void:
	App.prog.reset_meta()
	App.bank_gold = 0
	App.bank_ore = 0
	App.bank_wood = 0
	App.bank_root = 0
	App.bal = (load("res://scripts/data/balance.gd") as GDScript).new()
	App.character_type = "male"
	App.character_chosen = false
	App.cam_zoom = 1.0
	App.hud_scale = 1.0
	App.vol_master = 1.0
	App.vol_music = 0.7
	App.vol_sfx = 0.85
	App.bal.aim_line_on = true
	App.bal.aim_line_opacity = 0.85
	App.reset_binds()
	App.set_volume("master", App.vol_master)
	App.set_volume("music", App.vol_music)
	App.set_volume("sfx", App.vol_sfx)


static func wipe_slot(slot: String) -> void:
	ensure_dir(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(primary_path(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path(slot)))


static func corrupt_primary(slot: String) -> void:
	ensure_dir(slot)
	var f := FileAccess.open(primary_path(slot), FileAccess.WRITE)
	if f:
		f.store_string("{not-json")