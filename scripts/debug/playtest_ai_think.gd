extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Util := preload("res://scripts/debug/playtest_ai_util.gd")
const Goals := preload("res://scripts/debug/playtest_goals.gd")
const NEAR := 22.0
const SEE := 28.0
const CLOSE := 2.4
const START := 24.0
const ROOM := 11.0


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
	pt._follow_goal(p, dest)


static func _usable_local(pt: Node, p: Node, lim: float) -> Node:
	var guard: int = 0
	while guard < 8:
		guard += 1
		var n: Node = Util._near_prop(pt, p, lim)
		if n == null or not is_instance_valid(n):
			return null
		if Util.is_junk(pt, n) or not Util.can_use(pt, n):
			Util._ban(pt, n)
			Util.mark_pad(pt, n)
			continue
		return n
	return null


static func _wants_clerk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or Util._banned(pt, n):
		return false
	var k: String = str(n.get("kind"))
	if k.find("clerk") < 0 and k != "patty" and k != "receptionist":
		return false
	if k.find("gather") >= 0:
		return int(pt._gather_cargo()) > 0
	return int(App.gold) > 0 or int(pt._gather_cargo()) > 0 or int(pt._misc_cargo()) > 0


static func _done_with_clerk(pt: Node, n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	Util._ban(pt, n)
	Util.mark_pad(pt, n)
	Util.drop_lock(pt)


static func _stop_gather(p: Node) -> void:
	if p != null and is_instance_valid(p) and p.has_method("stop_gather"):
		p.stop_gather()


static func _foe(pt: Node, p: Node) -> Node:
	var seen_e: Node = pt._nearest_visible_threat(p)
	if seen_e and is_instance_valid(seen_e):
		return seen_e
	return Goals.nearest_room_threat(pt, p, ROOM)


static func wander(pt: Node, p: Node, _delta: float) -> void:
	Util.wander_step(pt, p)


static func _engage(pt: Node, p: Node, foe: Node, why: String) -> void:
	Util.drop_lock(pt)
	PlaytestLog.decide(pt, p, "fight", why, PlaytestLog.target(foe))
	if pt._is_boss(foe):
		pt._approach_boss(p, foe)
	else:
		pt._fight(p, foe)


static func think(pt: Node, p: Node, delta: float) -> void:
	Util.tick_motion(pt, p, delta)
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	var gathering: Variant = p.get("gathering")
	var mining: bool = gathering != null and is_instance_valid(gathering)
	var foe: Node = _foe(pt, p)
	if foe and is_instance_valid(foe):
		if mining:
			_stop_gather(p)
		_engage(pt, p, foe, "threat")
		return
	if mining:
		PlaytestLog.decide(pt, p, "gathering", "busy", PlaytestLog.target(gathering))
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	var spin: bool = Util.spinning(pt)
	if Util.should_unstick(pt, p) or spin:
		pt.path.clear()
		pt.path_i = 0
		var spin_cd: float = Util._meta_f(pt, "spin_d", 0.0) - delta
		pt.set_meta("spin_d", spin_cd)
		if Util.should_unstick(pt, p) or spin_cd <= 0.0:
			pt.dash = true
			pt.just["dash"] = true
			pt.set_meta("spin_d", 0.8)
		var stall: Node = Util._meta_n(pt, "lock_n")
		if stall and (not stall.is_in_group("enemies") or pt._dist(p, stall) > CLOSE):
			Util._ban(pt, stall)
		Util.drop_lock(pt)
		pt.set_meta("cell_t", 0.0)
	var hold: Node = Util._locked(pt, delta)
	if hold and is_instance_valid(hold):
		if hold.is_in_group("enemies"):
			if not Util.alive_enemy(hold) or Util._banned(pt, hold):
				Util.drop_lock(pt)
				hold = null
			else:
				_engage(pt, p, hold, "lock")
				return
		var hk: String = str(hold.get("kind"))
		if hk.find("clerk") >= 0 and not _wants_clerk(pt, hold):
			_done_with_clerk(pt, hold)
			hold = null
		elif Util.is_junk(pt, hold) or not Util.can_use(pt, hold):
			Util.drop_lock(pt)
			hold = null
	if hold and is_instance_valid(hold):
		PlaytestLog.decide(pt, p, "hold", "lock", PlaytestLog.target(hold))
		var hk2: String = str(hold.get("kind"))
		if Util.is_use_kind(hk2) or Util.is_clerk_kind(hk2) or Util.is_loot_kind(hk2) or hk2.find("door") >= 0 or hk2.find("stairs") >= 0:
			use_prop(pt, p, hold)
			if hk2.find("clerk") >= 0 and not _wants_clerk(pt, hold):
				_done_with_clerk(pt, hold)
		elif pt._is_boss(hold):
			pt._approach_boss(p, hold)
		else:
			pt._follow_goal(p, hold)
		return
	if hold:
		Util.drop_lock(pt)
	var hunt: Node = pt._nearest_hunt(p)
	if hunt and is_instance_valid(hunt) and pt._dist(p, hunt) <= NEAR:
		if Util.spinning(pt):
			Util._ban(pt, hunt)
			Util.drop_lock(pt)
		else:
			Util._lock(pt, hunt, 1.6)
			PlaytestLog.decide(pt, p, "hunt", "hunt", PlaytestLog.target(hunt))
			if pt._is_boss(hunt):
				pt._approach_boss(p, hunt)
			else:
				pt._fight(p, hunt)
			return
	if App.extracted:
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs and is_instance_valid(stairs) and not Util._banned(pt, stairs) and pt._dist(p, stairs) <= SEE:
			Util._lock(pt, stairs, 4.0)
			PlaytestLog.decide(pt, p, "extract_stairs", "extracted", PlaytestLog.target(stairs))
			use_prop(pt, p, stairs)
			return
	var chest: Node = pt._best_chest(p)
	if chest and is_instance_valid(chest) and Util.can_use(pt, chest) and not Util.is_junk(pt, chest) and pt._dist(p, chest) <= START:
		Util._lock(pt, chest, 4.0)
		PlaytestLog.decide(pt, p, "gather", "chest", PlaytestLog.target(chest))
		use_prop(pt, p, chest)
		return
	var node: Node = pt._best_gather(p)
	if node and is_instance_valid(node) and Util.can_use(pt, node) and not Util.is_junk(pt, node) and pt._dist(p, node) <= START:
		Util._lock(pt, node, 6.0)
		PlaytestLog.decide(pt, p, "gather", "path_prop", PlaytestLog.target(node))
		use_prop(pt, p, node)
		return
	var local: Node = _usable_local(pt, p, START)
	if local:
		var lk: String = str(local.get("kind"))
		if lk == "mine" or lk == "wood" or Util.is_loot_kind(lk) or lk.find("chest") >= 0:
			Util._lock(pt, local, 6.0 if lk == "mine" or lk == "wood" else 4.0)
			PlaytestLog.decide(pt, p, "gather", "local_prop", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if _wants_clerk(pt, local):
			Util._lock(pt, local, 4.0)
			PlaytestLog.decide(pt, p, "clerk", "cargo_local", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if lk.find("door") >= 0 or lk.find("stairs") >= 0:
			Util._lock(pt, local, 2.5)
			PlaytestLog.decide(pt, p, "door", "local_exit", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
	var clerk: Node = pt._best_clerk(p)
	if clerk and is_instance_valid(clerk) and _wants_clerk(pt, clerk) and pt._dist(p, clerk) <= START:
		Util._lock(pt, clerk, 4.0)
		PlaytestLog.decide(pt, p, "clerk", "cargo_near", PlaytestLog.target(clerk))
		use_prop(pt, p, clerk)
		return
	var crystal: Node = Goals.closest_kind(pt, p, "crystal", 2.4)
	if crystal:
		var flee_c: Vector2 = Goals.away_open(pt, p, crystal)
		if flee_c != Vector2.ZERO:
			PlaytestLog.decide(pt, p, "wander", "leave_crystal")
			pt.path.clear()
			pt.path_goal = null
			pt.move = flee_c
			pt.wander_dir = flee_c
			return
	var why: String = "no_stairs" if App.extracted else "explore"
	PlaytestLog.decide(pt, p, "wander", why)
	pt._wander(p, delta)
