extends Object

## Playtester readiness gate, time-scale rule and decision-cost counters (state lives on the playtest node: gate_t, gate_why, perf, act_t).
## Rule: the AI only acts when the dungeon is ready; every wait runs at time_scale 1.0 so load/timing numbers are never skewed.

const Goals := preload("res://scripts/debug/playtest_goals.gd")
const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const CliArgs := preload("res://scripts/debug/cli_args.gd")
const FAST_FLAG := "--wdb-pt-fast"  # the only way to get a scale above 1.0
const GATE_MAX := 15.0  # s on a soft gate (paused / transition / loading) before acting anyway, so a stuck overlay cannot stall a run
const HARD_MAX := 90.0  # s on a hard gate (no dungeon / no player) before the run is ended as "stalled"
const GATE_SOFT := ["paused", "transition", "loading", "scene_not_ready"]

static func reset(pt: Node) -> void:
	pt.perf = {"think_us": 0, "think_n": 0, "think_max_us": 0, "phys_us": 0, "phys_n": 0, "gate_s": 0.0, "gate_over": 0, "scale": 1.0}
	pt.gate_t = 0.0
	pt.gate_why = ""

static func note(pt: Node, key: String, us: int) -> void:
	var perf: Dictionary = pt.perf
	perf[key + "_us"] = int(perf[key + "_us"]) + us
	perf[key + "_n"] = int(perf[key + "_n"]) + 1
	if key == "think":
		perf["think_max_us"] = maxi(int(perf["think_max_us"]), us)

static func report(pt: Node) -> Dictionary:
	# think = AI think + journal per decision; phys = whole playtest _physics_process per tick; time_scale = scale the AI ran at.
	var perf: Dictionary = pt.perf
	var tn: int = maxi(1, int(perf.get("think_n", 0)))
	var pn: int = maxi(1, int(perf.get("phys_n", 0)))
	return {
		"think_n": int(perf.get("think_n", 0)),
		"think_ms": snappedf(float(perf.get("think_us", 0)) / tn / 1000.0, 0.001),
		"think_max_ms": snappedf(float(perf.get("think_max_us", 0)) / 1000.0, 0.1),
		"phys_ms": snappedf(float(perf.get("phys_us", 0)) / pn / 1000.0, 0.001),
		"phys_n": int(perf.get("phys_n", 0)),
		"gate_s": snappedf(float(perf.get("gate_s", 0.0)), 0.001),
		"gate_over": int(perf.get("gate_over", 0)),
		"unstick_n": int(perf.get("unstick_n", 0)),
		"stuck_max": snappedf(float(perf.get("stuck_max", 0.0)), 0.1),
		"time_scale": float(perf.get("scale", 1.0)),
		"act_t": snappedf(pt.act_t, 0.1),
	}

static func acting_scale(pt: Node) -> float:
	# 1.0 unless --wdb-pt-fast (URL ?wdb-pt-fast) is given; then the job scale (default App.bal.playtest_scale), capped at 6.
	if pt.smoke_mode or not CliArgs.has(FAST_FLAG):
		return 1.0
	return clampf(float(pt.job.get("scale", App.bal.playtest_scale)), 1.0, 6.0)

static func set_scale(want: float) -> void:
	if not is_equal_approx(Engine.time_scale, want):
		Engine.time_scale = want

static func not_ready(pt: Node) -> String:
	if not App.in_dungeon:
		return "no_dungeon"
	var d: Node = Goals.dungeon(pt)
	if d == null:
		return "no_dungeon"
	if not d.is_node_ready():
		return "scene_not_ready"
	var pl: Node = pt.get_tree().get_first_node_in_group("player")
	if pl == null or not is_instance_valid(pl):
		return "no_player"
	if pt.get_tree().paused:
		return "paused"
	if (App.get("_menu_loading") == true):
		return "loading"
	var pr: Variant = App.get("present")
	if pr != null and (str(pr.get("_mode")) in ["enter", "enter_hold", "enter_fade", "wake"] or (pr.get("_enter_load") == true)):
		return "transition"
	return ""

static func hold(pt: Node, why: String, delta: float) -> bool:
	# True when the AI must not act this tick (input zeroed, scale 1.0). Soft gates fail open after GATE_MAX s.
	pt.ai_on = false
	pt.move = Vector2.ZERO
	pt.attack = false
	set_scale(1.0)
	if why != pt.gate_why:
		pt.gate_why = why
		pt.gate_t = 0.0
	pt.gate_t += delta
	pt.perf["gate_s"] = float(pt.perf["gate_s"]) + delta
	if pt.sim_t - pt.last_wait_t >= 2.0:
		pt.last_wait_t = pt.sim_t
		PlaytestLog.wait(pt, why)
	if why not in GATE_SOFT and pt.gate_t >= HARD_MAX:
		pt.stall_abort(why)
		return true
	if why in GATE_SOFT and pt.gate_t >= GATE_MAX:
		pt.perf["gate_over"] = int(pt.perf["gate_over"]) + 1
		pt.gate_t = 0.0
		return false
	return true
