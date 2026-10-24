extends Object

## Split from hitch_log.gd: _hitch_row, _session_row, _sample_proc....

const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")

static var _phase: String = ""
static var _play_s: float = 0.0
static var _proc_held: int = 0
static var _t0_ms: int = 0
static var _whys: PackedStringArray = PackedStringArray()
static var gx: int = 0
static var gy: int = 0
static var ver: String = ""
static var why: String = ""
const KIND := "wdb_hitch_log"
static var _last_proc: float = -1.0
static var _bench_gen: int = 0
static var _fh: FileAccess = null
static var _mark_ms: int = 0
static var _keep_all: bool = false
static var _mark_frame: int = -1
static var started: bool = false

## Seconds since the log started (0.1 s steps), 0 before it starts.
static func _t_sec() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1) if _t0_ms > 0 else 0.0

static func _hitch_row(host: Node, dt_ms: float) -> Dictionary:
	var row: Dictionary = {
		"ev": "hitch",
		"ver": ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"t": _t_sec(),
		"dt_ms": dt_ms,
		"where": Ctx._where(host),
		"fl": int(App.floor_n) if App else 0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"proc_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
		"phys_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
		"proc_held": _proc_held,
		"refresh_n": Present._refresh_n(dt_ms),
		"play_s": snappedf(_play_s, 0.1),
		"frame": int(Engine.get_process_frames()),
		"mult": Present.mult(),
		"thr_ms": snappedf(Present.BUDGET_SEC * Present.mult() * 1000.0, 0.1),
	}
	if _phase != "":
		row["phase"] = _phase
	if not _whys.is_empty():
		row["why"] = ",".join(_whys)
	elif why != "":
		row["why"] = why
	if why == "geo_activate" or (not _whys.is_empty() and _whys[_whys.size() - 1].begins_with("geo_activate")):
		row["gx"] = gx
		row["gy"] = gy
	if str(row.get("where", "")) == "hub":
		Ctx._hub_ctx(host, row)
	return row

static func _session_row() -> Dictionary:
	var row: Dictionary = {
		"ev": "session",
		"kind": KIND,
		"ver": ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"os": OS.get_name(),
		"web": 1 if OS.has_feature("web") else 0,
		"godot": str(Engine.get_version_info().get("string", "")),
		"mult": Present.mult(),
		"thr_ms": snappedf(Present.BUDGET_SEC * Present.mult() * 1000.0, 0.1),
	}
	Present._stamp_present(row)
	return row

static func _sample_proc() -> void:
	var proc: float = snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1)
	if _last_proc >= 0.0 and is_equal_approx(proc, _last_proc):
		_proc_held = 1
	else:
		_proc_held = 0
	_last_proc = proc

static func _write_mark(reason: String, gap_ms: int) -> void:
	var row: Dictionary = {
		"ev": "mark",
		"why": reason,
		"dt_ms": gap_ms,
		"t": _t_sec(),
		"play_s": snappedf(_play_s, 0.1),
	}
	if _phase != "":
		row["phase"] = _phase
	_write_row(row)

static func _write_gap(delta: float, reason: String) -> void:
	var row: Dictionary = {
		"ev": "gap",
		"why": reason,
		"dt_ms": snappedf(delta * 1000.0, 0.1),
		"t": _t_sec(),
		"play_s": snappedf(_play_s, 0.1),
	}
	if _phase != "":
		row["phase"] = _phase
	_write_row(row)

static func set_phase(phase_name: String) -> void:
	_phase = phase_name

static func set_play_s(sec: float) -> void:
	_play_s = sec

static func _write_row(row: Dictionary) -> void:
	row["bench_gen"] = _bench_gen
	var line: String = JSON.stringify(row)
	# Post before the file write. A web user:// write on the stall frame held
	# the next present. The sink is what the web runner reads.
	Web._post(line)
	if OS.has_feature("web") or _fh == null:
		return
	_fh.store_line(line)
	_fh.flush()

static func _note_bar(host: Node, delta: float) -> void:
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var row: Dictionary = _hitch_row(host, dt_ms)
	row["bar"] = 1
	_write_row(row)
	why = ""
	gx = 0
	gy = 0
	_whys.clear()
	_mark_ms = 0

static func _close() -> void:
	if _fh != null:
		_fh.flush()
		_fh.close()
		_fh = null

static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	var now: int = Time.get_ticks_msec()
	var frame: int = int(Engine.get_process_frames())
	var gap: int = 0
	if _mark_ms > 0:
		gap = now - _mark_ms
	var dt: int = 0
	if frame != _mark_frame:
		_whys.clear()
		_mark_frame = frame
	elif _mark_ms > 0:
		dt = gap
	_mark_ms = now
	why = reason
	gx = int(origin.x)
	gy = int(origin.y)
	if _whys.size() >= 16:
		_whys.remove_at(0)
	_whys.append("%s:%d" % [reason, dt])
	# A bench frame can run for a long time before the next tick. Post the mark
	# now so a hung load still names the last step.
	if _keep_all and started:
		_write_mark(reason, gap)
