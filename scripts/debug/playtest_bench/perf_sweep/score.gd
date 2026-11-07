extends Object

## Split from perf_sweep.gd: _note_place, _open_seg, _close_seg....

const HitchLog := preload("res://scripts/debug/hitch_log.gd")

static func _note_place(host: Node, delta: float) -> void:
	var place: String = _scoring_place(host)
	if place == "":
		# The sample for this frame already ran. Later loader frames stay untagged.
		HitchLog.set_seg("")
		return
	if place == host._seg_place:
		host._play += delta
		HitchLog.set_play_s(host._play)
		HitchLog.set_score_where(place)
		return
	# This frame was already sampled under the previous place (or as a bar
	# frame). Close that stretch before the next sample uses the new place.
	if host._seg_place != "":
		_close_seg(host)
	host._seg_place = place
	host._seg_name = _open_seg(host, place)
	host._play = 0.0
	HitchLog.set_score_where(place)
	HitchLog.set_play_s(0.0)
	HitchLog.set_seg(host._seg_name)

static func _open_seg(host: Node, place: String) -> String:
	if place == "dungeon":
		host._dung_i += 1
		return "dungeon%d" % host._dung_i
	host._hub_i += 1
	return "hub%d" % host._hub_i

static func _close_seg(host: Node) -> void:
	var frames: int = HitchLog.frame_n - host._base_frames
	var slow: int = HitchLog.slow_n - host._base_slow
	if frames < 0:
		frames = 0
	if slow < 0:
		slow = 0
	host._hb("HB: seg=%s frames=%d slow=%d fps_pct=%.1f" % [host._seg_name, frames, slow, _pct(host, frames, slow)])
	host._base_frames = HitchLog.frame_n
	host._base_slow = HitchLog.slow_n

static func _finish(host: Node, extra: String) -> void:
	if host._done:
		return
	host._done = true
	if host._measure_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(host._measure_rid, false)
		host._measure_rid = RID()
	if App.playtest != null:
		App.playtest.ai_on = false
		App.playtest.move = Vector2.ZERO
		App.playtest.attack = false
	var hub: Node = App.get_node_or_null("HubBench")
	if hub != null:
		var zoom: float = float(hub.get("_saved_zoom"))
		if zoom >= 0.0:
			App.set_zoom(zoom)
	if host._seg_place != "":
		_close_seg(host)
		host._seg_place = ""
	var missing: PackedStringArray = PackedStringArray()
	if extra != "":
		missing.append(extra)
	if host._hub_done < 2:
		missing.append("hub")
	if host._dung_i < 2:
		missing.append("dungeon")
	if not host._dispel_sent:
		missing.append("dispel")
	if HitchLog.frame_n <= 0:
		missing.append("frames")
	var ok: bool = missing.is_empty()
	var miss: String = "-" if ok else ",".join(missing)
	var sec: float = _wall_s(host)
	host._hb("HB: seg=total frames=%d slow=%d fps_pct=%.1f" % [HitchLog.frame_n, HitchLog.slow_n, HitchLog.fps_pct()])
	host._hb("HB: sec=%.1f hitches=%d frames=%d slow=%d pause_slow=%d fps_pct=%.1f worst=%.1f %s path=%s" % [sec, HitchLog.hitch_n, HitchLog.frame_n, HitchLog.slow_n, HitchLog.pause_slow_n, HitchLog.fps_pct(), HitchLog.worst_ms, HitchLog.present_text(), HitchLog.file_path])
	host._hb("HB: missing=%s" % miss)
	host._hb("HB: ok=%d" % (1 if ok else 0))
	HitchLog.bench_done(sec, ok, miss)
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.quit(0 if ok else 1)

static func _scoring_place(host: Node) -> String:
	if _scene_up(host, "Dungeon", "dungeon.tscn"):
		return "dungeon"
	if _scene_up(host, "Camp", "camp"):
		return "hub"
	return ""

static func _scene_up(host: Node, scene_name: String, path_frag: String) -> bool:
	if _loader_up(host):
		return false
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == scene_name:
		return true
	return str(scene.scene_file_path).find(path_frag) >= 0

static func _camp_scene(host: Node) -> bool:
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == "Camp":
		return true
	return str(scene.scene_file_path).find("camp") >= 0

static func _loader_up(_host: Node) -> bool:
	var loader_v: Variant = App.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return true
	return false

static func _live(_host: Node) -> bool:
	return App.playtest != null and bool(App.playtest.get("live_running"))

static func _recap_open(_host: Node) -> bool:
	var recap_v: Variant = App.get("recap")
	return recap_v is Node and bool((recap_v as Node).get("open"))

static func _wall_s(host: Node) -> float:
	return float(Time.get_ticks_msec() - host._wall0) / 1000.0

static func _pct(_host: Node, frames: int, slow: int) -> float:
	if frames <= 0:
		return 100.0
	return snappedf(100.0 * float(frames - slow) / float(frames), 0.1)
