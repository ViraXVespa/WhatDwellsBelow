extends Object

## Split from hub_bench.gd: _finish, _faces_done, _hub_up....

const HitchLog := preload("res://scripts/debug/hitch_log.gd")

static func _finish(host: Node, extra: String) -> void:
	if host._done:
		return
	host._done = true
	if App.playtest != null:
		App.playtest.ai_on = false
		App.playtest.move = Vector2.ZERO
		App.playtest.attack = false
	if host._saved_zoom >= 0.0:
		App.set_zoom(host._saved_zoom)
	var missing: PackedStringArray = PackedStringArray()
	if extra != "":
		missing.append(extra)
	if not host._to_walk:
		missing.append("idle_to_walk")
	if not host._to_idle:
		missing.append("walk_to_idle")
	for face_name: String in host._face_names:
		if not bool(host._faces.get(face_name, false)):
			missing.append("face_" + face_name)
	for need: String in host._need:
		if not bool(host._got.get(need, false)):
			missing.append(need)
	var ok: bool = missing.is_empty()
	var miss: String = "-" if ok else ",".join(missing)
	host._hb("HB: sec=%.1f hitches=%d frames=%d slow=%d pause_slow=%d fps_pct=%.1f worst=%.1f %s path=%s" % [host._clock, HitchLog.hitch_n, HitchLog.frame_n, HitchLog.slow_n, HitchLog.pause_slow_n, HitchLog.fps_pct(), HitchLog.worst_ms, HitchLog.present_text(), HitchLog.file_path])
	host._hb("HB: missing=%s" % miss)
	host._hb("HB: ok=%d" % (1 if ok else 0))
	HitchLog.bench_done(host._clock, ok, miss)
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.quit(0 if ok else 1)

static func _faces_done(host: Node) -> bool:
	if not host._to_walk or not host._to_idle:
		return false
	for face_name: String in host._face_names:
		if not bool(host._faces.get(face_name, false)):
			return false
	for need: String in host._need:
		if not bool(host._got.get(need, false)):
			return false
	return true

static func _hub_up(host: Node) -> bool:
	var loader_v: Variant = App.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return false
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == "Camp":
		return true
	return str(scene.scene_file_path).find("camp") >= 0

static func _sample(host: Node, actor: Node3D) -> void:
	var loco: int = int(actor.get("loc_state"))
	var moving: bool = loco == 1 or loco == 2
	if moving and not host._was_moving:
		host._to_walk = true
	if (not moving) and host._was_moving:
		host._to_idle = true
	host._was_moving = moving
	if loco == 2:
		host._faces[str(actor.get("facing_key"))] = true
