extends Object

## Split from rows.gd: stamp_edge, clear_edge, set_lit_mark....

## Call at the hitch tick, before the row is built. The physics probes have
## already run. head_ms is whatever the sweep stored on the previous frame.
static func stamp_edge(now_us: int) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	rt._tick_us = now_us
	if rt._edge_post_us <= 0:
		rt._wake_ms = -1.0
		rt._phys_span_ms = -1.0
		rt._post_phys_ms = -1.0
		return
	if not rt._phys_open:
		var bare: float = float(now_us - rt._edge_post_us) / 1000.0
		if bare < 0.0:
			bare = 0.0
		rt._wake_ms = bare
		rt._phys_span_ms = 0.0
		rt._post_phys_ms = 0.0
		return
	var wake: float = float(rt._phys_head_us - rt._edge_post_us) / 1000.0
	var span: float = float(rt._phys_tail_us - rt._phys_head_us) / 1000.0
	var after_phys: float = float(now_us - rt._phys_tail_us) / 1000.0
	if wake < 0.0:
		wake = 0.0
	if span < 0.0:
		span = 0.0
	if after_phys < 0.0:
		after_phys = 0.0
	rt._wake_ms = wake
	rt._phys_span_ms = span
	rt._post_phys_ms = after_phys

static func clear_edge() -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	rt._edge_post_us = 0
	rt._tick_us = 0
	rt._phys_head_us = 0
	rt._phys_tail_us = 0
	rt._phys_open = false
	rt._wake_ms = -1.0
	rt._phys_span_ms = -1.0
	rt._post_phys_ms = -1.0
	rt._head_ms = -1.0
	rt._floor_ms = -1.0
	rt._torch_ms = -1.0
	rt._bar_ms = -1.0

static func set_lit_mark(lit_ms: float, sample_ms: float, sample_n: int, tint_ms: float = -1.0, drive_ms: float = -1.0, geo_ms: float = -1.0, sync_ms: float = -1.0, foot_ms: float = -1.0, quad_ms: float = -1.0, shade_ms: float = -1.0, albedo_ms: float = -1.0, contact_ms: float = -1.0, sole_ms: float = -1.0, pin_ms: float = -1.0) -> void:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	rt._lit_ms = lit_ms
	rt._sample_ms = sample_ms
	rt._sample_n = sample_n
	rt._tint_ms = tint_ms
	rt._drive_ms = drive_ms
	rt._geo_ms = geo_ms
	rt._sync_ms = sync_ms
	rt._foot_ms = foot_ms
	rt._quad_ms = quad_ms
	rt._shade_ms = shade_ms
	rt._albedo_ms = albedo_ms
	rt._contact_ms = contact_ms
	rt._sole_ms = sole_ms
	rt._pin_ms = pin_ms
	rt._sync_rest_ms = _rest4(sync_ms, albedo_ms, contact_ms, foot_ms, quad_ms)
	rt._geo_rest_ms = _rest2(geo_ms, sole_ms, pin_ms)
	rt._lit_rest_ms = _rest_lit(lit_ms, tint_ms, drive_ms, geo_ms, sync_ms, shade_ms)

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

## Once per idle frame, before the bench closes after_ms. Godot samples delta at the
## start of the iteration, then runs physics, then idle. This delta therefore holds
## the previous iteration's playtest, and the after window the bench is about to
## close holds the playtest that just ran. submit (pre_draw to post_draw) holds neither.
static func rotate_harness() -> float:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	if not rt._harness_on:
		rt._pt_ms = 0.0
		return 0.0
	var credit_us: int = rt._harness_hold_us
	rt._harness_hold_us = rt._harness_open_us
	rt._harness_open_us = 0
	rt._pt_ms = snappedf(float(credit_us) / 1000.0, 0.1)
	return float(credit_us) / 1000000.0
