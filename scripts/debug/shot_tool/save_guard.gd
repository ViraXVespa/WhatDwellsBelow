extends RefCounted

## Menu-screen shots (title, splash, fullscreen gate) boot real scenes whose buttons save. A shot boot never loads user://live
## and App.save_now() writes the smoke slot while a smoke flag is active; this guard proves it: arm() refuses (the shot fails
## loudly) when the smoke slot is not a different folder from the live slot, and check() fails the flow if the live save changed.

const Store := preload("res://scripts/data/save_store.gd")

static var _armed: bool = false
static var _live_before: String = ""

static func _sig() -> String:
	var parts: PackedStringArray = []
	for path: String in [Store.primary_path("live"), Store.backup_path("live")]:
		if not FileAccess.file_exists(path):
			parts.append("absent")
			continue
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		parts.append("%d@%d" % [f.get_length() if f != null else -1, FileAccess.get_modified_time(path)])
	return "|".join(parts)

## "" when isolated and armed; else why not.
static func arm() -> String:
	if not App.Smoke.active():
		return "no smoke flag is active, so App.save_now() would write the live slot"
	if Store.dir_for("smoke") == Store.dir_for("live") or not Store.dir_for("smoke").begins_with("user://playtest/"):
		return "the smoke slot is not a separate folder from the live slot"
	_live_before = _sig()
	_armed = true
	return ""

## "" when the live save is untouched (or the guard was never armed).
static func check() -> String:
	if not _armed:
		return ""
	var now: String = _sig()
	return "" if now == _live_before else "the live save changed during the shot (%s -> %s)" % [_live_before, now]
