extends Object

## Opt-in human decide rows. Off unless --wdb-pt-human-log is passed.

const CliArgs := preload("res://scripts/app/cli_args.gd")
const Goals := preload("res://scripts/debug/playtest_goals.gd")
const Db := preload("res://scripts/debug/playtest_db.gd")
const Policy := preload("res://scripts/debug/playtest_ai/ai_policy.gd")
const LogUtil := preload("res://scripts/debug/playtest_log/log_util.gd")

const STEP := 0.5

static func tick(pt: PlayHost, delta: float) -> void:
	if not _on(pt):
		return
	if bool(pt.get("live_running")) or bool(pt.get("smoke_mode")):
		return
	if not App.in_dungeon:
		return
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return
	var p: Node = tree.get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	var clock: float = float(pt.get_meta("human_log_t", 0.0)) + delta
	pt.set_meta("human_log_t", clock)
	var acc: float = float(pt.get_meta("human_log_acc", 0.0)) + delta
	if acc < STEP:
		pt.set_meta("human_log_acc", acc)
		return
	pt.set_meta("human_log_acc", 0.0)
	var goal: String = _infer(pt, p)
	if goal == "":
		return
	if str(pt.get_meta("human_log_goal", "")) == goal:
		return
	pt.set_meta("human_log_goal", goal)
	Db.append_decisions("human", [_row(pt, p, goal, clock)], "")

static func _on(pt: PlayHost) -> bool:
	if pt.has_meta("human_log_on"):
		return bool(pt.get_meta("human_log_on"))
	var on: bool = CliArgs.has("--wdb-pt-human-log")
	pt.set_meta("human_log_on", on)
	return on

static func _speed(p: Node) -> float:
	if p is CharacterBody3D:
		var body: CharacterBody3D = p
		return Vector2(body.velocity.x, body.velocity.z).length()
	return 0.0

static func _infer(pt: PlayHost, p: Node) -> String:
	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		return "gather"
	var spd: float = _speed(p)
	var foe: Node = Goals.nearest_foe(pt, p)
	if foe != null and is_instance_valid(foe) and pt._dist(p, foe) <= 3.2 and spd < 2.0:
		return "threat"
	var gather: Node = pt._best_gather(p)
	if gather != null and is_instance_valid(gather) and pt._dist(p, gather) <= 2.4:
		return "gather"
	var clerk: Node = pt._best_clerk(p)
	if clerk != null and is_instance_valid(clerk) and pt._dist(p, clerk) <= 2.4:
		return "clerk"
	var stairs: Node = pt._reachable_kind(p, "stairs")
	if stairs != null and is_instance_valid(stairs) and pt._dist(p, stairs) <= 2.4:
		return "door"
	if spd > 0.35:
		return "wander"
	return ""

static func _row(pt: PlayHost, p: Node, goal: String, clock: float) -> Dictionary:
	var dist: Vector3 = Policy.human_dists(pt, p)
	var hp: float = 1.0
	if p.get("hp") != null and p.get("max_hp") != null:
		hp = float(p.hp) / maxf(1.0, float(p.max_hp))
	var ex: int = 0
	if App.extracted:
		ex = 1
	var cargo: int = int(App.gold)
	if App.get("ore") != null:
		cargo += int(App.ore)
	if App.get("wood") != null:
		cargo += int(App.wood)
	return {
		"ev": "decide",
		"t": clock,
		"goal": goal,
		"source": "human",
		"threat_d": dist.x,
		"gather_d": dist.y,
		"clerk_d": dist.z,
		"hp": hp,
		"ex": ex,
		"fl": int(App.floor_n),
		"cargo": cargo,
		"cell": LogUtil._xy(pt, p),
	}
