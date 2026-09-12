extends RefCounted

## Save path helpers and JSON payload IO.

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
