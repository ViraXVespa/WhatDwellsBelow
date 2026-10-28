extends Object

const U := preload("res://scripts/debug/playtest_ai/ai_util.gd")
const G := preload("res://scripts/debug/playtest_goals.gd")
const L := preload("res://scripts/debug/playtest_log.gd")
const A := preload("res://scripts/debug/playtest_ai/ai_act.gd")
const CLOSE := 2.4
const Human := preload("res://scripts/debug/playtest_ai/ai_human.gd")

static func use_prop(pt: Node, p: Node, dest: Node, _reach: float = 1.18) -> void:
	if dest == null or not is_instance_valid(dest):
		pt.move = Vector2.ZERO
		pt.path_goal = null
		return
	var d: float = pt._dist(p, dest)
	pt.aim = pt._xz_to(p, dest)
	pt.path_goal = dest
	if d < 1.18:
		pt.path.clear()
		pt.path_i = 0
		pt.move = Vector2.ZERO
		pt.interact = true
		pt.just["interact"] = true
		return
	if d < CLOSE:
		pt.path.clear()
		pt.path_i = 0
		pt.move = pt._steer(p, pt._xz_to(p, dest))
		return
	if U.spinning(pt):
		pt.path.clear()
		pt.path_i = 0
		pt.move = pt._any_open(p)
		return
	pt._follow_goal(p, dest)

static func _wants_clerk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or U._banned(pt, n):
		return false
	if (n.get("used") == true):
		return false
	var k: String = str(n.get("kind"))
	if k != "extract_gate" and k.find("clerk") < 0 and k != "patty" and k != "receptionist":
		return false
	if k.find("gather") >= 0:
		return int(pt._gather_cargo()) > 0
	return int(App.gold) > 0 or int(pt._gather_cargo()) > 0 or int(pt._misc_cargo()) > 0

static func _is_junk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return true
	var k: String = str(n.get("kind"))
	if k.find("crystal") >= 0:
		return false
	if U._banned(pt, n):
		return true
	if n.get("used") == true:
		return true
	if (k == "mine" or k == "wood") and not U.tool_ok(n):
		return true
	if (k == "mine" or k == "wood") and int(n.get("hits")) <= 0:
		return true
	return false

static func _usable_local(pt: Node, p: Node, lim: float) -> Node:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	var guard: int = 0
	while guard < 8:
		guard += 1
		var n: Node = U._near_prop(pt, p, lim)
		if n == null or not is_instance_valid(n):
			return null
		if _is_junk(pt, n) or not U.can_use(pt, n):
			U._ban(pt, n)
			_fac._mark_pad(pt, n, 1)
			continue
		return n
	return null

static func _mail_if_close(pt: Node, p: Node, clerk: Node) -> bool:
	if clerk == null or not is_instance_valid(clerk) or not _wants_clerk(pt, clerk):
		return false
	if pt._dist(p, clerk) > 1.6:
		return false
	G.mail_at(pt, clerk)
	_done_with_clerk(pt, clerk)
	L.decide(pt, p, "clerk", "mailed", L.target(clerk))
	pt.move = Vector2.ZERO
	pt.interact = true
	pt.just["interact"] = true
	return true

static func _leave_crystal(pt: Node, p: Node, crystal: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	pt.set_meta("flee_c", true)
	pt.set_meta("flee_t", 6.0)
	pt.set_meta("wander_hold", 2.4)
	_fac._mark_pad(pt, crystal, 10)
	var flee_c: Vector2 = G.away_open(pt, p, crystal)
	if flee_c == Vector2.ZERO:
		flee_c = pt._any_open(p)
	L.decide(pt, p, "wander", "leave_crystal")
	pt.path.clear()
	pt.path_goal = null
	pt.move = flee_c
	pt.wander_dir = flee_c
	pt.aim = flee_c

static func _engage(pt: Node, p: Node, foe: Node, why: String) -> void:
	U.stop_gather(p)
	U.note_threat(pt, p, foe)
	_clear_lock(pt)
	L.decide(pt, p, "fight", why, L.target(foe))
	var d: float = pt._dist(p, foe)
	if Human.reacting(pt, foe, d):
		pt.attack = false
		pt.aim = pt._xz_to(p, foe)
		return
	if pt._is_boss(foe):
		A.approach_boss(pt, p, foe)
	else:
		A.fight(pt, p, foe)
	Human.dodge(pt, p, foe, d)
	Human.blur_aim(pt, d)

static func _done_with_clerk(pt: Node, n: Node) -> void:
	var _fac = load("res://scripts/debug/playtest_ai.gd")
	if n == null or not is_instance_valid(n):
		return
	U._ban(pt, n)
	_fac._mark_pad(pt, n, 2)
	_clear_lock(pt)
	pt.path.clear()
	pt.path_goal = null

static func _clear_lock(pt: Node) -> void:
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)

static func campaign_depth(pt: Node, p: Node, delta: float) -> bool:
	if str(pt.slot) != "campaign":
		return false
	var goal: Node = _living_boss(pt, p)
	if goal == null:
		goal = _floor_stairs(pt)
	if goal == null:
		return false
	var slip: float = U._meta_f(pt, "campaign_slip", 0.0)
	if slip <= 0.0 and _tight(pt, p, delta):
		slip = 1.6
		pt.set_meta("campaign_hold", 0.0)
		pt.set_meta("campaign_side", _slip_side(pt, p, goal))
	if slip > 0.0:
		pt.set_meta("campaign_slip", maxf(0.0, slip - delta))
		pt.path.clear()
		pt.path_goal = null
		var side: Vector2 = _slip_side(pt, p, goal)
		if pt.has_meta("campaign_side") and pt.get_meta("campaign_side") is Vector2:
			side = pt.get_meta("campaign_side")
		pt.move = pt._steer(p, side)
		pt.dash = true
		pt.just["dash"] = true
		L.decide(pt, p, "wander", "campaign_slip", L.target(goal))
		return true
	var boss: Node = _living_boss(pt, p)
	if boss != null:
		var dist: float = pt._dist(p, boss)
		L.decide(pt, p, "hunt", "campaign_boss", L.target(boss))
		if dist <= 28.0:
			A.approach_boss(pt, p, boss)
		else:
			pt._follow_goal(p, boss)
			pt.aim = pt._xz_to(p, boss)
		return true
	var stairs: Node = goal
	if bool(stairs.get("locked")):
		L.decide(pt, p, "door", "campaign_boss", L.target(stairs))
		pt._follow_goal(p, stairs)
		pt.aim = pt._xz_to(p, stairs)
		return true
	if U._banned(pt, stairs):
		return false
	U._lock(pt, stairs, 4.0)
	L.decide(pt, p, "extract_stairs", "campaign_stairs", L.target(stairs))
	use_prop(pt, p, stairs)
	return true

static func _tight(pt: Node, p: Node, delta: float) -> bool:
	var here: Vector2i = pt._cell_of_node(p)
	var ax: int = here.x
	var ay: int = here.y
	if pt.has_meta("campaign_ax"):
		ax = int(pt.get_meta("campaign_ax"))
		ay = int(pt.get_meta("campaign_ay"))
	if absi(here.x - ax) + absi(here.y - ay) > 2:
		pt.set_meta("campaign_ax", here.x)
		pt.set_meta("campaign_ay", here.y)
		pt.set_meta("campaign_hold", 0.0)
		return false
	var hold: float = U._meta_f(pt, "campaign_hold", 0.0) + delta
	pt.set_meta("campaign_hold", hold)
	return hold > 2.0

static func _slip_side(pt: Node, p: Node, goal: Node) -> Vector2:
	var to_goal: Vector2 = pt._xz_to(p, goal)
	var side: Vector2 = Vector2(-to_goal.y, to_goal.x)
	if side.length_squared() < 0.0001:
		return pt._any_open(p)
	side = side.normalized()
	if not pt._dir_open(p, side):
		side = -side
	if not pt._dir_open(p, side):
		if to_goal.length_squared() > 0.0001:
			return -to_goal.normalized()
		return pt._any_open(p)
	return side

static func _living_boss(pt: Node, p: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = 100000.0
	for n: Node in tree.get_nodes_in_group("boss"):
		if not U.alive_enemy(n):
			continue
		var dist: float = pt._dist(p, n)
		if best == null or dist < best_d:
			best = n
			best_d = dist
	return best

static func _floor_stairs(pt: Node) -> Node:
	var dungeon: Node = pt._dungeon()
	if dungeon == null:
		return null
	var stairs: Variant = dungeon.get("stairs")
	if stairs is Node and is_instance_valid(stairs):
		return stairs as Node
	return null
