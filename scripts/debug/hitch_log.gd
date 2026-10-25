extends Object

## Local / localhost hitch JSONL. Append on miss. Tail 256. Localhost web also POSTs rows to `perf.py hitch`.

const CAP := 256
const REL_DIR := "hitch"
const REL_FILE := "hitch.jsonl"
const CliArgs := preload("res://scripts/app/cli_args.gd")
const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")
const Run := preload("res://scripts/debug/hitch_log/log_run.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Rows := preload("res://scripts/debug/hitch_log/rows.gd")
const LogFile := preload("res://scripts/debug/hitch_log/log_file.gd")
static var hitch_n: int = 0
static var worst_ms: float = 0.0
static var file_path: String = ""
static var _on: int = -1
static var _skip_gap: bool = false
static var frame_n: int = 0
static var slow_n: int = 0
static var pause_slow_n: int = 0
static var bar_slow_n: int = 0
## Last time a full stall row was built. Building one on every miss held the next present.
static var _emit_at: int = -100000

static func enabled() -> bool:
	if _on >= 0:
		return _on == 1
	if OS.has_feature("web"):
		_on = 1 if Ctx._localhost() else 0
	else:
		_on = 1
	return _on == 1

static func set_mult(value: float) -> void:
	Present._mult = maxf(0.05, value)

static func mult() -> float:
	return Present.mult()

## Drop the next tick from the FPS count. The bench uses this so the frame that
## opens a menu is recorded as ev=gap, not as a counted hitch.
static func skip_gap() -> void:
	_skip_gap = true

static func set_phase(phase_name: String) -> void:
	Rows.set_phase(phase_name)

static func set_play_s(sec: float) -> void:
	Rows.set_play_s(sec)

## One HB line in the hitch file. The web console never reaches the runner.
static func hb(msg: String) -> void:
	if not enabled():
		return
	if not Rows.started:
		begin()
	if not Rows.started:
		return
	var t_sec: float = 0.0
	if Rows._t0_ms > 0:
		t_sec = snappedf(float(Time.get_ticks_msec() - Rows._t0_ms) / 1000.0, 0.1)
	var row: Dictionary = {"ev": "hb", "msg": msg, "t": t_sec}
	Rows._write_row(row)

## Write one hitch row when sec is over the threshold. Keeps why tags already on this frame.
static func note_span(host: Node, reason: String, sec: float) -> void:
	if not enabled():
		return
	if not Rows.started:
		begin(host)
	if not Rows.started:
		return
	if not Present._over_budget(sec):
		return
	if Rows._whys.size() >= 16:
		Rows._whys.remove_at(0)
	Rows._whys.append("%s:0" % reason)
	Rows.why = reason
	_note(host, sec)

## Bench start: apply the multiplier and replace the hitch file so the run is one session.
static func bench_reset(mult_value: float) -> void:
	set_mult(mult_value)
	close()
	var path: String = OS.get_user_data_dir().path_join(REL_DIR).path_join(REL_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	Rows.started = false
	hitch_n = 0
	worst_ms = 0.0
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys = PackedStringArray()
	Rows._mark_ms = 0
	Rows._mark_frame = -1
	_skip_gap = false
	Rows._keep_all = true
	frame_n = 0
	slow_n = 0
	pause_slow_n = 0
	bar_slow_n = 0
	Present._dts = PackedFloat32Array()
	Rows._phase = ""
	Rows._play_s = 0.0
	Rows._last_proc = -1.0
	Rows._proc_held = 0
	Run._run_n = 0
	Run._run_best = 0
	Run._run_vals = PackedFloat32Array()
	Run._run_best_vals = PackedFloat32Array()
	Web._web_q = PackedStringArray()
	Present._present_at = -100000
	Present._present_row = {}
	Ctx._counted = false
	Ctx._mesh_n = 0
	Ctx._light_n = 0
	_emit_at = -100000
	Rows._bench_gen += 1
	file_path = ""
	Rows._t0_ms = 0
	begin()

static func begin(_host: Node = null) -> void:
	if Rows.started or not enabled():
		return
	if Present._mult <= 0.0:
		var cli_mult: float = CliArgs.float_arg("--wdb-hitch-mult", 0.0)
		if cli_mult > 0.0:
			set_mult(cli_mult)
	Rows.ver = Ctx._ver_label()
	Rows._t0_ms = Time.get_ticks_msec()
	var dir_path: String = OS.get_user_data_dir().path_join(REL_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	file_path = dir_path.path_join(REL_FILE)
	LogFile._trim_file()
	Rows._fh = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if Rows._fh == null:
		Rows._fh = FileAccess.open(file_path, FileAccess.WRITE_READ)
	if Rows._fh == null:
		return
	Rows._fh.seek_end()
	Rows.started = true
	hitch_n = LogFile._count_hitches()
	Rows._write_row(Rows._session_row())

static func tick(host: Node, delta: float) -> void:
	if not enabled():
		return
	if not Rows.started:
		begin(host)
	if not Rows.started:
		return
	if Engine.time_scale != 1.0:
		return
	Rows._sample_proc()
	if _skip_gap:
		_skip_gap = false
		Run._break_run()
		Rows._write_gap(delta, "skip_gap")
		return
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.paused:
		Run._break_run()
		if Present._over_budget(delta):
			pause_slow_n += 1
			_note_paused(host, delta)
		return
	# The 99% bar is the whole time the player can see the hub. Frames while the
	# loading bar is up, and frames before camp is showing, are not that time.
	if not Ctx._hub_on_screen(host):
		Run._break_run()
		if Present._over_budget(delta):
			bar_slow_n += 1
			Rows._note_bar(host, delta)
		return
	frame_n += 1
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	if Rows._keep_all:
		Present._dts.append(dt_ms)
	var slow: bool = Present._over_budget(delta)
	Run._track_run(dt_ms, slow)
	if not slow:
		return
	slow_n += 1
	_note(host, delta)

static func copy_text() -> String:
	var txt: String = LogFile._read_all()
	if txt != "":
		DisplayServer.clipboard_set(txt)
	return txt

static func clear_log() -> void:
	Rows._close()
	if file_path != "" and FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	Rows.started = false
	hitch_n = 0
	worst_ms = 0.0
	frame_n = 0
	slow_n = 0
	Present._dts = PackedFloat32Array()
	if enabled():
		begin()

static func close() -> void:
	Rows._close()

## Read-back of the window the frame was actually presented on. Web is always paced:
## DisplayServerWeb ignores window_set_vsync_mode and the loop is requestAnimationFrame.
static func present() -> Dictionary:
	return Present.present()

static func present_text() -> String:
	return Present.present_text()

## Share of counted frames faster than the 60 FPS budget. Paused frames are not counted.
static func fps_pct() -> float:
	if frame_n <= 0:
		return 100.0
	return snappedf(100.0 * float(frame_n - slow_n) / float(frame_n), 0.1)

## One session row the hub bench runner reads (desktop file and the localhost hitch sink).
static func bench_done(sec: float, ok: bool, missing: String) -> void:
	if not enabled():
		return
	if not Rows.started:
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
		"pause_slow": pause_slow_n,
		"bar_slow": bar_slow_n,
	}
	var shape: Dictionary = Present._slow_shape()
	row["n_edge"] = int(shape["n_edge"])
	row["n_stutter"] = int(shape["n_stutter"])
	row["n_spike"] = int(shape["n_spike"])
	row["slow_run_n"] = int(shape["slow_run_n"])
	row["slow_run_med_ms"] = float(shape["slow_run_med_ms"])
	if Present._dts.size() > 0:
		Present._dts.sort()
	row["dt_p50_ms"] = Present._percentile(0.50)
	row["dt_p95_ms"] = Present._percentile(0.95)
	Present._stamp_present(row)
	row["bench_gen"] = Rows._bench_gen
	if Rows.started and Rows._fh != null:
		Rows._write_row(row)
	else:
		Web._post(JSON.stringify(row))
	Web._flush_web()

static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	Rows.mark(reason, origin)

static func status_line() -> String:
	if not enabled():
		return "Hitch log off"
	var worst: String = "0"
	if worst_ms > 0.0:
		worst = str(snappedf(worst_ms, 0.1))
	return "Hitch %d/%d  worst %s ms  x%.2f  %s" % [hitch_n, CAP, worst, mult(), file_path]

static func _note(host: Node, delta: float) -> void:
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var fresh: bool = dt_ms > worst_ms
	if fresh:
		worst_ms = dt_ms
	hitch_n += 1
	# The counters above are the 99% bar. Building the row on every miss costs
	# another present on web, so a single stall becomes the rest of the walk.
	var now: int = Time.get_ticks_msec()
	if not fresh and now - _emit_at < 100:
		return
	_emit_at = now
	Rows._write_row(Rows._hitch_row(host, dt_ms))
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys.clear()
	Rows._mark_ms = 0
	if hitch_n > CAP and not Rows._keep_all:
		Rows._close()
		LogFile._trim_file()
		Rows._fh = FileAccess.open(file_path, FileAccess.READ_WRITE)
		if Rows._fh == null:
			Rows._fh = FileAccess.open(file_path, FileAccess.WRITE_READ)
		if Rows._fh != null:
			Rows._fh.seek_end()
		hitch_n = LogFile._count_hitches()

static func _note_paused(host: Node, delta: float) -> void:
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var row: Dictionary = Rows._hitch_row(host, dt_ms)
	row["paused"] = 1
	hitch_n += 1
	Rows._write_row(row)
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys.clear()
	Rows._mark_ms = 0

static func flush_web() -> void:
	Web._flush_web()
