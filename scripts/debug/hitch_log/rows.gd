extends Object

## Split from hitch_log.gd: _hitch_row, _session_row, _sample_proc....

const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")

const Schema := preload("res://scripts/debug/hitch_log/rows_schema.gd")
const Clock := preload("res://scripts/debug/hitch_log/rows_clock.gd")
const Sink := preload("res://scripts/debug/hitch_log/rows_sink.gd")
static var _phase: String = ""
## Sweep stretch: hub1, dungeon1, hub2, dungeon2. Empty leaves the key off the row.
static var _seg: String = ""
static var _play_s: float = 0.0
static var _submit_ms: float = -1.0
static var _tree_ms: float = -1.0
static var _after_ms: float = -1.0
## Sweep only. -1 leaves the keys off the row (hub and dungeon benches).
static var _script_ms: float = -1.0
static var _queue_ms: float = -1.0
static var _tail_ms: float = -1.0
## Sweep only. bench_ms is the hub bench _process. lit_ms is every ActorLit _process.
## sample_ms is LightRt.sample_xz. Actor tint does not call it. foot_ms and quad_ms sit inside sync_ms.
## -1 leaves the keys off the row.
static var _bench_ms: float = -1.0
static var _lit_ms: float = -1.0
static var _sample_ms: float = -1.0
static var _sample_n: int = -1
static var _tint_ms: float = -1.0
static var _drive_ms: float = -1.0
static var _geo_ms: float = -1.0
static var _sync_ms: float = -1.0
static var _foot_ms: float = -1.0
static var _quad_ms: float = -1.0
static var _shade_ms: float = -1.0
## Sweep only. albedo_ms and contact_ms sit inside sync_ms. sole_ms and pin_ms sit inside geo_ms.
## The rest fields are what those parts do not cover. cpu_ms and gpu_ms are the previous frame.
static var _albedo_ms: float = -1.0
static var _contact_ms: float = -1.0
static var _sole_ms: float = -1.0
static var _pin_ms: float = -1.0
static var _sync_rest_ms: float = -1.0
static var _geo_rest_ms: float = -1.0
static var _lit_rest_ms: float = -1.0
static var _lit_max_ms: float = -1.0
static var _lit_who: String = ""
static var _cpu_ms: float = -1.0
static var _gpu_ms: float = -1.0
## Sweep only. The hitch tick is App._process, which is where dt is measured.
## wake_ms is post-draw until the first _physics_process (present and the engine
## step before scripts). phys_span_ms is first to last _physics_process.
## post_phys_ms is that last script until the hitch tick. head_ms is the hitch
## tick until the sweep _process. -1 leaves the keys off the row.
static var _edge_post_us: int = 0
static var _tick_us: int = 0
static var _phys_head_us: int = 0
static var _phys_tail_us: int = 0
static var _phys_open: bool = false
static var _wake_ms: float = -1.0
static var _phys_span_ms: float = -1.0
static var _post_phys_ms: float = -1.0
static var _head_ms: float = -1.0
## Sweep only. Dungeon process_floor and hp-bar _process.
## -1 leaves the keys off the row.
static var _floor_ms: float = -1.0
static var _bar_ms: float = -1.0
## Sweep layer window. Those frames are not in fps_pct.
static var _unscored: bool = false
## Sweep only. Visible, shadow, and canvas counts for the frame whose submit_ms just closed.
## -1 leaves the keys off the row. Draw-call total is already "draw"; these name the pass.
static var _obj_3d: int = -1
static var _prim_3d: int = -1
static var _draw_3d: int = -1
static var _obj_shadow: int = -1
static var _prim_shadow: int = -1
static var _draw_shadow: int = -1
static var _obj_canvas: int = -1
static var _prim_canvas: int = -1
static var _draw_canvas: int = -1
static var _proc_held: int = 0
static var _t0_ms: int = 0
static var _whys: PackedStringArray = PackedStringArray()
static var gx: int = 0
static var gy: int = 0
static var ver: String = ""
static var why: String = ""
static var _last_proc: float = -1.0
static var _bench_gen: int = 0
static var _fh: FileAccess = null
static var _mark_ms: int = 0
static var _keep_all: bool = false
static var _mark_frame: int = -1
static var started: bool = false
## Dungeon bench only. The playtest tick is the harness, not the frame the player pays.
## open = this iteration's physics (not in this delta). hold = previous iteration, which is.
static var _harness_on: bool = false
static var _harness_open_us: int = 0
static var _harness_hold_us: int = 0
static var _pt_ms: float = 0.0

## Seconds since the log started (0.1 s steps), 0 before it starts.
static func _t_sec() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0_ms) / 1000.0, 0.1) if _t0_ms > 0 else 0.0

static func _hitch_row(host: Node, dt_ms: float) -> Dictionary:
	return Schema._hitch_row(host, dt_ms)

static func _session_row() -> Dictionary:
	return Schema._session_row()

static func _sample_proc() -> void:
	var proc: float = snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1)
	if _last_proc >= 0.0 and is_equal_approx(proc, _last_proc):
		_proc_held = 1
	else:
		_proc_held = 0
	_last_proc = proc

static func _write_gap(delta: float, reason: String) -> void:
	Sink._write_gap(delta, reason)

static func set_phase(phase_name: String) -> void:
	_phase = phase_name

static func set_seg(seg_name: String) -> void:
	_seg = seg_name

static func set_play_s(sec: float) -> void:
	_play_s = sec

static func set_tree_ms(ms: float) -> void:
	_tree_ms = ms

static func set_submit_ms(ms: float) -> void:
	_submit_ms = ms

static func set_after_ms(ms: float) -> void:
	_after_ms = ms

## script_ms + queue_ms + tail_ms partition tree_ms. A negative part stays off the row.
static func set_tree_split(script_ms: float, queue_ms: float, tail_ms: float) -> void:
	_script_ms = script_ms
	_queue_ms = queue_ms
	_tail_ms = tail_ms

## Post-draw of the frame the next hitch tick will close.
static func set_edge_post(us: int) -> void:
	_edge_post_us = us
	_phys_open = false

static func note_phys_head() -> void:
	if _phys_open:
		return
	_phys_open = true
	_phys_head_us = Time.get_ticks_usec()

static func note_phys_tail() -> void:
	_phys_tail_us = Time.get_ticks_usec()

static func set_idle_ms(floor_ms: float, bar_ms: float) -> void:
	_floor_ms = floor_ms
	_bar_ms = bar_ms

static func set_head_ms(ms: float) -> void:
	if ms < 0.0:
		_head_ms = 0.0
		return
	_head_ms = ms

static func tick_us() -> int:
	return _tick_us

## Call at the hitch tick, before the row is built. The physics probes have
## already run. head_ms is whatever the sweep stored on the previous frame.
static func stamp_edge(now_us: int) -> void:
	Clock.stamp_edge(now_us)

static func clear_edge() -> void:
	Clock.clear_edge()

static func set_bench_ms(ms: float) -> void:
	_bench_ms = ms

static func set_draw_split(obj_3d: int, prim_3d: int, draw_3d: int, obj_shadow: int, prim_shadow: int, draw_shadow: int, obj_canvas: int, prim_canvas: int, draw_canvas: int) -> void:
	_obj_3d = obj_3d
	_prim_3d = prim_3d
	_draw_3d = draw_3d
	_obj_shadow = obj_shadow
	_prim_shadow = prim_shadow
	_draw_shadow = draw_shadow
	_obj_canvas = obj_canvas
	_prim_canvas = prim_canvas
	_draw_canvas = draw_canvas

static func set_lit_mark(lit_ms: float, sample_ms: float, sample_n: int, tint_ms: float = -1.0, drive_ms: float = -1.0, geo_ms: float = -1.0, sync_ms: float = -1.0, foot_ms: float = -1.0, quad_ms: float = -1.0, shade_ms: float = -1.0, albedo_ms: float = -1.0, contact_ms: float = -1.0, sole_ms: float = -1.0, pin_ms: float = -1.0) -> void:
	Clock.set_lit_mark(lit_ms, sample_ms, sample_n, tint_ms, drive_ms, geo_ms, sync_ms, foot_ms, quad_ms, shade_ms, albedo_ms, contact_ms, sole_ms, pin_ms)

static func set_render_ms(cpu_ms: float, gpu_ms: float) -> void:
	_cpu_ms = cpu_ms
	_gpu_ms = gpu_ms

static func set_lit_peak(ms: float, who: String) -> void:
	_lit_max_ms = ms
	_lit_who = who

static func set_unscored(on: bool) -> void:
	_unscored = on

static func unscored() -> bool:
	return _unscored

static func frame_submit_ms() -> float:
	return _submit_ms

static func frame_split() -> Dictionary:
	var row: Dictionary = {
		"submit_ms": _submit_ms,
		"tree_ms": _tree_ms,
		"cpu_ms": _cpu_ms,
		"gpu_ms": _gpu_ms,
		"lit_ms": _lit_ms,
		"geo_ms": _geo_ms,
		"sync_ms": _sync_ms,
		"albedo_ms": _albedo_ms,
		"contact_ms": _contact_ms,
		"draw_3d": float(_draw_3d),
	}
	return row

static func harness_on() -> bool:
	return _harness_on

static func pt_ms() -> float:
	return _pt_ms

static func arm_harness() -> void:
	_harness_on = true
	_harness_open_us = 0
	_harness_hold_us = 0
	_pt_ms = 0.0

static func clear_harness() -> void:
	_harness_on = false
	_harness_open_us = 0
	_harness_hold_us = 0
	_pt_ms = 0.0

static func add_harness_us(us: int) -> void:
	if _harness_on and us > 0:
		_harness_open_us += us

## Once per idle frame, before the bench closes after_ms. Godot samples delta at the
## start of the iteration, then runs physics, then idle. This delta therefore holds
## the previous iteration's playtest, and the after window the bench is about to
## close holds the playtest that just ran. submit (pre_draw to post_draw) holds neither.
static func rotate_harness() -> float:
	return Clock.rotate_harness()

static func harness_in_after_ms() -> float:
	if not _harness_on:
		return 0.0
	return snappedf(float(_harness_hold_us) / 1000.0, 0.1)

static func _write_row(row: Dictionary) -> void:
	Sink._write_row(row)

static func _note_bar(host: Node, delta: float) -> void:
	Sink._note_bar(host, delta)

static func _close() -> void:
	Sink._close()

static func mark(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	Sink.mark(reason, origin)

## The bench row (hitch_log.gd bench_done): stats, generation, then the file or the localhost sink.
static func emit_bench(row: Dictionary) -> void:
	Sink.emit_bench(row)
