extends Object

## Split from perf_sweep.gd: _claim_hub, _enqueue, _tick_dungeon....

const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const Score := preload("res://scripts/debug/playtest_bench/perf_sweep/score.gd")

static func _claim_hub(host: Node, miss: String) -> bool:
	if host._done:
		return true
	if host._state != host.ST_HUB:
		return true
	if miss != "-":
		Score._finish(host, miss)
		return true
	host._hub_done += 1
	host._hb("HB: sweep hub=%d" % host._hub_done)
	if host._hub_done > 2:
		Score._finish(host, "hub")
		return true
	_enqueue(host)
	return true

static func _enqueue(host: Node) -> void:
	if App.playtest == null:
		Score._finish(host, "no_playtest")
		return
	# Physics reaches the job limit before the next idle frame, so the job
	# limit sits above the scored acting window. This node plays the dispel
	# exit when act_t hits _act_limit. start_next takes App.enter_dungeon
	# while this flag is set, so the cover runs before the scene change.
	HitchLog.arm_harness()
	var job_limit: float = host._act_limit + 60.0
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
	host._visit_saw = false
	_set_state(host, host.ST_DUNG)
	host._hb("HB: dungeon enter act=%.0f" % host._act_limit)

static func _tick_dungeon(host: Node) -> void:
	if Score._scoring_place(host) == "dungeon":
		host._visit_saw = true
		HitchLog.set_phase("play")
	else:
		HitchLog.set_phase("wait")
	if not host._visit_saw and host._state_t >= host.LOAD_SEC:
		Score._finish(host, "stall")
		return
	if not host._visit_saw or App.playtest == null:
		return
	var acted: float = float(App.playtest.get("act_t"))
	if acted >= host._act_limit:
		if host._hub_done >= 2:
			Score._finish(host, "")
		elif not host._dispel_sent:
			_begin_dispel(host)
		return
	if not bool(App.playtest.get("live_running")):
		Score._finish(host, "ended")

static func _tick_dispel(host: Node) -> void:
	HitchLog.set_phase("dispel")
	if Score._recap_open(host) or Score._live(host):
		if host._state_t >= 30.0:
			Score._finish(host, "dispel")
		return
	if not host._camp_sent:
		host._camp_sent = true
		host._hb("HB: camp")
		_wake_camp(host)
	_set_state(host, host.ST_BACK)

static func _tick_back(host: Node) -> void:
	HitchLog.set_phase("wait")
	if Score._camp_scene(host) and not host._hub_restarted:
		host._hub_restarted = true
		var hub: Node = App.get_node_or_null("HubBench")
		if hub != null and hub.has_method("restart_walk"):
			hub.restart_walk()
		_set_state(host, host.ST_HUB)
		host._hb("HB: hub2")
		return
	if host._state_t >= host.LOAD_SEC:
		Score._finish(host, "stall")

static func _begin_dispel(host: Node) -> void:
	host._dispel_sent = true
	host._hb("HB: dispel")
	# end_run skips the exit clip while a playtest is live and jumps to the recap.
	# The player path plays that clip, then finish_end opens the recap.
	var p: Node = _player(host)
	if p != null and p.has_method("play_exit") and not bool(p.get("exiting")):
		p.play_exit("dispel")
	else:
		App.finish_end("dispel")
	_set_state(host, host.ST_DISPEL)

static func _wake_camp(_host: Node) -> void:
	# Same handoff recap finish uses after a human dispel. consume_recap returns
	# before those lines, so the sweep runs them once the recap has closed.
	App.wake_pending = true
	var present_v: Variant = App.get("present")
	if present_v is Node and (present_v as Node).has_method("cover_wake"):
		(present_v as Node).call("cover_wake")
	App.go_camp()

static func _player(host: Node) -> Node:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")

static func _set_state(host: Node, next_state: int) -> void:
	host._state = next_state
	host._state_t = 0.0
	host._wait_hb = 0.0
