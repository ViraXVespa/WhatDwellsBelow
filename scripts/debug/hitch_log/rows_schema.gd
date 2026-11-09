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
	var timings: Dictionary = {
		"script_ms": rt._script_ms,
		"queue_ms": rt._queue_ms,
		"tail_ms": rt._tail_ms,
		"bench_ms": rt._bench_ms,
		"lit_ms": rt._lit_ms,
		"sample_ms": rt._sample_ms,
		"sample_n": rt._sample_n,
		"tint_ms": rt._tint_ms,
		"drive_ms": rt._drive_ms,
		"geo_ms": rt._geo_ms,
		"sync_ms": rt._sync_ms,
		"foot_ms": rt._foot_ms,
		"quad_ms": rt._quad_ms,
		"shade_ms": rt._shade_ms,
		"albedo_ms": rt._albedo_ms,
		"contact_ms": rt._contact_ms,
		"sole_ms": rt._sole_ms,
		"pin_ms": rt._pin_ms,
		"sync_rest_ms": rt._sync_rest_ms,
		"geo_rest_ms": rt._geo_rest_ms,
		"lit_rest_ms": rt._lit_rest_ms,
		"lit_max_ms": rt._lit_max_ms,
		"lit_who": rt._lit_who,
		"cpu_ms": rt._cpu_ms,
		"gpu_ms": rt._gpu_ms,
		"wake_ms": rt._wake_ms,
		"phys_span_ms": rt._phys_span_ms,
		"post_phys_ms": rt._post_phys_ms,
		"head_ms": rt._head_ms,
		"floor_ms": rt._floor_ms,
		"bar_ms": rt._bar_ms
	}
	for key: String in timings:
		var value: Variant = timings[key]
		if key == "lit_who":
			if value != "":
				row[key] = value
		elif key == "sample_n":
			if value >= 0:
				row[key] = value
		elif value >= 0.0:
			row[key] = snappedf(float(value), 0.1)
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
