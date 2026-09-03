extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Util := preload("res://scripts/debug/playtest_ai_util.gd")
const Act := preload("res://scripts/debug/playtest_ai_act.gd")
const Goals := preload("res://scripts/debug/playtest_goals.gd")
const NEAR := 22.0
const SEE := 28.0
const CLOSE := 2.4
const START := 24.0
const GATHER := 9.0


static func weapon_range() -> float:
	return Util.weapon_range()


static func is_boss(n: Node) -> bool:
	return Util.is_boss(n)


static func alive_enemy(n: Node) -> bool:
	return Util.alive_enemy(n)


static func notice_range(pt: Node) -> float:
	return Util.notice_range(pt)


static func try_staff_special(pt: Node, d: float, los: bool) -> void:
	Util.try_staff_special(pt, d, los)


static func fight(pt: Node, p: Node, enemy: Node) -> void:
	Act.fight(pt, p, enemy)


static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	Act.approach_boss(pt, p, boss)


static func wander(pt: Node, p: Node, delta: float) -> void:
	Util.wander(pt, p, delta)


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
	if Util.spinning(pt):
		pt.path.clear()
		pt.path_i = 0
		pt.move = pt._any_open(p)
		return
	pt._follow_goal(p, dest)


static func _mark_pad(pt: Node, n: Node, w: int = 1) -> void:
	if n == null or not is_instance_valid(n):
		return
	var c: Vector2i = pt._cell_of_node(n)
	var m: Dictionary = Util._seen(pt)
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			var k: Vector2i = c + Vector2i(x, y)
			m[k] = int(m.get(k, 0)) + w
	pt.set_meta("seen_map", m)


static func _is_junk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return true
	var k: String = str(n.get("kind"))
	if k.find("crystal") >= 0:
		return false
	if Util._banned(pt, n):
		return true
	if n.get("used") == true:
		return true
	if (k == "mine" or k == "wood") and not Util.tool_ok(n):
		return true
	if (k == "mine" or k == "wood") and int(n.get("hits")) <= 0:
		return true
	return false


static func _usable_local(pt: Node, p: Node, lim: float) -> Node:
	var guard: int = 0
	while guard < 8:
		guard += 1
		var n: Node = Util._near_prop(pt, p, lim)
		if n == null or not is_instance_valid(n):
			return null
		if _is_junk(pt, n) or not Util.can_use(pt, n):
			Util._ban(pt, n)
			_mark_pad(pt, n, 1)
			continue
		return n
	return null


static func _wants_clerk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or Util._banned(pt, n):
		return false
	if bool(n.get("used")):
		return false
	var k: String = str(n.get("kind"))
	if k != "extract_gate" and k.find("clerk") < 0 and k != "patty" and k != "receptionist":
		return false
	if k.find("gather") >= 0:
		return int(pt._gather_cargo()) > 0
	return int(App.gold) > 0 or int(pt._gather_cargo()) > 0 or int(pt._misc_cargo()) > 0


static func _done_with_clerk(pt: Node, n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	Util._ban(pt, n)
	_mark_pad(pt, n, 2)
	_clear_lock(pt)
	pt.path.clear()
	pt.path_goal = null


static func _clear_lock(pt: Node) -> void:
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)


static func _mail_if_close(pt: Node, p: Node, clerk: Node) -> bool:
	if clerk == null or not is_instance_valid(clerk) or not _wants_clerk(pt, clerk):
		return false
	if pt._dist(p, clerk) > 1.6:
		return false
	Goals.mail_at(pt, clerk)
	_done_with_clerk(pt, clerk)
	PlaytestLog.decide(pt, p, "clerk", "mailed", PlaytestLog.target(clerk))
	pt.move = Vector2.ZERO
	pt.interact = true
	pt.just["interact"] = true
	return true


static func _engage(pt: Node, p: Node, foe: Node, why: String) -> void:
	Util.stop_gather(p)
	Util.note_threat(pt, p, foe)
	_clear_lock(pt)
	PlaytestLog.decide(pt, p, "fight", why, PlaytestLog.target(foe))
	if pt._is_boss(foe):
		Act.approach_boss(pt, p, foe)
	else:
		Act.fight(pt, p, foe)


static func _leave_crystal(pt: Node, p: Node, crystal: Node) -> void:
	pt.set_meta("flee_c", true)
	pt.set_meta("flee_t", 6.0)
	pt.set_meta("wander_hold", 2.4)
	_mark_pad(pt, crystal, 10)
	var flee_c: Vector2 = Goals.away_open(pt, p, crystal)
	if flee_c == Vector2.ZERO:
		flee_c = pt._any_open(p)
	PlaytestLog.decide(pt, p, "wander", "leave_crystal")
	pt.path.clear()
	pt.path_goal = null
	pt.move = flee_c
	pt.wander_dir = flee_c
	pt.aim = flee_c


static func think(pt: Node, p: Node, delta: float) -> void:
	Util.tick_motion(pt, p, delta)
	pt.set_meta("flee_t", maxf(0.0, Util._meta_f(pt, "flee_t", 0.0) - delta))
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	var foe: Node = Goals.nearest_foe(pt, p)
	Util.note_threat(pt, p, foe)
	if foe and is_instance_valid(foe):
		_engage(pt, p, foe, "threat")
		return
	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		PlaytestLog.decide(pt, p, "gathering", "busy", PlaytestLog.target(gathering))
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	if Util.should_unstick(pt, p):
		Util.do_unstick(pt)
	var hold: Node = Util._locked(pt, delta)
	if hold and is_instance_valid(hold):
		if Util.is_foe_lock(hold):
			if pt._alive_enemy(hold):
				_engage(pt, p, hold, "hold_foe")
				return
			_clear_lock(pt)
			hold = null
		elif _mail_if_close(pt, p, hold):
			return
		elif (str(hold.get("kind")) == "extract_gate" or str(hold.get("kind")).find("clerk") >= 0) and not _wants_clerk(pt, hold):
			_done_with_clerk(pt, hold)
			hold = null
		elif _is_junk(pt, hold) or not Util.can_use(pt, hold):
			_clear_lock(pt)
			hold = null
		elif Util.is_loot_kind(str(hold.get("kind"))) and pt._dist(p, hold) > GATHER + 2.0:
			_clear_lock(pt)
			hold = null
	if hold and is_instance_valid(hold):
		if Util.spinning(pt) and Util.is_loot_kind(str(hold.get("kind"))):
			Util._ban(pt, hold)
			_clear_lock(pt)
		else:
			PlaytestLog.decide(pt, p, "hold", "lock", PlaytestLog.target(hold))
			use_prop(pt, p, hold)
			_mail_if_close(pt, p, hold)
			return
	var hunt: Node = pt._nearest_hunt(p)
	if hunt and is_instance_valid(hunt) and pt._dist(p, hunt) <= NEAR:
		Util.note_threat(pt, p, hunt)
		Util._lock(pt, hunt, 2.2)
		PlaytestLog.decide(pt, p, "hunt", "hunt", PlaytestLog.target(hunt))
		if pt._is_boss(hunt):
			Act.approach_boss(pt, p, hunt)
		else:
			if Util.spinning(pt):
				pt.path.clear()
				pt.move = pt._any_open(p)
			else:
				pt._follow_goal(p, hunt)
			pt.aim = pt._xz_to(p, hunt)
		return
	var clerk: Node = pt._best_clerk(p)
	if clerk and is_instance_valid(clerk) and _wants_clerk(pt, clerk):
		if _mail_if_close(pt, p, clerk):
			return
		Util._lock(pt, clerk, 4.0)
		PlaytestLog.decide(pt, p, "clerk", "cargo_near", PlaytestLog.target(clerk))
		use_prop(pt, p, clerk)
		_mail_if_close(pt, p, clerk)
		return
	if Util.really_extracted():
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs and is_instance_valid(stairs) and not Util._banned(pt, stairs):
			Util._lock(pt, stairs, 4.0)
			PlaytestLog.decide(pt, p, "extract_stairs", "extracted", PlaytestLog.target(stairs))
			use_prop(pt, p, stairs)
			return
	var chest: Node = pt._best_chest(p)
	if chest and is_instance_valid(chest) and Util.can_use(pt, chest) and not _is_junk(pt, chest) and pt._dist(p, chest) <= GATHER:
		Util._lock(pt, chest, 4.0)
		PlaytestLog.decide(pt, p, "gather", "chest", PlaytestLog.target(chest))
		use_prop(pt, p, chest)
		return
	var node: Node = pt._best_gather(p)
	if node and is_instance_valid(node) and Util.can_use(pt, node) and not _is_junk(pt, node) and pt._dist(p, node) <= GATHER:
		Util._lock(pt, node, 6.0)
		PlaytestLog.decide(pt, p, "gather", "path_prop", PlaytestLog.target(node))
		use_prop(pt, p, node)
		return
	var local: Node = _usable_local(pt, p, GATHER)
	if local:
		var lk: String = str(local.get("kind"))
		if lk == "mine" or lk == "wood" or Util.is_loot_kind(lk) or lk.find("chest") >= 0:
			Util._lock(pt, local, 6.0)
			PlaytestLog.decide(pt, p, "gather", "local_prop", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if _wants_clerk(pt, local):
			if _mail_if_close(pt, p, local):
				return
			Util._lock(pt, local, 4.0)
			PlaytestLog.decide(pt, p, "clerk", "cargo_local", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if lk.find("door") >= 0 or lk.find("stairs") >= 0:
			Util._lock(pt, local, 2.5)
			PlaytestLog.decide(pt, p, "door", "local_exit", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
	var fleeing: bool = Util._meta_f(pt, "flee_t", 0.0) > 0.0
	if not fleeing:
		var crystal: Node = Goals.closest_kind(pt, p, "crystal", 2.6)
		if crystal:
			_leave_crystal(pt, p, crystal)
			return
		if pt.has_meta("flee_c"):
			pt.remove_meta("flee_c")
	var why: String = "explore"
	if Util.really_extracted():
		why = "no_stairs"
	PlaytestLog.decide(pt, p, "wander", why)
	Util.wander(pt, p, delta)
