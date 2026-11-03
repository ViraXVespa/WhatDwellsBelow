extends Node

## --wdb-perf-sweep: one process, no quit between states.
## Cold boot, hub walk, dungeon (seed from --wdb-seed, Great Axe, time scale 1),
## dispel when that acting timer ends, hub walk, dungeon walk, then quit.
## Dungeon entry is App.enter_dungeon (cover, paint wait, scene change).
## Dispel is the player's exit, then the recap camp handoff (wake cover, go_camp).
## Frames count while camp or the dungeon is showing and the loader bar is down.
## HB: seg=<place><n> is that stretch. The last fps_pct line is the whole run.
## tree_ms splits into script_ms, queue_ms, and tail_ms. The sweep node stays at priority 0.
## script_ms further splits into bench_ms (hub bench _process), lit_ms (ActorLit),
## and sample_ms (LightRt.sample_xz, also counted inside lit_ms).

const FLAG := "--wdb-perf-sweep"
const CliArgs := preload("res://scripts/app/cli_args.gd")
const BU := preload("res://scripts/debug/playtest_bench/bench_util.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const ActorLit := preload("res://scripts/graphics/actor_lit.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const ST_HUB := 0
const ST_DUNG := 1
const ST_DISPEL := 2
const ST_BACK := 3

const HARD_SEC := 900.0
const LOAD_SEC := 240.0
## Last idle _process. The sweep node stays at the default priority. Moving that
## node later made tree_ms collapse into after_ms. This probe only brackets tree_ms.
const TAIL_PRIORITY := 1000000

static var _inst: Node = null

static func active() -> bool:
	return CliArgs.has(FLAG)

static func _vsync_off() -> void:
	BU.vsync_off()

static func _warm_user() -> bool:
	return BU.warm_user()

static func _hb(msg: String) -> void:
	BU.hb(msg)

static func start() -> void:
	_vsync_off()
	if _warm_user():
		_hb("HB: fresh=0")
		_hb("HB: missing=warm_user")
		_hb("HB: ok=0")
		App.get_tree().quit(1)
		return
	var mult: float = CliArgs.float_arg("--wdb-hitch-mult", 1.0)
	HitchLog.bench_reset(mult)
	HitchLog.set_score_where("hub")
	HitchLog.set_phase("wait")
	_hb("HB: fresh=1")
	App.character_type = "male"
	App.character_chosen = true
	var scr: GDScript = load("res://scripts/debug/playtest_bench/perf_sweep.gd") as GDScript
	var node: Node = scr.new() as Node
	node.name = "PerfSweep"
	App.add_child(node)
	var hub_scr: GDScript = load("res://scripts/debug/playtest_bench/hub_bench.gd") as GDScript
	if hub_scr != null:
		hub_scr.spawn()
	_hb("HB: sweep pt_sec=%.0f" % float(node.get("_act_limit")))
	App.call_deferred("play_from_menu")

static func claim_hub(_host: Node, miss: String) -> bool:
	if _inst == null or not is_instance_valid(_inst):
		return false
	return _inst._claim_hub(miss)

var _state: int = ST_HUB
var _act_limit: float = 30.0
var _done: bool = false
var _wall0: int = 0
var _state_t: float = 0.0
var _post_t: float = 0.0
var _wait_hb: float = 0.0
var _hub_done: int = 0
var _dispel_sent: bool = false
var _camp_sent: bool = false
var _hub_restarted: bool = false
var _visit_saw: bool = false
var _seg_place: String = ""
var _seg_name: String = ""
var _hub_i: int = 0
var _dung_i: int = 0
var _base_frames: int = 0
var _base_slow: int = 0
var _play: float = 0.0
var _proc_us: int = 0
var _pre_us: int = 0
var _post_us: int = 0
var _tree_ms: float = -1.0
var _script_ms: float = -1.0
var _queue_ms: float = -1.0
var _tail_ms: float = -1.0
var _tail: _TreeTail = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inst = self
	_act_limit = CliArgs.float_arg("--wdb-pt-sec", 30.0)
	_wall0 = Time.get_ticks_msec()
	if not RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	var tail: _TreeTail = _TreeTail.new()
	tail.name = "TreeTail"
	tail.process_mode = Node.PROCESS_MODE_ALWAYS
	tail.process_priority = TAIL_PRIORITY
	_tail = tail
	add_child(tail)
	_vsync_off()

func _on_pre_draw() -> void:
	var now: int = Time.get_ticks_usec()
	if _proc_us > 0:
		_tree_ms = float(now - _proc_us) / 1000.0
	_script_ms = -1.0
	_queue_ms = -1.0
	_tail_ms = -1.0
	if not _done and _tail != null and _proc_us > 0:
		var script_us: int = _tail.script_us
		if script_us >= _proc_us:
			_script_ms = float(script_us - _proc_us) / 1000.0
			var queue_us: int = _tail.queue_us
			if queue_us >= script_us:
				_queue_ms = float(queue_us - script_us) / 1000.0
				_tail_ms = float(now - queue_us) / 1000.0
			else:
				_tail_ms = float(now - script_us) / 1000.0
	_pre_us = now

func _on_post_draw() -> void:
	var now: int = Time.get_ticks_usec()
	HitchLog.set_tree_ms(_tree_ms)
	HitchLog.set_tree_split(_script_ms, _queue_ms, _tail_ms)
	HitchLog.set_lit_mark(ActorLit.mark_ms(), LightRt.mark_ms(), LightRt.mark_n)
	HitchLog.set_submit_ms(float(now - _pre_us) / 1000.0)
	_post_us = now

func _process(delta: float) -> void:
	if _done:
		ActorLit.mark_off()
		LightRt.mark_off()
		return
	var now: int = Time.get_ticks_usec()
	if _post_us > 0:
		var after_ms: float = float(now - _post_us) / 1000.0 - HitchLog.harness_in_after_ms()
		if after_ms < 0.0:
			after_ms = 0.0
		HitchLog.set_after_ms(after_ms)
	_proc_us = now
	HitchLog.set_bench_ms(-1.0)
	ActorLit.arm_mark()
	LightRt.arm_mark()
	_post_t += delta
	if _post_t >= 0.5:
		_post_t = 0.0
		HitchLog.flush_web()
	_state_t += delta
	_note_place(delta)
	if _wall_s() >= HARD_SEC:
		_finish("timeout")
		return
	if _state == ST_DUNG:
		_tick_dungeon()
	elif _state == ST_DISPEL:
		_tick_dispel()
	elif _state == ST_BACK:
		_tick_back()
	elif not _scoring_place():
		_wait_hb += delta
		if _wait_hb >= 2.0:
			_wait_hb = 0.0
			_hb("HB: wait")

func _claim_hub(miss: String) -> bool:
	if _done:
		return true
	if _state != ST_HUB:
		return true
	if miss != "-":
		_finish(miss)
		return true
	_hub_done += 1
	_hb("HB: sweep hub=%d" % _hub_done)
	if _hub_done > 2:
		_finish("hub")
		return true
	_enqueue()
	return true

func _enqueue() -> void:
	if App.playtest == null:
		_finish("no_playtest")
		return
	# Physics reaches the job limit before the next idle frame, so the job
	# limit sits above the scored acting window. This node plays the dispel
	# exit when act_t hits _act_limit. start_next takes App.enter_dungeon
	# while this flag is set, so the cover runs before the scene change.
	HitchLog.arm_harness()
	var job_limit: float = _act_limit + 60.0
	var job: Dictionary = {
		"save": "fresh",
		"weapon": "great_axe",
		"tool": "pickaxe",
		"gender": "male",
		"scale": 1.0,
		"limit": job_limit,
		"cfg": {},
	}
	App.playtest.enqueue(job)
	_visit_saw = false
	_set_state(ST_DUNG)
	_hb("HB: dungeon enter act=%.0f" % _act_limit)

func _tick_dungeon() -> void:
	if _scoring_place() == "dungeon":
		_visit_saw = true
		HitchLog.set_phase("play")
	else:
		HitchLog.set_phase("wait")
	if not _visit_saw and _state_t >= LOAD_SEC:
		_finish("stall")
		return
	if not _visit_saw or App.playtest == null:
		return
	var acted: float = float(App.playtest.get("act_t"))
	if acted >= _act_limit:
		if _hub_done >= 2:
			_finish("")
		elif not _dispel_sent:
			_begin_dispel()
		return
	if not bool(App.playtest.get("live_running")):
		_finish("ended")

func _tick_dispel() -> void:
	HitchLog.set_phase("dispel")
	if _recap_open() or _live():
		if _state_t >= 30.0:
			_finish("dispel")
		return
	if not _camp_sent:
		_camp_sent = true
		_hb("HB: camp")
		_wake_camp()
	_set_state(ST_BACK)

func _tick_back() -> void:
	HitchLog.set_phase("wait")
	if _camp_scene() and not _hub_restarted:
		_hub_restarted = true
		var hub: Node = App.get_node_or_null("HubBench")
		if hub != null and hub.has_method("restart_walk"):
			hub.restart_walk()
		_set_state(ST_HUB)
		_hb("HB: hub2")
		return
	if _state_t >= LOAD_SEC:
		_finish("stall")

func _begin_dispel() -> void:
	_dispel_sent = true
	_hb("HB: dispel")
	# end_run skips the exit clip while a playtest is live and jumps to the recap.
	# The player path plays that clip, then finish_end opens the recap.
	var p: Node = _player()
	if p != null and p.has_method("play_exit") and not bool(p.get("exiting")):
		p.play_exit("dispel")
	else:
		App.finish_end("dispel")
	_set_state(ST_DISPEL)

func _wake_camp() -> void:
	# Same handoff recap finish uses after a human dispel. consume_recap returns
	# before those lines, so the sweep runs them once the recap has closed.
	App.wake_pending = true
	var present_v: Variant = App.get("present")
	if present_v is Node and (present_v as Node).has_method("cover_wake"):
		(present_v as Node).call("cover_wake")
	App.go_camp()

func _player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")

func _set_state(next_state: int) -> void:
	_state = next_state
	_state_t = 0.0
	_wait_hb = 0.0

func _note_place(delta: float) -> void:
	var place: String = _scoring_place()
	if place == "":
		return
	if place == _seg_place:
		_play += delta
		HitchLog.set_play_s(_play)
		HitchLog.set_score_where(place)
		return
	# This frame was already sampled under the previous place (or as a bar
	# frame). Close that stretch before the next sample uses the new place.
	if _seg_place != "":
		_close_seg()
	_seg_place = place
	_seg_name = _open_seg(place)
	_play = 0.0
	HitchLog.set_score_where(place)
	HitchLog.set_play_s(0.0)

func _open_seg(place: String) -> String:
	if place == "dungeon":
		_dung_i += 1
		return "dungeon%d" % _dung_i
	_hub_i += 1
	return "hub%d" % _hub_i

func _close_seg() -> void:
	var frames: int = HitchLog.frame_n - _base_frames
	var slow: int = HitchLog.slow_n - _base_slow
	if frames < 0:
		frames = 0
	if slow < 0:
		slow = 0
	_hb("HB: seg=%s frames=%d slow=%d fps_pct=%.1f" % [_seg_name, frames, slow, _pct(frames, slow)])
	_base_frames = HitchLog.frame_n
	_base_slow = HitchLog.slow_n

func _finish(extra: String) -> void:
	if _done:
		return
	_done = true
	if App.playtest != null:
		App.playtest.ai_on = false
		App.playtest.move = Vector2.ZERO
		App.playtest.attack = false
	var hub: Node = App.get_node_or_null("HubBench")
	if hub != null:
		var zoom: float = float(hub.get("_saved_zoom"))
		if zoom >= 0.0:
			App.set_zoom(zoom)
	if _seg_place != "":
		_close_seg()
		_seg_place = ""
	var missing: PackedStringArray = PackedStringArray()
	if extra != "":
		missing.append(extra)
	if _hub_done < 2:
		missing.append("hub")
	if _dung_i < 2:
		missing.append("dungeon")
	if not _dispel_sent:
		missing.append("dispel")
	if HitchLog.frame_n <= 0:
		missing.append("frames")
	var ok: bool = missing.is_empty()
	var miss: String = "-" if ok else ",".join(missing)
	var sec: float = _wall_s()
	_hb("HB: seg=total frames=%d slow=%d fps_pct=%.1f" % [HitchLog.frame_n, HitchLog.slow_n, HitchLog.fps_pct()])
	_hb("HB: sec=%.1f hitches=%d frames=%d slow=%d pause_slow=%d fps_pct=%.1f worst=%.1f %s path=%s" % [sec, HitchLog.hitch_n, HitchLog.frame_n, HitchLog.slow_n, HitchLog.pause_slow_n, HitchLog.fps_pct(), HitchLog.worst_ms, HitchLog.present_text(), HitchLog.file_path])
	_hb("HB: missing=%s" % miss)
	_hb("HB: ok=%d" % (1 if ok else 0))
	HitchLog.bench_done(sec, ok, miss)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.quit(0 if ok else 1)

func _scoring_place() -> String:
	if _scene_up("Dungeon", "dungeon.tscn"):
		return "dungeon"
	if _scene_up("Camp", "camp"):
		return "hub"
	return ""

func _scene_up(scene_name: String, path_frag: String) -> bool:
	if _loader_up():
		return false
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == scene_name:
		return true
	return str(scene.scene_file_path).find(path_frag) >= 0

func _camp_scene() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	if str(scene.name) == "Camp":
		return true
	return str(scene.scene_file_path).find("camp") >= 0

func _loader_up() -> bool:
	var loader_v: Variant = App.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return true
	return false

func _live() -> bool:
	return App.playtest != null and bool(App.playtest.get("live_running"))

func _recap_open() -> bool:
	var recap_v: Variant = App.get("recap")
	return recap_v is Node and bool((recap_v as Node).get("open"))

func _wall_s() -> float:
	return float(Time.get_ticks_msec() - _wall0) / 1000.0

func _pct(frames: int, slow: int) -> float:
	if frames <= 0:
		return 100.0
	return snappedf(100.0 * float(frames - slow) / float(frames), 0.1)

## End of idle _process, then the deferred flush. pre_draw reads these against the sweep stamp.
class _TreeTail extends Node:
	var script_us: int = 0
	var queue_us: int = 0

	func _process(_delta: float) -> void:
		var sweep: Node = get_parent()
		if sweep == null or bool(sweep.get("_done")):
			return
		script_us = Time.get_ticks_usec()
		call_deferred("_stamp_queue")

	func _stamp_queue() -> void:
		queue_us = Time.get_ticks_usec()
