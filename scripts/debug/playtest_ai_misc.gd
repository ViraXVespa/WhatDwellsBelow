extends Object

const U := preload("res://scripts/debug/playtest_ai_util.gd")
const G := preload("res://scripts/debug/playtest_goals.gd")
const L := preload("res://scripts/debug/playtest_log.gd")
const A := preload("res://scripts/debug/playtest_ai_act.gd")
const CLOSE := 2.4

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
	if bool(n.get("used")):
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
	if pt._is_boss(foe):
		A.approach_boss(pt, p, foe)
	else:
		A.fight(pt, p, foe)

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
