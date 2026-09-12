extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const Digest := preload("res://scripts/debug/playtest_log_batch_digest.gd")
const Flags := preload("res://scripts/debug/playtest_log_batch_flags.gd")
const Prune := preload("res://scripts/debug/playtest_log_batch_prune.gd")


static var active: bool = false
static var stamp: String = ""
static var runs: Array = []

static func begin() -> void:
	active = true
	runs = []
	var now: Dictionary = Time.get_datetime_dict_from_system()
	stamp = "batch_%04d%02d%02d_%02d%02d%02d" % [
		int(now.year), int(now.month), int(now.day),
		int(now.hour), int(now.minute), int(now.second),
	]

static func note_run() -> void:
	if not active:
		begin()
	var events: Array = PlaytestLog.events
	var file_name: String = PlaytestLog.file_name
	var header: Dictionary = {}
	if events.size() > 0 and events[0] is Dictionary and str(events[0].get("ev", "")) == "begin":
		header = events[0]
	var tel: Dictionary = PlaytestLogUtil._tel_slim()
	var body: Dictionary = {
		"kind": "wdb_playtest_journal",
		"ver": 2,
		"file": file_name,
		"cards": "EWNS",
		"header": header,
		"events": events.duplicate(true),
		"godot": PlaytestLogUtil._godot(),
		"written": Time.get_datetime_string_from_system(false, true),
		"end_cond": PlaytestLog.end_cond,
		"fail": PlaytestLog.end_fail,
	}
	if not tel.is_empty():
		body["tel"] = tel
	runs.append(body)

static func close() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if runs.is_empty():
		active = false
		stamp = ""
		Prune._prune()
		return out
	if stamp == "":
		var now: Dictionary = Time.get_datetime_dict_from_system()
		stamp = "batch_%04d%02d%02d_%02d%02d%02d" % [
			int(now.year), int(now.month), int(now.day),
			int(now.hour), int(now.minute), int(now.second),
		]
	var dir: String = PlaytestLogUtil._dir()
	var json_path: String = dir.path_join(stamp + ".json")
	var txt_path: String = dir.path_join(stamp + ".txt")
	var files: Array = []
	for row: Variant in runs:
		if row is Dictionary:
			files.append(str((row as Dictionary).get("file", "")))
	var bundle: Dictionary = {
		"kind": "wdb_playtest_batch",
		"ver": 1,
		"written": Time.get_datetime_string_from_system(false, true),
		"n": runs.size(),
		"files": files,
		"runs": runs,
	}
	var jf: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if jf:
		jf.store_string(JSON.stringify(bundle))
		jf.close()
		out.append(json_path)
	var tf: FileAccess = FileAccess.open(txt_path, FileAccess.WRITE)
	if tf:
		tf.store_string(Digest._digest())
		tf.close()
		out.append(txt_path)
	active = false
	runs = []
	stamp = ""
	Prune._prune()
	return out

static func _rm(path: String) -> void:
	Prune._rm(path)

static func _drop_batch(dir_path: String, json_name: String) -> void:
	Prune._drop_batch(dir_path, json_name)

static func _prune() -> void:
	Prune._prune()

static func _digest() -> String:
	return Digest._digest()

static func _goal_counts(events: Array) -> Dictionary:
	return Flags._goal_counts(events)

static func _goal_flow(events: Array) -> String:
	return Flags._goal_flow(events)

static func _flags(events: Array) -> PackedStringArray:
	return Flags._flags(events)
