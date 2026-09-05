extends Object

## Animation Browser review ledger. Not part of SaveStore / live settings.
## Disk file is editor-only under the live checkout and is gitignored.

const DIR := "res://tools/anim_review"
const PATH := "res://tools/anim_review/review.json"
const GOOD := "good"
const REPACK := "repack"
const REGEN := "regenerate"
const ORDER: Array[String] = [GOOD, REPACK, REGEN]

static var mem: Dictionary = {}
static var loaded: bool = false


static func clip_key(model_id: String, facing: String, anim: String) -> String:
	return "%s/%s/%s" % [model_id, facing, anim]


static func can_review(frame_n: int) -> bool:
	return frame_n > 1


static func can_write() -> bool:
	return OS.has_feature("editor")


static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	mem = {}
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return
	var parsed: Variant = j.data
	if not (parsed is Dictionary):
		return
	var clips: Variant = (parsed as Dictionary).get("clips", {})
	if not (clips is Dictionary):
		return
	for k in (clips as Dictionary).keys():
		var row: Variant = (clips as Dictionary)[k]
		if not (row is Dictionary):
			continue
		var st := str((row as Dictionary).get("state", GOOD))
		if st != REPACK and st != REGEN:
			continue
		mem[str(k)] = {
			"state": st,
			"note": str((row as Dictionary).get("note", "")),
		}


static func row(model_id: String, facing: String, anim: String) -> Dictionary:
	ensure_loaded()
	var k := clip_key(model_id, facing, anim)
	if mem.has(k):
		return mem[k]
	return {"state": GOOD, "note": ""}


static func state_of(model_id: String, facing: String, anim: String) -> String:
	return str(row(model_id, facing, anim).get("state", GOOD))


static func note_of(model_id: String, facing: String, anim: String) -> String:
	return str(row(model_id, facing, anim).get("note", ""))


static func label_of(model_id: String, facing: String, anim: String) -> String:
	var st := state_of(model_id, facing, anim)
	if st == REPACK:
		return "Repack"
	if st == REGEN:
		return "Regenerate"
	return "Good"


static func set_state(model_id: String, facing: String, anim: String, st: String, frame_n: int) -> String:
	if not can_review(frame_n):
		return GOOD
	if st != GOOD and st != REPACK and st != REGEN:
		st = GOOD
	ensure_loaded()
	var k := clip_key(model_id, facing, anim)
	var note := note_of(model_id, facing, anim)
	mem[k] = {"state": st, "note": note}
	save_disk()
	return st


static func set_note(model_id: String, facing: String, anim: String, note: String, frame_n: int) -> void:
	if not can_review(frame_n):
		return
	ensure_loaded()
	var k := clip_key(model_id, facing, anim)
	var st := state_of(model_id, facing, anim)
	mem[k] = {"state": st, "note": note}
	save_disk()


static func cycle(model_id: String, facing: String, anim: String, frame_n: int) -> String:
	if not can_review(frame_n):
		return GOOD
	var cur := state_of(model_id, facing, anim)
	var i := ORDER.find(cur)
	if i < 0:
		i = 0
	var nxt: String = ORDER[(i + 1) % ORDER.size()]
	return set_state(model_id, facing, anim, nxt, frame_n)


static func save_disk() -> bool:
	if not can_write():
		return false
	ensure_loaded()
	var clips := {}
	for k in mem.keys():
		var r: Variant = mem[k]
		if not (r is Dictionary):
			continue
		var st := str((r as Dictionary).get("state", GOOD))
		if st != REPACK and st != REGEN:
			continue
		clips[str(k)] = {
			"state": st,
			"note": str((r as Dictionary).get("note", "")),
		}
	var abs_dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"v": 1, "clips": clips}, "\t"))
	return true
