extends Object

## Local / localhost hitch JSONL. Append on miss. Tail 256.

const BUDGET_SEC := 1.0 / 60.0
const MULT := 4.0
const CAP := 256
const KIND := "wdb_hitch_log"
const REL_DIR := "hitch"
const REL_FILE := "hitch.jsonl"

static var started: bool = false
static var hitch_n: int = 0
static var worst_ms: float = 0.0
static var file_path: String = ""
static var ver: String = ""
static var _on: int = -1
static var _fh: FileAccess = null
static var _t0_ms: int = 0
static var why: String = ""
static var gx: int = 0
static var gy: int = 0
static var _whys: PackedStringArray = PackedStringArray()
static var _mark_ms: int = 0
static var _mark_frame: int = -1


static func enabled() -> bool:
	if _on >= 0:
		return _on == 1
	if OS.has_feature("web"):
		_on = 1 if _localhost() else 0
	else:
		_on = 1
	return _on == 1


static func begin(_host: Node = null) -> void:
	if started or not enabled():
		return
	ver = _ver_label()
	_t0_ms = Time.get_ticks_msec()
	var dir_path: String = OS.get_user_data_dir().path_join(REL_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	file_path = dir_path.path_join(REL_FILE)
	_trim_file()
	_fh = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if _fh == null:
		_fh = FileAccess.open(file_path, FileAccess.WRITE_READ)
	if _fh == null:
		return
	_fh.seek_end()
	started = true
	hitch_n = _count_hitches()
	_write_row(_session_row())


static func tick(host: Node, delta: float) -> void:
	if not enabled():
		return
	if not started:
		begin(host)
	if not started:
		return
	if Engine.time_scale != 1.0:
		return
	if host.get_tree() != null and host.get_tree().paused:
		return
	if delta < BUDGET_SEC * MULT:
		return
	_note(host, delta)


static func copy_text() -> String:
	var txt: String = _read_all()
	if txt != "":
		DisplayServer.clipboard_set(txt)
	return txt


static func clear_log() -> void:
	_close()
	if file_path != "" and FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	started = false
	hitch_n = 0
	worst_ms = 0.0
	if enabled():
		begin()


static func close() -> void:
	_close()


static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	var now: int = Time.get_ticks_msec()
	var frame: int = int(Engine.get_process_frames())
	var dt: int = 0
	if frame != _mark_frame:
		_whys.clear()
		_mark_frame = frame
	elif _mark_ms > 0:
		dt = now - _mark_ms
	_mark_ms = now
	why = reason
	gx = int(origin.x)
	gy = int(origin.y)
	if _whys.size() >= 12:
		_whys.remove_at(0)
	_whys.append("%s:%d" % [reason, dt])


static func status_line() -> String:
	if not enabled():
		return "Hitch log off"
	var worst: String = "0"
	if worst_ms > 0.0:
		worst = str(snappedf(worst_ms, 0.1))
	return "Hitch %d/%d  worst %s ms  %s" % [hitch_n, CAP, worst, file_path]


static func _note(host: Node, delta: float) -> void:
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	if dt_ms > worst_ms:
		worst_ms = dt_ms
	hitch_n += 1
	_write_row(_hitch_row(host, dt_ms))
	why = ""
	gx = 0
	gy = 0
	_whys.clear()
	_mark_ms = 0
	if hitch_n > CAP:
		_close()
		_trim_file()
		_fh = FileAccess.open(file_path, FileAccess.READ_WRITE)
		if _fh == null:
			_fh = FileAccess.open(file_path, FileAccess.WRITE_READ)
		if _fh != null:
			_fh.seek_end()
		hitch_n = _count_hitches()


static func _session_row() -> Dictionary:
	var row: Dictionary = {
		"ev": "session",
		"kind": KIND,
		"ver": ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"os": OS.get_name(),
		"web": 1 if OS.has_feature("web") else 0,
		"godot": str(Engine.get_version_info().get("string", "")),
	}
	return row


static func _hitch_row(host: Node, dt_ms: float) -> Dictionary:
	var t_sec: float = 0.0
	if _t0_ms > 0:
		t_sec = snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1)
	var row: Dictionary = {
		"ev": "hitch",
		"ver": ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"t": t_sec,
		"dt_ms": dt_ms,
		"where": _where(host),
		"fl": int(App.floor_n) if App else 0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"proc_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
	}
	if not _whys.is_empty():
		row["why"] = ",".join(_whys)
	elif why != "":
		row["why"] = why
	if why == "geo_activate" or (not _whys.is_empty() and _whys[_whys.size() - 1].begins_with("geo_activate")):
		row["gx"] = gx
		row["gy"] = gy
	return row


static func _where(host: Node) -> String:
	if App != null and App.in_dungeon:
		return "dungeon"
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return "boot"
	var scn: String = tree.current_scene.name.to_lower()
	if scn.find("title") >= 0 or scn.find("splash") >= 0:
		return "title"
	if scn.find("camp") >= 0 or scn.find("hub") >= 0:
		return "hub"
	return scn


static func _write_row(row: Dictionary) -> void:
	if _fh == null:
		return
	_fh.store_line(JSON.stringify(row))
	_fh.flush()


static func _trim_file() -> void:
	if file_path == "" or not FileAccess.file_exists(file_path):
		return
	var raw: String = FileAccess.get_file_as_string(file_path)
	if raw == "":
		return
	var kept: Array[String] = []
	var found: int = 0
	var parts: PackedStringArray = raw.split("\n")
	var i: int = parts.size()
	while i > 0:
		i -= 1
		var line: String = parts[i].strip_edges()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		var is_hitch: bool = parsed is Dictionary and str((parsed as Dictionary).get("ev", "")) == "hitch"
		if is_hitch:
			if found >= CAP:
				continue
			found += 1
		kept.push_front(line)
	var out: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if out == null:
		return
	for line: String in kept:
		out.store_line(line)
	out.close()


static func _count_hitches() -> int:
	var raw: String = _read_all()
	if raw == "":
		return 0
	var n: int = 0
	for line: String in raw.split("\n"):
		if line.find("\"ev\":\"hitch\"") >= 0:
			n += 1
	return n


static func _read_all() -> String:
	if file_path != "" and FileAccess.file_exists(file_path):
		return FileAccess.get_file_as_string(file_path)
	return ""


static func _ver_label() -> String:
	var txt: String = FileAccess.get_file_as_string("res://scripts/data/version.json")
	if txt == "":
		return ""
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("label", ""))
	return ""


static func _localhost() -> bool:
	if not OS.has_feature("web"):
		return false
	var host: Variant = JavaScriptBridge.eval("window.location.hostname", true)
	var h: String = str(host)
	return h == "localhost" or h == "127.0.0.1" or h == "[::1]"


static func _close() -> void:
	if _fh != null:
		_fh.flush()
		_fh.close()
		_fh = null
