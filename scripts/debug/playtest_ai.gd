extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const Util := preload("res://scripts/debug/playtest_ai_util.gd")
const NEAR := 22.0
const SEE := 28.0
const CLOSE := 2.4
const START := 24.0


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


static func _tool() -> String:
	if App.prog:
		return str(App.prog.tool_type)
	return "pickaxe"


static func _tool_matches(k: String) -> bool:
	var tool: String = _tool()
	if k == "wood":
		return tool == "hatchet"
	if k == "mine":
		return tool == "pickaxe"
	return true


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
	if (k == "mine" or k == "wood") and not _tool_matches(k):
		return true
	if (k == "mine" or k == "wood") and int(n.get("hits")) <= 0:
		return true
	return false


static func _mark_pad(pt: Node, n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var c: Vector2i = pt._cell_of_node(n)
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			Util._mark(pt, c + Vector2i(x, y))


static func _junk_away(pt: Node, p: Node, radius: float = 4.0) -> Vector2:
	var tree: SceneTree = p.get_tree()
	if tree == null:
		return Vector2.ZERO
	var best: Node = null
	var best_d: float = radius
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if not _is_junk(pt, n):
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return Vector2.ZERO
	var away: Vector2 = -pt._xz_to(p, best)
	if away.length() < 0.05:
		return Vector2.RIGHT
	return away.normalized()


static func _usable_local(pt: Node, p: Node, lim: float) -> Node:
	var guard: int = 0
	while guard < 8:
		guard += 1
		var n: Node = Util._near_prop(pt, p, lim)
		if n == null or not is_instance_valid(n):
			return null
		if _is_junk(pt, n) or not Util.can_use(pt, n):
			Util._ban(pt, n)
			_mark_pad(pt, n)
			continue
		return n
	return null


static func _gather_left(pt: Node) -> int:
	return int(pt._gather_cargo())


static func _wants_clerk(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or Util._banned(pt, n):
		return false
	var k: String = str(n.get("kind"))
	if k.find("clerk") < 0 and k != "patty" and k != "receptionist":
		return false
	if k.find("gather") >= 0:
		return _gather_left(pt) > 0
	return int(App.gold) > 0 or _gather_left(pt) > 0 or int(pt._misc_cargo()) > 0


static func _done_with_clerk(pt: Node, n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	Util._ban(pt, n)
	_mark_pad(pt, n)
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)
	pt.path.clear()
	pt.path_goal = null


static func wander(pt: Node, p: Node, _delta: float) -> void:
	var here: Vector2i = pt._cell_of_node(p)
	Util._mark(pt, here)
	var seen: Dictionary = Util._seen(pt)
	var last: Vector2 = pt.wander_dir
	var flee: Vector2 = _junk_away(pt, p, 5.0)
	if flee != Vector2.ZERO and last != Vector2.ZERO and last.dot(flee) < -0.2:
		last = flee
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var best: Vector2 = Vector2.ZERO
	var best_s: float = -999.0
	for d: Vector2 in dirs:
		if not pt._dir_open(p, d):
			continue
		var nxt: Vector2i = here + Vector2i(int(signf(d.x)), int(signf(d.y)))
		var s: float = 0.0
		if not seen.has(nxt):
			s += 4.0
		else:
			s -= 0.8
		if last != Vector2.ZERO and d.dot(last) > 0.5:
			s += 1.0
		if last != Vector2.ZERO and d.dot(last) < -0.5:
			s -= 3.2
		if flee != Vector2.ZERO:
			if d.dot(flee) > 0.25:
				s += 2.4
			elif d.dot(flee) < -0.25:
				s -= 3.6
		if s > best_s:
			best_s = s
			best = d
	if best == Vector2.ZERO:
		best = pt._any_open(p)
	pt.wander_dir = best
	pt.aim = best
	pt.move = best
	pt.path.clear()
	pt.path_goal = null


static func _closest_kind(pt: Node, p: Node, kind: String, radius: float) -> Node:
	var best: Node = null
	var best_d: float = radius
	var tree: SceneTree = p.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")) != kind:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


static func _away_open(pt: Node, p: Node, node: Node) -> Vector2:
	var away: Vector2 = -pt._xz_to(p, node)
	if away.length() < 0.05:
		away = Vector2.RIGHT
	var tried: Array[Vector2] = [
		away,
		Vector2(-away.y, away.x),
		Vector2(away.y, -away.x),
		-away,
	]
	for raw: Vector2 in tried:
		var stepped: Vector2 = pt._safe_step(p, raw)
		if stepped.length() >= 0.35 and stepped.dot(raw) > 0.0:
			return stepped
	return Vector2.ZERO


static func think(pt: Node, p: Node, delta: float) -> void:
	Util.tick_motion(pt, p, delta)
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	var gathering: Variant = p.get("gathering")
	var mining: bool = gathering != null and is_instance_valid(gathering)
	if mining:
		PlaytestLog.decide(pt, p, "gathering", "busy", PlaytestLog.target(gathering))
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	var seen_e: Node = pt._nearest_visible_threat(p)
	if seen_e and is_instance_valid(seen_e):
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		PlaytestLog.decide(pt, p, "fight", "threat", PlaytestLog.target(seen_e))
		pt._fight(p, seen_e)
		return
	if Util.should_unstick(pt, p):
		pt.path.clear()
		pt.path_i = 0
		pt.dash = true
		pt.just["dash"] = true
		var stall: Node = Util._meta_n(pt, "lock_n")
		if stall and pt._dist(p, stall) > CLOSE:
			Util._ban(pt, stall)
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		pt.set_meta("lock_t", 0.0)
		pt.set_meta("cell_t", 0.0)
	var hold: Node = Util._locked(pt, delta)
	if hold and is_instance_valid(hold):
		var hk: String = str(hold.get("kind"))
		if hk.find("clerk") >= 0 and not _wants_clerk(pt, hold):
			_done_with_clerk(pt, hold)
			hold = null
		elif _is_junk(pt, hold) or not Util.can_use(pt, hold):
			if pt.has_meta("lock_n"):
				pt.remove_meta("lock_n")
			pt.set_meta("lock_t", 0.0)
			hold = null
	if hold and is_instance_valid(hold):
		PlaytestLog.decide(pt, p, "hold", "lock", PlaytestLog.target(hold))
		var hk2: String = str(hold.get("kind"))
		if Util.is_use_kind(hk2) or Util.is_clerk_kind(hk2) or Util.is_loot_kind(hk2) or hk2 == "mine" or hk2 == "wood" or hk2.find("chest") >= 0 or hk2.find("door") >= 0 or hk2.find("stairs") >= 0:
			use_prop(pt, p, hold)
			if hk2.find("clerk") >= 0 and not _wants_clerk(pt, hold):
				_done_with_clerk(pt, hold)
		elif pt._is_boss(hold):
			pt._approach_boss(p, hold)
		else:
			pt._follow_goal(p, hold)
		return
	if hold:
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		pt.set_meta("lock_t", 0.0)
	var hunt: Node = pt._nearest_hunt(p)
	if hunt and is_instance_valid(hunt) and pt._dist(p, hunt) <= NEAR:
		Util._lock(pt, hunt, 1.6)
		PlaytestLog.decide(pt, p, "hunt", "hunt", PlaytestLog.target(hunt))
		if pt._is_boss(hunt):
			pt._approach_boss(p, hunt)
		else:
			pt._follow_goal(p, hunt)
			pt.aim = pt._xz_to(p, hunt)
		return
	if App.extracted:
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs and is_instance_valid(stairs) and not Util._banned(pt, stairs) and pt._dist(p, stairs) <= SEE:
			Util._lock(pt, stairs, 4.0)
			PlaytestLog.decide(pt, p, "extract_stairs", "extracted", PlaytestLog.target(stairs))
			use_prop(pt, p, stairs)
			return
	var chest: Node = pt._best_chest(p)
	if chest and is_instance_valid(chest) and Util.can_use(pt, chest) and not _is_junk(pt, chest) and pt._dist(p, chest) <= START:
		Util._lock(pt, chest, 4.0)
		PlaytestLog.decide(pt, p, "gather", "chest", PlaytestLog.target(chest))
		use_prop(pt, p, chest)
		return
	var node: Node = pt._best_gather(p)
	if node and is_instance_valid(node) and Util.can_use(pt, node) and not _is_junk(pt, node) and pt._dist(p, node) <= START:
		Util._lock(pt, node, 6.0)
		PlaytestLog.decide(pt, p, "gather", "path_prop", PlaytestLog.target(node))
		use_prop(pt, p, node)
		return
	var local: Node = _usable_local(pt, p, START)
	if local:
		var lk: String = str(local.get("kind"))
		if lk == "mine" or lk == "wood":
			Util._lock(pt, local, 6.0)
			PlaytestLog.decide(pt, p, "gather", "local_prop", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if Util.is_loot_kind(lk) or lk.find("chest") >= 0:
			Util._lock(pt, local, 4.0)
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
	var crystal: Node = _closest_kind(pt, p, "crystal", 2.4)
	if crystal:
		var flee_c: Vector2 = _away_open(pt, p, crystal)
		if flee_c != Vector2.ZERO:
			PlaytestLog.decide(pt, p, "wander", "leave_crystal")
			pt.path.clear()
			pt.path_goal = null
			pt.move = flee_c
			pt.wander_dir = flee_c
			return
	var why: String = "explore"
	if App.extracted:
		why = "no_stairs"
	PlaytestLog.decide(pt, p, "wander", why)
	pt._wander(p, delta)


static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	if boss == null or not is_instance_valid(boss) or pt._dist(p, boss) > SEE:
		pt.move = Vector2.ZERO
		return
	var gate: Node = pt._closed_door()
	if gate != null and is_instance_valid(gate) and (pt._door_between(p, boss) or pt._near_closed_door(p) or not pt._has_path(p, boss)):
		PlaytestLog.decide(pt, p, "door", "boss_gate", PlaytestLog.target(gate))
		pt._go_open_door(p, gate)
		return
	if pt._has_los(p, boss) and pt._dist(p, boss) <= 6.5:
		PlaytestLog.decide(pt, p, "fight", "boss_los", PlaytestLog.target(boss))
		pt._fight(p, boss)
		return
	if pt._has_path(p, boss):
		pt._follow_goal(p, boss)
		pt.aim = pt._xz_to(p, boss)
		return
	pt.move = Vector2.ZERO


static func fight(pt: Node, p: Node, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		pt.move = Vector2.ZERO
		pt.attack = false
		return
	var d: float = pt._dist(p, enemy)
	var rng: float = pt._weapon_range()
	var boss: bool = pt._is_boss(enemy)
	var los: bool = pt._has_wide_los(p, enemy) if pt._is_bow() else pt._has_los(p, enemy)
	if pt._door_between(p, enemy):
		var bypass: Vector2 = pt._door_bypass(p, enemy)
		pt.move = pt._steer(p, bypass if bypass != Vector2.ZERO else pt._door_away(p))
		pt.attack = false
		pt._lock_aim(p, enemy)
		return
	var hold: float = clampf(rng * 0.86, 1.12, maxf(1.12, rng - 0.08))
	var too_close: float = minf(hold * 0.52, maxf(0.78, rng * 0.34))
	if boss and pt._is_axe():
		hold = rng - 0.18
		too_close = 1.08
	elif boss:
		hold = 3.9 if not pt._is_bow() else clampf(rng * 0.62, 3.2, 6.2)
		too_close = 3.2 if not pt._is_bow() else 2.6
	if pt._is_bow():
		hold = clampf(rng * 0.62, 3.2, 6.2)
		too_close = 2.6
	if pt._is_staff():
		hold = pt._staff_hold()
		too_close = 2.05
	pt._lock_aim(p, enemy)
	if App.tel and App.tel.dmg_dealt > 0.0:
		pt.hit_something = true
	var need_path: bool = (not los) or (d > hold and not pt._walk_clear(p, enemy))
	if pt._is_axe() and not pt._walk_clear(p, enemy) and d > rng:
		need_path = true
	if need_path and pt._has_path(p, enemy):
		pt._follow_goal(p, enemy)
		pt._lock_aim(p, enemy)
		pt.attack = los and pt._in_primary(d) and not pt._is_staff()
		if pt._is_staff():
			pt._try_staff_special(d, los)
		return
	pt.path.clear()
	pt.path_goal = null
	if not los:
		var slide: Vector2 = pt._los_reposition(p, enemy)
		pt.move = pt._steer(p, slide)
		pt._lock_aim(p, enemy)
		pt.attack = false
		if pt.stuck_t > 0.4:
			pt.strafe_sign *= -1.0
			pt.dash = true
			pt.just["dash"] = true
		return
	if pt._is_staff():
		pt._try_staff_special(d, true)
		pt.attack = pt.spec_cd > 0.2 and pt._in_primary(d)
		if d < too_close:
			pt.move = pt._safe_step(p, -pt.aim)
		elif d > hold + 0.35:
			pt.move = pt._safe_step(p, pt.aim)
		else:
			pt.move = pt._safe_step(p, Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign)
			if pt.stuck_t > 0.35:
				pt.strafe_sign *= -1.0
				pt.dash = true
				pt.just["dash"] = true
		pt._lock_aim(p, enemy)
		return
	if pt._is_axe() and boss:
		pt.attack = pt._in_primary(d)
		if pt.spec_cd <= 0.0 and d <= float(App.bal.slam_radius) + 0.08:
			pt.special = true
			pt.just["special"] = true
			pt.spec_cd = 1.1
		if d < too_close:
			pt.move = pt._safe_step(p, -pt.aim)
		elif not pt._in_primary(d):
			pt.move = pt._safe_step(p, pt.aim)
		else:
			pt.move = pt._safe_step(p, Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign)
		pt._lock_aim(p, enemy)
		return
	if d < too_close:
		pt.move = pt._safe_step(p, -pt.aim)
		pt.attack = pt._in_primary(d)
		if d < (2.6 if boss else 1.05) or pt._crowd(p) >= 2 or pt.stuck_t > 0.4:
			pt.dash = true
			pt.just["dash"] = true
		pt._lock_aim(p, enemy)
		return
	if d > hold:
		pt.move = pt._safe_step(p, pt.aim)
		pt.attack = false
		pt._lock_aim(p, enemy)
		return
	pt.move = pt._safe_step(p, Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign)
	pt.attack = true
	if pt.stuck_t > 0.3:
		pt.strafe_sign *= -1.0
		pt.dash = true
		pt.just["dash"] = true
	pt._lock_aim(p, enemy)
