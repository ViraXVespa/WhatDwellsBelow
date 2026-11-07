extends Object

## Split from perf_sweep.gd: _on_pre_draw, _on_post_draw, _arm_render....

const ActorLit := preload("res://scripts/graphics/actor_lit.gd")
const DungeonBoot := preload("res://scripts/world/dungeon/dungeon_boot.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const HpBar := preload("res://scripts/combat/hp_bar.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const TorchBill := preload("res://scripts/graphics/torch_bill.gd")

static func _on_pre_draw(host: Node) -> void:
	var now: int = Time.get_ticks_usec()
	if host._proc_us > 0:
		host._tree_ms = float(now - host._proc_us) / 1000.0
	host._script_ms = -1.0
	host._queue_ms = -1.0
	host._tail_ms = -1.0
	if not host._done and host._tail != null and host._proc_us > 0:
		var script_us: int = host._tail.script_us
		if script_us >= host._proc_us:
			host._script_ms = float(script_us - host._proc_us) / 1000.0
			var queue_us: int = host._tail.queue_us
			if queue_us >= script_us:
				host._queue_ms = float(queue_us - script_us) / 1000.0
				host._tail_ms = float(now - queue_us) / 1000.0
			else:
				host._tail_ms = float(now - script_us) / 1000.0
	host._pre_us = now

static func _on_post_draw(host: Node) -> void:
	var now: int = Time.get_ticks_usec()
	HitchLog.set_tree_ms(host._tree_ms)
	HitchLog.set_tree_split(host._script_ms, host._queue_ms, host._tail_ms)
	var parts: PackedFloat32Array = ActorLit.parts_ms()
	HitchLog.set_lit_mark(ActorLit.mark_ms(), LightRt.mark_ms(), LightRt.mark_n, parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10])
	HitchLog.set_lit_peak(ActorLit.max_ms(), ActorLit.max_who())
	HitchLog.set_submit_ms(float(now - host._pre_us) / 1000.0)
	HitchLog.set_idle_ms(DungeonBoot.floor_ms(), TorchBill.torch_ms(), HpBar.bar_ms())
	_stamp_draw(host)
	_stamp_render(host)
	host._post_us = now
	HitchLog.set_edge_post(now)

static func _arm_render(host: Node) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.root == null:
		return
	var rid: RID = tree.root.get_viewport_rid()
	if rid == host._measure_rid:
		return
	if host._measure_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(host._measure_rid, false)
	host._measure_rid = rid
	if rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(rid, true)

static func _stamp_render(host: Node) -> void:
	if not host._measure_rid.is_valid():
		HitchLog.set_render_ms(-1.0, -1.0)
		return
	var cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(host._measure_rid) * 1000.0
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(host._measure_rid) * 1000.0
	HitchLog.set_render_ms(cpu_ms, gpu_ms)

static func _stamp_draw(host: Node) -> void:
	var vp: Viewport = host.get_viewport()
	if vp == null:
		HitchLog.set_draw_split(-1, -1, -1, -1, -1, -1, -1, -1, -1)
		return
	var rid: RID = vp.get_viewport_rid()
	HitchLog.set_draw_split(
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		_draw_info(host, rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	)

static func _draw_info(host: Node, rid: RID, kind: RenderingServer.ViewportRenderInfoType, info: RenderingServer.ViewportRenderInfo) -> int:
	return int(RenderingServer.viewport_get_render_info(rid, kind, info))
