extends Object

## Split from hitch_log.gd: bench_reset, begin, clear_log....

const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Rows := preload("res://scripts/debug/hitch_log/rows.gd")
const Run := preload("res://scripts/debug/hitch_log/log_run.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")
const CliArgs := preload("res://scripts/app/cli_args.gd")
const LogFile := preload("res://scripts/debug/hitch_log/log_file.gd")

const REL_DIR := "hitch"
const REL_FILE := "hitch.jsonl"

## Bench start: apply the multiplier and replace the hitch file so the run is one session.
static func bench_reset(mult_value: float) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	rt.set_mult(mult_value)
	rt.close()
	var path: String = OS.get_user_data_dir().path_join(REL_DIR).path_join(REL_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	Rows.started = false
	rt.hitch_n = 0
	rt.worst_ms = 0.0
	Rows.why = ""
	Rows.gx = 0
	Rows.gy = 0
	Rows._whys = PackedStringArray()
	Rows._mark_ms = 0
	Rows._mark_frame = -1
	rt._skip_gap = false
	Rows._keep_all = true
	rt.frame_n = 0
	rt.slow_n = 0
	rt.pause_slow_n = 0
	rt.bar_slow_n = 0
	Present._dts = PackedFloat32Array()
	Present._pts = PackedFloat32Array()
	Rows.clear_harness()
	Rows.set_tree_split(-1.0, -1.0, -1.0)
	Rows.clear_edge()
	Rows.set_bench_ms(-1.0)
	Rows.set_lit_mark(-1.0, -1.0, -1)
	Rows.set_render_ms(-1.0, -1.0)
	Rows.set_lit_peak(-1.0, "")
	Rows.set_unscored(false)
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
	Ctx.set_score_where("hub")
	rt._emit_at = -100000
	Rows._bench_gen += 1
	rt.file_path = ""
	Rows._t0_ms = 0
	begin()

static func begin(_host: Node = null) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	if Rows.started or not rt.enabled():
		return
	if Present._mult <= 0.0:
		var cli_mult: float = CliArgs.float_arg("--wdb-hitch-mult", 0.0)
		if cli_mult > 0.0:
			rt.set_mult(cli_mult)
	Rows.ver = Ctx._ver_label()
	Rows._t0_ms = Time.get_ticks_msec()
	var dir_path: String = OS.get_user_data_dir().path_join(REL_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	rt.file_path = dir_path.path_join(REL_FILE)
	LogFile._trim_file()
	Rows._fh = FileAccess.open(rt.file_path, FileAccess.READ_WRITE)
	if Rows._fh == null:
		Rows._fh = FileAccess.open(rt.file_path, FileAccess.WRITE_READ)
	if Rows._fh == null:
		return
	Rows._fh.seek_end()
	Rows.started = true
	rt.hitch_n = LogFile._count_hitches()
	Rows._write_row(Rows._session_row())

static func clear_log() -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	Rows._close()
	if rt.file_path != "" and FileAccess.file_exists(rt.file_path):
		DirAccess.remove_absolute(rt.file_path)
	Rows.started = false
	rt.hitch_n = 0
	rt.worst_ms = 0.0
	rt.frame_n = 0
	rt.slow_n = 0
	Present._dts = PackedFloat32Array()
	Present._pts = PackedFloat32Array()
	if rt.enabled():
		begin()

## One session row the hub bench runner reads (desktop file and the localhost hitch sink).
static func bench_done(sec: float, ok: bool, missing: String) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log.gd")
	if not rt.enabled():
		return
	if not Rows.started:
		begin()
	var row: Dictionary = {
		"ev": "bench",
		"sec": snappedf(sec, 0.1),
		"ok": 1 if ok else 0,
		"missing": missing,
		"hitches": rt.hitch_n,
		"frames": rt.frame_n,
		"slow": rt.slow_n,
		"fps_pct": rt.fps_pct(),
		"worst_ms": snappedf(rt.worst_ms, 0.1),
		"web": 1 if OS.has_feature("web") else 0,
		"pause_slow": rt.pause_slow_n,
		"bar_slow": rt.bar_slow_n,
	}
	Rows.emit_bench(row)
