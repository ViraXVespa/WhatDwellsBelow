extends Object

## Split from hitch_log.gd: _hitch_row, _session_row, _sample_proc....

const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")
const Web := preload("res://scripts/debug/hitch_log/log_web.gd")

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
## sample_ms is LightRt.sample_xz (inside tint_ms). foot_ms and quad_ms sit inside sync_ms.
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
const KIND := "wdb_hitch_log"
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
	if _seg != "":
		row["seg"] = _seg
	if not _whys.is_empty():
		row["why"] = ",".join(_whys)
	elif why != "":
		row["why"] = why
	if why == "geo_activate" or (not _whys.is_empty() and _whys[_whys.size() - 1].begins_with("geo_activate")):
		row["gx"] = gx
		row["gy"] = gy
	if str(row.get("where", "")) == "hub":
		Ctx._hub_ctx(host, row)
	row["tree_ms"] = snappedf(_tree_ms, 0.1)
	row["submit_ms"] = snappedf(_submit_ms, 0.1)
	row["after_ms"] = snappedf(_after_ms, 0.1)
	if _script_ms >= 0.0:
		row["script_ms"] = snappedf(_script_ms, 0.1)
	if _queue_ms >= 0.0:
		row["queue_ms"] = snappedf(_queue_ms, 0.1)
	if _tail_ms >= 0.0:
		row["tail_ms"] = snappedf(_tail_ms, 0.1)
	if _bench_ms >= 0.0:
		row["bench_ms"] = snappedf(_bench_ms, 0.1)
	if _lit_ms >= 0.0:
		row["lit_ms"] = snappedf(_lit_ms, 0.1)
	if _sample_ms >= 0.0:
		row["sample_ms"] = snappedf(_sample_ms, 0.1)
	if _sample_n >= 0:
		row["sample_n"] = _sample_n
	if _tint_ms >= 0.0:
		row["tint_ms"] = snappedf(_tint_ms, 0.1)
	if _drive_ms >= 0.0:
		row["drive_ms"] = snappedf(_drive_ms, 0.1)
	if _geo_ms >= 0.0:
		row["geo_ms"] = snappedf(_geo_ms, 0.1)
	if _sync_ms >= 0.0:
		row["sync_ms"] = snappedf(_sync_ms, 0.1)
	if _foot_ms >= 0.0:
		row["foot_ms"] = snappedf(_foot_ms, 0.1)
	if _quad_ms >= 0.0:
		row["quad_ms"] = snappedf(_quad_ms, 0.1)
	if _shade_ms >= 0.0:
		row["shade_ms"] = snappedf(_shade_ms, 0.1)
	if _albedo_ms >= 0.0:
		row["albedo_ms"] = snappedf(_albedo_ms, 0.1)
	if _contact_ms >= 0.0:
		row["contact_ms"] = snappedf(_contact_ms, 0.1)
	if _sole_ms >= 0.0:
		row["sole_ms"] = snappedf(_sole_ms, 0.1)
	if _pin_ms >= 0.0:
		row["pin_ms"] = snappedf(_pin_ms, 0.1)
	if _sync_rest_ms >= 0.0:
		row["sync_rest_ms"] = snappedf(_sync_rest_ms, 0.1)
	if _geo_rest_ms >= 0.0:
		row["geo_rest_ms"] = snappedf(_geo_rest_ms, 0.1)
	if _lit_rest_ms >= 0.0:
		row["lit_rest_ms"] = snappedf(_lit_rest_ms, 0.1)
	if _lit_max_ms >= 0.0:
		row["lit_max_ms"] = snappedf(_lit_max_ms, 0.1)
	if _lit_who != "":
		row["lit_who"] = _lit_who
	if _cpu_ms >= 0.0:
		row["cpu_ms"] = snappedf(_cpu_ms, 0.1)
	if _gpu_ms >= 0.0:
		row["gpu_ms"] = snappedf(_gpu_ms, 0.1)
	if _wake_ms >= 0.0:
		row["wake_ms"] = snappedf(_wake_ms, 0.1)
	if _phys_span_ms >= 0.0:
		row["phys_span_ms"] = snappedf(_phys_span_ms, 0.1)
	if _post_phys_ms >= 0.0:
		row["post_phys_ms"] = snappedf(_post_phys_ms, 0.1)
	if _head_ms >= 0.0:
		row["head_ms"] = snappedf(_head_ms, 0.1)
	if _obj_3d >= 0:
		row["obj_3d"] = _obj_3d
		row["prim_3d"] = _prim_3d
		row["draw_3d"] = _draw_3d
		row["obj_shadow"] = _obj_shadow
		row["prim_shadow"] = _prim_shadow
		row["draw_shadow"] = _draw_shadow
		row["obj_canvas"] = _obj_canvas
		row["prim_canvas"] = _prim_canvas
		row["draw_canvas"] = _draw_canvas
	if _harness_on:
		row["pt_ms"] = _pt_ms
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
	_tick_us = now_us
	if _edge_post_us <= 0:
		_wake_ms = -1.0
		_phys_span_ms = -1.0
		_post_phys_ms = -1.0
		return
	if not _phys_open:
		var bare: float = float(now_us - _edge_post_us) / 1000.0
		if bare < 0.0:
			bare = 0.0
		_wake_ms = bare
		_phys_span_ms = 0.0
		_post_phys_ms = 0.0
		return
	var wake: float = float(_phys_head_us - _edge_post_us) / 1000.0
	var span: float = float(_phys_tail_us - _phys_head_us) / 1000.0
	var after_phys: float = float(now_us - _phys_tail_us) / 1000.0
	if wake < 0.0:
		wake = 0.0
	if span < 0.0:
		span = 0.0
	if after_phys < 0.0:
		after_phys = 0.0
	_wake_ms = wake
	_phys_span_ms = span
	_post_phys_ms = after_phys

static func clear_edge() -> void:
	_edge_post_us = 0
	_tick_us = 0
	_phys_head_us = 0
	_phys_tail_us = 0
	_phys_open = false
	_wake_ms = -1.0
	_phys_span_ms = -1.0
	_post_phys_ms = -1.0
	_head_ms = -1.0

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
	_lit_ms = lit_ms
	_sample_ms = sample_ms
	_sample_n = sample_n
	_tint_ms = tint_ms
	_drive_ms = drive_ms
	_geo_ms = geo_ms
	_sync_ms = sync_ms
	_foot_ms = foot_ms
	_quad_ms = quad_ms
	_shade_ms = shade_ms
	_albedo_ms = albedo_ms
	_contact_ms = contact_ms
	_sole_ms = sole_ms
	_pin_ms = pin_ms
	_sync_rest_ms = _rest4(sync_ms, albedo_ms, contact_ms, foot_ms, quad_ms)
	_geo_rest_ms = _rest2(geo_ms, sole_ms, pin_ms)
	_lit_rest_ms = _rest_lit(lit_ms, tint_ms, drive_ms, geo_ms, sync_ms, shade_ms)

static func _rest2(total: float, a: float, b: float) -> float:
	if total < 0.0 or a < 0.0 or b < 0.0:
		return -1.0
	var rest: float = total - a - b
	if rest < 0.0:
		return 0.0
	return rest

static func _rest4(total: float, a: float, b: float, c: float, d: float) -> float:
	if total < 0.0 or a < 0.0 or b < 0.0 or c < 0.0 or d < 0.0:
		return -1.0
	var rest: float = total - a - b - c - d
	if rest < 0.0:
		return 0.0
	return rest

static func _rest_lit(total: float, tint_ms: float, drive_ms: float, geo_ms: float, sync_ms: float, shade_ms: float) -> float:
	if total < 0.0 or tint_ms < 0.0 or drive_ms < 0.0 or geo_ms < 0.0 or sync_ms < 0.0 or shade_ms < 0.0:
		return -1.0
	var rest: float = total - tint_ms - drive_ms - geo_ms - sync_ms - shade_ms
	if rest < 0.0:
		return 0.0
	return rest

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
	if not _harness_on:
		_pt_ms = 0.0
		return 0.0
	var credit_us: int = _harness_hold_us
	_harness_hold_us = _harness_open_us
	_harness_open_us = 0
	_pt_ms = snappedf(float(credit_us) / 1000.0, 0.1)
	return float(credit_us) / 1000000.0

static func harness_in_after_ms() -> float:
	if not _harness_on:
		return 0.0
	return snappedf(float(_harness_hold_us) / 1000.0, 0.1)

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

## The bench row (hitch_log.gd bench_done): stats, generation, then the file or the localhost sink.
static func emit_bench(row: Dictionary) -> void:
	Present.bench_stats(row)
	row["bench_gen"] = _bench_gen
	if started and _fh != null:
		_write_row(row)
	else:
		Web._post(JSON.stringify(row))
	Web._flush_web()
