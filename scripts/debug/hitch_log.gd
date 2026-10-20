extends Object

## Local / localhost hitch JSONL. Append on miss. Tail 256. Localhost web also POSTs rows to tools/hitch_sink.py.

const BUDGET_SEC := 1.0 / 60.0
const MULT := 4.0
const CAP := 256
const KIND := "wdb_hitch_log"
const REL_DIR := "hitch"
const REL_FILE := "hitch.jsonl"
const CliArgs := preload("res://scripts/debug/cli_args.gd")
## Refresh-paced frames cluster a few ms over one refresh. That cluster is the present, not a stall.
const PRESENT_SLACK_SEC := 0.003
## Float slack so a frame at exactly 1/60 is not a hitch when vsync is actually off.
const BUDGET_EPS_SEC := 0.0005

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
static var pause_slow_n: int = 0
static var bar_slow_n: int = 0
static var _dts: PackedFloat32Array = PackedFloat32Array()
static var _phase: String = ""
static var _play_s: float = 0.0
static var _bench_gen: int = 0
static var _last_proc: float = -1.0
static var _proc_held: int = 0
static var _run_n: int = 0
static var _run_best: int = 0
static var _run_vals: PackedFloat32Array = PackedFloat32Array()
static var _run_best_vals: PackedFloat32Array = PackedFloat32Array()
## Web only. A JavaScript eval on every slow frame keeps the present over one refresh.
static var _web_q: PackedStringArray = PackedStringArray()
## Display server read-back. Queried at most twice a second; every frame was a web stall.
static var _present_at: int = -100000
static var _present_row: Dictionary = {}
## Mesh and light totals. One walk per bench. A walk on every stall held web at two refreshes.
static var _counted: bool = false
static var _mesh_n: int = 0
static var _light_n: int = 0
## Last time a full stall row was built. Building one on every miss held the next present.
static var _emit_at: int = -100000

static func enabled() -> bool:
	if _on >= 0:
		return _on == 1
	if OS.has_feature("web"):
		_on = 1 if _localhost() else 0
	else:
		_on = 1
	return _on == 1

static func set_mult(value: float) -> void:
	_mult = maxf(0.05, value)

static func mult() -> float:
	return _mult if _mult > 0.0 else MULT

## Drop the next tick from the FPS count. The bench uses this so the frame that
## opens a menu is recorded as ev=gap, not as a counted hitch.
static func skip_gap() -> void:
	_skip_gap = true

static func set_phase(phase_name: String) -> void:
	_phase = phase_name

static func set_play_s(sec: float) -> void:
	_play_s = sec

## One HB line in the hitch file. The web console never reaches the runner.
static func hb(msg: String) -> void:
	if not enabled():
		return
	if not started:
		begin()
	if not started:
		return
	var t_sec: float = 0.0
	if _t0_ms > 0:
		t_sec = snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1)
	var row: Dictionary = {"ev": "hb", "msg": msg, "t": t_sec}
	_write_row(row)

## Write one hitch row when sec is over the threshold. Keeps why tags already on this frame.
static func note_span(host: Node, reason: String, sec: float) -> void:
	if not enabled():
		return
	if not started:
		begin(host)
	if not started:
		return
	if not _over_budget(sec):
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
	pause_slow_n = 0
	bar_slow_n = 0
	_dts = PackedFloat32Array()
	_phase = ""
	_play_s = 0.0
	_last_proc = -1.0
	_proc_held = 0
	_run_n = 0
	_run_best = 0
	_run_vals = PackedFloat32Array()
	_run_best_vals = PackedFloat32Array()
	_web_q = PackedStringArray()
	_present_at = -100000
	_present_row = {}
	_counted = false
	_mesh_n = 0
	_light_n = 0
	_emit_at = -100000
	_bench_gen += 1
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
	if Engine.time_scale != 1.0:
		return
	_sample_proc()
	if _skip_gap:
		_skip_gap = false
		_break_run()
		_write_gap(delta, "skip_gap")
		return
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.paused:
		_break_run()
		if _over_budget(delta):
			pause_slow_n += 1
			_note_paused(host, delta)
		return
	# The 99% bar is the whole time the player can see the hub. Frames while the
	# loading bar is up, and frames before camp is showing, are not that time.
	if not _hub_on_screen(host):
		_break_run()
		if _over_budget(delta):
			bar_slow_n += 1
			_note_bar(host, delta)
		return
	frame_n += 1
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	if _keep_all:
		_dts.append(dt_ms)
	var slow: bool = _over_budget(delta)
	_track_run(dt_ms, slow)
	if not slow:
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
	_dts = PackedFloat32Array()
	if enabled():
		begin()

static func close() -> void:
	_close()

## Read-back of the window the frame was actually presented on. Web is always paced:
## DisplayServerWeb ignores window_set_vsync_mode and the loop is requestAnimationFrame.
static func present() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if not _present_row.is_empty() and now - _present_at < 500:
		return _present_row
	var mode: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	var hz: float = DisplayServer.screen_get_refresh_rate()
	if hz <= 1.0:
		hz = 60.0
	var paced: int = 0
	if OS.has_feature("web") or mode != DisplayServer.VSYNC_DISABLED:
		paced = 1
	var scr_i: int = DisplayServer.window_get_current_screen()
	var screen: Vector2i = DisplayServer.screen_get_size(scr_i)
	var win: Vector2i = DisplayServer.window_get_size()
	_present_at = now
	_present_row = {
		"vsync": int(mode),
		"max_fps": Engine.max_fps,
		"refresh_hz": snappedf(hz, 0.1),
		"paced": paced,
		"renderer": RenderingServer.get_current_rendering_method(),
		"win_w": win.x,
		"win_h": win.y,
		"screen_w": screen.x,
		"screen_h": screen.y,
	}
	return _present_row

static func present_text() -> String:
	var info: Dictionary = present()
	return "vsync=%d max_fps=%d refresh=%.1f paced=%d" % [int(info["vsync"]), int(info["max_fps"]), float(info["refresh_hz"]), int(info["paced"])]

static func _stamp_present(row: Dictionary) -> void:
	var info: Dictionary = present()
	row["vsync"] = int(info["vsync"])
	row["max_fps"] = int(info["max_fps"])
	row["refresh_hz"] = float(info["refresh_hz"])
	row["paced"] = int(info["paced"])
	row["renderer"] = str(info["renderer"])
	row["win_w"] = int(info["win_w"])
	row["win_h"] = int(info["win_h"])
	row["screen_w"] = int(info["screen_w"])
	row["screen_h"] = int(info["screen_h"])

## True when this delta is a stall. A refresh-paced present within 3 ms of one
## refresh is not a stall. An uncapped desktop frame is a stall over the 60 FPS budget.
static func _over_budget(delta: float) -> bool:
	var budget: float = BUDGET_SEC * mult()
	var info: Dictionary = present()
	if int(info["paced"]) == 1:
		var refresh: float = 1.0 / float(info["refresh_hz"])
		var line: float = budget
		if refresh > line:
			line = refresh
		return delta > line + PRESENT_SLACK_SEC
	return delta > budget + BUDGET_EPS_SEC

static func _percentile(p: float) -> float:
	var n: int = _dts.size()
	if n <= 0:
		return 0.0
	var i: int = int(float(n - 1) * p)
	return snappedf(_dts[i], 0.1)

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
		"pause_slow": pause_slow_n,
		"bar_slow": bar_slow_n,
	}
	var shape: Dictionary = _slow_shape()
	row["n_edge"] = int(shape["n_edge"])
	row["n_stutter"] = int(shape["n_stutter"])
	row["n_spike"] = int(shape["n_spike"])
	row["slow_run_n"] = int(shape["slow_run_n"])
	row["slow_run_med_ms"] = float(shape["slow_run_med_ms"])
	if _dts.size() > 0:
		_dts.sort()
	row["dt_p50_ms"] = _percentile(0.50)
	row["dt_p95_ms"] = _percentile(0.95)
	_stamp_present(row)
	row["bench_gen"] = _bench_gen
	if started and _fh != null:
		_write_row(row)
	else:
		_post(JSON.stringify(row))
	_flush_web()

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
	_stamp_present(row)
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
		"phys_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
		"proc_held": _proc_held,
		"refresh_n": _refresh_n(dt_ms),
		"play_s": snappedf(_play_s, 0.1),
		"frame": int(Engine.get_process_frames()),
		"mult": mult(),
		"thr_ms": snappedf(BUDGET_SEC * mult() * 1000.0, 0.1),
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
	if not _counted and gen != null:
		_counted = true
		_mesh_n = gen.find_children("*", "MeshInstance3D", true, false).size()
		_light_n = scn.find_children("*", "Light3D", true, false).size()
	row["meshes"] = _mesh_n
	row["lights"] = _light_n

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

static func _sample_proc() -> void:
	var proc: float = snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1)
	if _last_proc >= 0.0 and is_equal_approx(proc, _last_proc):
		_proc_held = 1
	else:
		_proc_held = 0
	_last_proc = proc

static func _refresh_n(dt_ms: float) -> int:
	var info: Dictionary = present()
	var refresh_ms: float = 1000.0 / float(info["refresh_hz"])
	if refresh_ms <= 0.0:
		return 1
	return maxi(1, roundi(dt_ms / refresh_ms))

## Counted-frame shape. edge is one late refresh, stutter is two or more, spike is 100 ms or more.
static func _slow_shape() -> Dictionary:
	var info: Dictionary = present()
	var refresh_ms: float = 1000.0 / float(info["refresh_hz"])
	var two: float = refresh_ms * 2.0
	if int(info["paced"]) == 0:
		two = BUDGET_SEC * mult() * 1000.0 * 2.0
	_break_run()
	var edge: int = 0
	var stutter: int = 0
	var spike: int = 0
	for dt: float in _dts:
		if not _over_budget(dt / 1000.0):
			continue
		if dt >= 100.0:
			spike += 1
		elif dt >= two:
			stutter += 1
		else:
			edge += 1
	var med: float = 0.0
	if _run_best_vals.size() > 0:
		var ordered: PackedFloat32Array = _copy_run(_run_best_vals)
		ordered.sort()
		med = snappedf(ordered[int(float(ordered.size()) / 2.0)], 0.1)
	return {
		"n_edge": edge,
		"n_stutter": stutter,
		"n_spike": spike,
		"slow_run_n": _run_best,
		"slow_run_med_ms": med,
	}

static func _copy_run(src: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(src.size())
	for i: int in src.size():
		out[i] = src[i]
	return out

static func _break_run() -> void:
	if _run_n > _run_best:
		_run_best = _run_n
		_run_best_vals = _copy_run(_run_vals)
	_run_n = 0
	_run_vals = PackedFloat32Array()

static func _track_run(dt_ms: float, slow: bool) -> void:
	if not slow:
		_break_run()
		return
	_run_n += 1
	_run_vals.append(dt_ms)

static func _write_mark(reason: String, gap_ms: int) -> void:
	var t_sec: float = 0.0
	if _t0_ms > 0:
		t_sec = snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1)
	var row: Dictionary = {
		"ev": "mark",
		"why": reason,
		"dt_ms": gap_ms,
		"t": t_sec,
		"play_s": snappedf(_play_s, 0.1),
	}
	if _phase != "":
		row["phase"] = _phase
	_write_row(row)

static func _write_gap(delta: float, reason: String) -> void:
	var t_sec: float = 0.0
	if _t0_ms > 0:
		t_sec = snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1)
	var row: Dictionary = {
		"ev": "gap",
		"why": reason,
		"dt_ms": snappedf(delta * 1000.0, 0.1),
		"t": t_sec,
		"play_s": snappedf(_play_s, 0.1),
	}
	if _phase != "":
		row["phase"] = _phase
	_write_row(row)

static func _hub_on_screen(host: Node) -> bool:
	var loader_v: Variant = host.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return false
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return false
	var scene: Node = tree.current_scene
	if scene == null:
		return false
	if str(scene.name) == "Camp":
		return true
	return str(scene.scene_file_path).find("camp") >= 0

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

static func _note_paused(host: Node, delta: float) -> void:
	var dt_ms: float = snappedf(delta * 1000.0, 0.1)
	var row: Dictionary = _hitch_row(host, dt_ms)
	row["paused"] = 1
	hitch_n += 1
	_write_row(row)
	why = ""
	gx = 0
	gy = 0
	_whys.clear()
	_mark_ms = 0

static func _write_row(row: Dictionary) -> void:
	row["bench_gen"] = _bench_gen
	var line: String = JSON.stringify(row)
	# Post before the file write. A web user:// write on the stall frame held
	# the next present. The sink is what the web runner reads.
	_post(line)
	if OS.has_feature("web") or _fh == null:
		return
	_fh.store_line(line)
	_fh.flush()

## Localhost web only. Rows wait here so the frame that measured them does not eval JavaScript.
static func _post(line: String) -> void:
	if not OS.has_feature("web"):
		return
	_web_q.append(line)

static func flush_web() -> void:
	_flush_web()

static func _flush_web() -> void:
	if not OS.has_feature("web") or _web_q.is_empty():
		return
	var i: int = 0
	while i < _web_q.size():
		var js := ""
		var n: int = 0
		while i < _web_q.size() and n < 40:
			js += "fetch('/_wdb/hitch',{method:'POST',keepalive:true,headers:{'Content-Type':'application/json'},body:%s}).catch(function(){});" % JSON.stringify(_web_q[i])
			i += 1
			n += 1
		JavaScriptBridge.eval(js, false)
	_web_q = PackedStringArray()

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
