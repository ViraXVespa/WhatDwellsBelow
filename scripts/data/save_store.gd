extends RefCounted

## Primary + backup saves. Isolated live vs playtest slots.

static var _migrated := false

const LIVE := "user://live"
const FRESH := "user://playtest/fresh"
const PROG := "user://playtest/progressed"
const Io := preload("res://scripts/data/save_store_io.gd")
const Data := preload("res://scripts/data/save_store_data.gd")
const Collect := preload("res://scripts/data/save_store_collect.gd")


static func dir_for(slot: String) -> String:
	return Io.dir_for(slot)


static func primary_path(slot: String) -> String:
	return Io.primary_path(slot)


static func backup_path(slot: String) -> String:
	return Io.backup_path(slot)


static func ensure_dir(slot: String) -> void:
	Io.ensure_dir(slot)


static func write_payload(path: String, data: Dictionary) -> bool:
	return Io.write_payload(path, data)


static func read_payload(path: String) -> Dictionary:
	return Io.read_payload(path)


static func collect() -> Dictionary:
	return Collect.collect()


static func apply(data: Dictionary) -> void:
	_migrated = Data.apply(data)


static func _display_mode(raw: String) -> String:
	return Data.display_mode(raw)


static func _fs_kind(raw: String) -> String:
	return Data.fs_kind(raw)


static func _persist_if_migrated(slot: String) -> void:
	if not _migrated:
		return
	_migrated = false
	save_slot(slot)


static func save_slot(slot := "live") -> bool:
	ensure_dir(slot)
	var data: Dictionary = collect()
	var pri := primary_path(slot)
	var bak := backup_path(slot)
	if FileAccess.file_exists(pri):
		var old: Dictionary = read_payload(pri)
		if not old.is_empty():
			write_payload(bak, old)
	if not write_payload(pri, data):
		return false
	if not FileAccess.file_exists(bak):
		write_payload(bak, data)
	return true


static func load_slot(slot := "live") -> String:
	ensure_dir(slot)
	var pri: Dictionary = read_payload(primary_path(slot))
	if not pri.is_empty() and int(pri.get("v", 0)) >= 1:
		apply(pri)
		write_payload(backup_path(slot), pri)
		_persist_if_migrated(slot)
		return "primary"
	var bak: Dictionary = read_payload(backup_path(slot))
	if not bak.is_empty() and int(bak.get("v", 0)) >= 1:
		apply(bak)
		write_payload(primary_path(slot), bak)
		_persist_if_migrated(slot)
		return "backup"
	fresh_delver()
	return "fresh"


static func fresh_delver() -> void:
	Data.fresh_delver()


static func wipe_slot(slot: String) -> void:
	ensure_dir(slot)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(primary_path(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path(slot)))


static func corrupt_primary(slot: String) -> void:
	ensure_dir(slot)
	var f := FileAccess.open(primary_path(slot), FileAccess.WRITE)
	if f:
		f.store_string("{not-json")
