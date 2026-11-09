extends Object

## Local / localhost hitch JSONL. Append on miss. Tail 256. Localhost web also POSTs rows to `perf.py hitch`.

const CAP := Tick.CAP
const CliArgs := preload("res://scripts/app/cli_args.gd")
const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")
const Run := preload("res://scripts/debug/hitch_log/log_run.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Rows := preload("res://scripts/debug/hitch_log/rows.gd")
const LogFile := preload("res://scripts/debug/hitch_log/log_file.gd")
const Session := preload("res://scripts/debug/hitch_log/session.gd")
const Tick := preload("res://scripts/debug/hitch_log/log_tick.gd")
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

## "hub" (default) counts camp. "dungeon" counts the dungeon scene. Anything else stays hub.
static func set_score_where(where_name: String) -> void:
	Ctx.set_score_where(where_name)

## Sweep stretch name (hub1, dungeon1, hub2, dungeon2). Empty leaves it off the hitch row.
static func set_seg(seg_name: String) -> void:
	Rows.set_seg(seg_name)

static func scoring(host: Node) -> bool:
	return Ctx._score_on_screen(host)

static func set_play_s(sec: float) -> void:
	Rows.set_play_s(sec)

static func set_tree_ms(ms: float) -> void:
	Rows.set_tree_ms(ms)

static func set_submit_ms(ms: float) -> void:
	Rows.set_submit_ms(ms)

static func set_after_ms(ms: float) -> void:
	Rows.set_after_ms(ms)

## Sweep only. Parts of tree_ms. A negative part stays off the hitch row.
static func set_tree_split(script_ms: float, queue_ms: float, tail_ms: float) -> void:
	Rows.set_tree_split(script_ms, queue_ms, tail_ms)

static func set_edge_post(us: int) -> void:
	Rows.set_edge_post(us)

static func note_phys_head() -> void:
	Rows.note_phys_head()

static func note_phys_tail() -> void:
	Rows.note_phys_tail()

static func set_idle_ms(floor_ms: float, bar_ms: float) -> void:
	Rows.set_idle_ms(floor_ms, bar_ms)

static func set_head_ms(ms: float) -> void:
	Rows.set_head_ms(ms)

static func tick_us() -> int:
	return Rows.tick_us()

static func set_bench_ms(ms: float) -> void:
	Rows.set_bench_ms(ms)

static func set_draw_split(obj_3d: int, prim_3d: int, draw_3d: int, obj_shadow: int, prim_shadow: int, draw_shadow: int, obj_canvas: int, prim_canvas: int, draw_canvas: int) -> void:
	Rows.set_draw_split(obj_3d, prim_3d, draw_3d, obj_shadow, prim_shadow, draw_shadow, obj_canvas, prim_canvas, draw_canvas)

static func set_lit_mark(lit_ms: float, sample_ms: float, sample_n: int, tint_ms: float = -1.0, drive_ms: float = -1.0, geo_ms: float = -1.0, sync_ms: float = -1.0, foot_ms: float = -1.0, quad_ms: float = -1.0, shade_ms: float = -1.0, albedo_ms: float = -1.0, contact_ms: float = -1.0, sole_ms: float = -1.0, pin_ms: float = -1.0) -> void:
	Rows.set_lit_mark(lit_ms, sample_ms, sample_n, tint_ms, drive_ms, geo_ms, sync_ms, foot_ms, quad_ms, shade_ms, albedo_ms, contact_ms, sole_ms, pin_ms)

static func set_render_ms(cpu_ms: float, gpu_ms: float) -> void:
	Rows.set_render_ms(cpu_ms, gpu_ms)

static func set_lit_peak(ms: float, who: String) -> void:
	Rows.set_lit_peak(ms, who)

## Sweep layer window. Counted frames stay the scored walk. Hidden frames do not.
static func set_unscored(on: bool) -> void:
	Rows.set_unscored(on)

static func frame_submit_ms() -> float:
	return Rows.frame_submit_ms()

static func frame_split() -> Dictionary:
	return Rows.frame_split()

## Dungeon bench. Later ticks subtract the playtest physics tick from the scored delta.
static func arm_harness() -> void:
	Rows.arm_harness()

static func add_harness_us(us: int) -> void:
	Rows.add_harness_us(us)

static func harness_in_after_ms() -> float:
	return Rows.harness_in_after_ms()

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
	Tick._note(host, sec)

## Bench start: apply the multiplier and replace the hitch file so the run is one session.
static func bench_reset(mult_value: float) -> void:
	Session.bench_reset(mult_value)

static func begin(_host: Node = null) -> void:
	Session.begin(_host)

static func tick(host: Node, delta: float) -> void:
	Tick.tick(host, delta)

static func copy_text() -> String:
	var txt: String = LogFile._read_all()
	if txt != "":
		DisplayServer.clipboard_set(txt)
	return txt

static func clear_log() -> void:
	Session.clear_log()

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
	Session.bench_done(sec, ok, missing)

static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	Rows.mark(reason, origin)

static func status_line() -> String:
	if not enabled():
		return "Hitch log off"
	var worst: String = "0"
	if worst_ms > 0.0:
		worst = str(snappedf(worst_ms, 0.1))
	return "Hitch %d/%d  worst %s ms  x%.2f  %s" % [hitch_n, CAP, worst, mult(), file_path]

static func flush_web() -> void:
	Web._flush_web()
