extends Object

## Split from rows.gd: _hitch_row, _session_row, KIND.

const Ctx := preload("res://scripts/debug/hitch_log/ctx.gd")
const Present := preload("res://scripts/debug/hitch_log/log_present.gd")

const KIND := "wdb_hitch_log"

static func _hitch_row(host: Node, dt_ms: float) -> Dictionary:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var row: Dictionary = {
		"ev": "hitch",
		"ver": rt.ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"t": rt._t_sec(),
		"dt_ms": dt_ms,
		"where": Ctx._where(host),
		"fl": int(App.floor_n) if App else 0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"proc_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
		"phys_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
		"proc_held": rt._proc_held,
		"refresh_n": Present._refresh_n(dt_ms),
		"play_s": snappedf(rt._play_s, 0.1),
		"frame": int(Engine.get_process_frames()),
		"mult": Present.mult(),
		"thr_ms": snappedf(Present.BUDGET_SEC * Present.mult() * 1000.0, 0.1),
	}
	if rt._phase != "":
		row["phase"] = rt._phase
	if rt._seg != "":
		row["seg"] = rt._seg
	if not rt._whys.is_empty():
		row["why"] = ",".join(rt._whys)
	elif rt.why != "":
		row["why"] = rt.why
	if rt.why == "geo_activate" or (not rt._whys.is_empty() and rt._whys[rt._whys.size() - 1].begins_with("geo_activate")):
		row["gx"] = rt.gx
		row["gy"] = rt.gy
	if str(row.get("where", "")) == "hub":
		Ctx._hub_ctx(host, row)
	row["tree_ms"] = snappedf(rt._tree_ms, 0.1)
	row["submit_ms"] = snappedf(rt._submit_ms, 0.1)
	row["after_ms"] = snappedf(rt._after_ms, 0.1)
	if rt._script_ms >= 0.0:
		row["script_ms"] = snappedf(rt._script_ms, 0.1)
	if rt._queue_ms >= 0.0:
		row["queue_ms"] = snappedf(rt._queue_ms, 0.1)
	if rt._tail_ms >= 0.0:
		row["tail_ms"] = snappedf(rt._tail_ms, 0.1)
	if rt._bench_ms >= 0.0:
		row["bench_ms"] = snappedf(rt._bench_ms, 0.1)
	if rt._lit_ms >= 0.0:
		row["lit_ms"] = snappedf(rt._lit_ms, 0.1)
	if rt._sample_ms >= 0.0:
		row["sample_ms"] = snappedf(rt._sample_ms, 0.1)
	if rt._sample_n >= 0:
		row["sample_n"] = rt._sample_n
	if rt._tint_ms >= 0.0:
		row["tint_ms"] = snappedf(rt._tint_ms, 0.1)
	if rt._drive_ms >= 0.0:
		row["drive_ms"] = snappedf(rt._drive_ms, 0.1)
	if rt._geo_ms >= 0.0:
		row["geo_ms"] = snappedf(rt._geo_ms, 0.1)
	if rt._sync_ms >= 0.0:
		row["sync_ms"] = snappedf(rt._sync_ms, 0.1)
	if rt._foot_ms >= 0.0:
		row["foot_ms"] = snappedf(rt._foot_ms, 0.1)
	if rt._quad_ms >= 0.0:
		row["quad_ms"] = snappedf(rt._quad_ms, 0.1)
	if rt._shade_ms >= 0.0:
		row["shade_ms"] = snappedf(rt._shade_ms, 0.1)
	if rt._albedo_ms >= 0.0:
		row["albedo_ms"] = snappedf(rt._albedo_ms, 0.1)
	if rt._contact_ms >= 0.0:
		row["contact_ms"] = snappedf(rt._contact_ms, 0.1)
	if rt._sole_ms >= 0.0:
		row["sole_ms"] = snappedf(rt._sole_ms, 0.1)
	if rt._pin_ms >= 0.0:
		row["pin_ms"] = snappedf(rt._pin_ms, 0.1)
	if rt._sync_rest_ms >= 0.0:
		row["sync_rest_ms"] = snappedf(rt._sync_rest_ms, 0.1)
	if rt._geo_rest_ms >= 0.0:
		row["geo_rest_ms"] = snappedf(rt._geo_rest_ms, 0.1)
	if rt._lit_rest_ms >= 0.0:
		row["lit_rest_ms"] = snappedf(rt._lit_rest_ms, 0.1)
	if rt._lit_max_ms >= 0.0:
		row["lit_max_ms"] = snappedf(rt._lit_max_ms, 0.1)
	if rt._lit_who != "":
		row["lit_who"] = rt._lit_who
	if rt._cpu_ms >= 0.0:
		row["cpu_ms"] = snappedf(rt._cpu_ms, 0.1)
	if rt._gpu_ms >= 0.0:
		row["gpu_ms"] = snappedf(rt._gpu_ms, 0.1)
	if rt._wake_ms >= 0.0:
		row["wake_ms"] = snappedf(rt._wake_ms, 0.1)
	if rt._phys_span_ms >= 0.0:
		row["phys_span_ms"] = snappedf(rt._phys_span_ms, 0.1)
	if rt._post_phys_ms >= 0.0:
		row["post_phys_ms"] = snappedf(rt._post_phys_ms, 0.1)
	if rt._head_ms >= 0.0:
		row["head_ms"] = snappedf(rt._head_ms, 0.1)
	if rt._floor_ms >= 0.0:
		row["floor_ms"] = snappedf(rt._floor_ms, 0.1)
	if rt._torch_ms >= 0.0:
		row["torch_ms"] = snappedf(rt._torch_ms, 0.1)
	if rt._bar_ms >= 0.0:
		row["bar_ms"] = snappedf(rt._bar_ms, 0.1)
	if rt._wake_ms >= 0.0:
		row["phys_obj"] = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
		row["phys_pairs"] = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
		row["phys_islands"] = int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))
	if rt._obj_3d >= 0:
		row["obj_3d"] = rt._obj_3d
		row["prim_3d"] = rt._prim_3d
		row["draw_3d"] = rt._draw_3d
		row["obj_shadow"] = rt._obj_shadow
		row["prim_shadow"] = rt._prim_shadow
		row["draw_shadow"] = rt._draw_shadow
		row["obj_canvas"] = rt._obj_canvas
		row["prim_canvas"] = rt._prim_canvas
		row["draw_canvas"] = rt._draw_canvas
	if rt._harness_on:
		row["pt_ms"] = rt._pt_ms
	return row

static func _session_row() -> Dictionary:
	var rt: Variant = load("res://scripts/debug/hitch_log/rows.gd")
	var row: Dictionary = {
		"ev": "session",
		"kind": KIND,
		"ver": rt.ver,
		"at": Time.get_datetime_string_from_system(false, true),
		"os": OS.get_name(),
		"web": 1 if OS.has_feature("web") else 0,
		"godot": str(Engine.get_version_info().get("string", "")),
		"mult": Present.mult(),
		"thr_ms": snappedf(Present.BUDGET_SEC * Present.mult() * 1000.0, 0.1),
	}
	Present._stamp_present(row)
	return row
