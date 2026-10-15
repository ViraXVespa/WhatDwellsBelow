extends Object

## Local / localhost hitch JSONL. Append on miss. Tail 256. Localhost web also POSTs rows to tools/hitch_sink.py.

const BUDGET_SEC := 1.0 / 60.0
const MULT := 4.0
const CAP := 256
const KIND := "wdb_hitch_log"
const REL_DIR := "hitch"
const REL_FILE := "hitch.jsonl"
const CliArgs := preload("res://scripts/debug/cli_args.gd")

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
static var _mult: float = 0.0
static var _skip_gap: bool = false
static var _keep_all: bool = false
static var frame_n: int = 0
static var slow_n: int = 0

static func enabled() -> bool:
	if _on >= 0:
		return _on == 1
	if OS.has_feature("web"):
		_on = 1 if _localhost() else 0
	else:
		_on = 1
	return _on == 1

static func set_mult(mult: float) -> void:
	_mult = maxf(0.05, mult)

static func mult() -> float:
	return _mult if _mult > 0.0 else MULT

## Drop the next tick. The bench uses this so a paused menu's hold is not logged as a hitch.
static func skip_gap() -> void:
	_skip_gap = true

## Write one hitch row when sec is over the threshold. Keeps why tags already on this frame.
static func note_span(host: Node, reason: String, sec: float) -> void:
	if not enabled():
		return
	if not started:
		begin(host)
	if not started:
		return
	if sec < BUDGET_SEC * mult():
		return
	if _whys.size() >= 16:
		_whys.remove_at(0)
	_whys.append("%s:0" % reason)
	why = reason
	_note(host, sec)

## Bench start: apply the multiplier and replace the hitch file so the run is one session.
static func bench_reset(mult_value: float) -> void:
	set_mult(mult_value)
	close()
	var path: String = OS.get_user_data_dir().path_join(REL_DIR).path_join(REL_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	started = false
	hitch_n = 0
	worst_ms = 0.0
	why = ""
	gx = 0
	gy = 0
	_whys = PackedStringArray()
	_mark_ms = 0
	_mark_frame = -1
	_skip_gap = false
	_keep_all = true
	frame_n = 0
	slow_n = 0
	file_path = ""
	_t0_ms = 0
	begin()

static func begin(_host: Node = null) -> void:
	if started or not enabled():
		return
	if _mult <= 0.0:
		var cli_mult: float = CliArgs.float_arg("--wdb-hitch-mult", 0.0)
		if cli_mult > 0.0:
			set_mult(cli_mult)
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
	if _skip_gap:
		_skip_gap = false
		return
	if Engine.time_scale != 1.0:
		return
	if host.get_tree() != null and host.get_tree().paused:
		return
	frame_n += 1
	if delta < BUDGET_SEC * mult():
		return
	slow_n += 1
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
	frame_n = 0
	slow_n = 0
	if enabled():
		begin()

static func close() -> void:
	_close()

## Share of counted frames faster than the 60 FPS budget. Paused frames are not counted.
static func fps_pct() -> float:
	if frame_n <= 0:
		return 100.0
	return snappedf(100.0 * float(frame_n - slow_n) / float(frame_n), 0.1)

## One session row the hub bench runner reads (desktop file and the localhost hitch sink).
static func bench_done(sec: float, ok: bool, missing: String) -> void:
	if not enabled():
		return
	if not started:
		begin()
	var row: Dictionary = {
		"ev": "bench",
		"sec": snappedf(sec, 0.1),
		"ok": 1 if ok else 0,
		"missing": missing,
		"hitches": hitch_n,
		"frames": frame_n,
		"slow": slow_n,
		"fps_pct": fps_pct(),
		"worst_ms": snappedf(worst_ms, 0.1),
		"web": 1 if OS.has_feature("web") else 0,
	}
	if started and _fh != null:
		_write_row(row)
	else:
		_post(JSON.stringify(row))

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
	if _whys.size() >= 16:
		_whys.remove_at(0)
	_whys.append("%s:%d" % [reason, dt])

static func status_line() -> String:
	if not enabled():
		return "Hitch log off"
	var worst: String = "0"
	if worst_ms > 0.0:
		worst = str(snappedf(worst_ms, 0.1))
	return "Hitch %d/%d  worst %s ms  x%.2f  %s" % [hitch_n, CAP, worst, mult(), file_path]

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
	if hitch_n > CAP and not _keep_all:
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
		"mult": mult(),
		"thr_ms": snappedf(BUDGET_SEC * mult() * 1000.0, 0.1),
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
		"mult": mult(),
		"thr_ms": snappedf(BUDGET_SEC * mult() * 1000.0, 0.1),
	}
	if not _whys.is_empty():
		row["why"] = ",".join(_whys)
	elif why != "":
		row["why"] = why
	if why == "geo_activate" or (not _whys.is_empty() and _whys[_whys.size() - 1].begins_with("geo_activate")):
		row["gx"] = gx
		row["gy"] = gy
	if str(row.get("where", "")) == "hub":
		_hub_ctx(host, row)
	return row

static func _hub_ctx(host: Node, row: Dictionary) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var actor: Node = tree.get_first_node_in_group("player")
	if actor is Node3D:
		var at: Vector3 = (actor as Node3D).global_position
		row["px"] = snappedf(at.x, 0.1)
		row["pz"] = snappedf(at.z, 0.1)
		row["cell"] = "%d,%d" % [int(at.x), int(at.z)]
		var loco_i: int = int(actor.get("loc_state"))
		var loco_name: String = "idle"
		if loco_i == 1:
			loco_name = "start"
		elif loco_i == 2:
			loco_name = "loop"
		elif loco_i == 3:
			loco_name = "stop"
		var face: String = str(actor.get("facing_key"))
		row["face"] = face
		row["anim"] = loco_name + "_" + face
	var scn: Node = tree.current_scene
	if scn == null:
		return
	var panels: PackedStringArray = PackedStringArray()
	var ui_v: Variant = scn.get("ui")
	if ui_v is Node and bool((ui_v as Node).get("open")):
		panels.append(str((ui_v as Node).get("mode")))
	if App != null and App.pause_menu != null and bool(App.pause_menu.get("open")):
		panels.append("pause")
	if panels.is_empty() and App != null and App.ui_open:
		panels.append("ui")
	if not panels.is_empty():
		row["ui"] = ",".join(panels)
	var gen: Node = scn.get_node_or_null("Generated")
	row["gen"] = gen.get_child_count() if gen != null else 0
	row["meshes"] = gen.find_children("*", "MeshInstance3D", true, false).size() if gen != null else 0
	row["lights"] = scn.find_children("*", "Light3D", true, false).size()

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
	var line: String = JSON.stringify(row)
	_fh.store_line(line)
	_fh.flush()
	_post(line)

## Localhost web only (enabled() gates it): fire-and-forget POST to tools/hitch_sink.py; never awaited, errors dropped.
static func _post(line: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("fetch('/_wdb/hitch',{method:'POST',keepalive:true,headers:{'Content-Type':'application/json'},body:%s}).catch(function(){})" % JSON.stringify(line), false)

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
		if line == "" or not line.begins_with("{"):
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed == null:
			continue
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
