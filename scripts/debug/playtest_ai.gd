extends Object

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const NEAR := 22.0


static func weapon_range() -> float:
	var w: String = str(App.weapon)
	if w == "longbow":
		return maxf(2.4, float(App.bal.bow_range))
	if w == "staff":
		return maxf(1.05, float(App.bal.staff_range))
	return maxf(1.15, float(App.bal.axe_range))


static func is_boss(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.get("is_boss") == true:
		return true
	return n.is_in_group("boss")


static func alive_enemy(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("is_alive") and not n.is_alive():
		return false
	return true


static func notice_range(pt: Node) -> float:
	if pt._is_staff():
		return maxf(6.2, float(App.bal.staff_special_radius) + 4.0)
	if pt._is_bow():
		return maxf(6.0, float(App.bal.bow_range) + 0.4)
	return maxf(4.4, pt._weapon_range() + 1.6)


static func try_staff_special(pt: Node, d: float, los: bool) -> void:
	if not los or pt.spec_cd > 0.0:
		return
	if d < 1.45 or d > pt._staff_hold() + 1.8:
		return
	pt.special = true
	pt.just["special"] = true
	pt.spec_cd = 1.15


static func _meta_n(pt: Node, key: String) -> Node:
	if not pt.has_meta(key):
		return null
	var v: Variant = pt.get_meta(key)
	if v == null or not is_instance_valid(v):
		return null
	return v


static func _meta_f(pt: Node, key: String, fallback: float = 0.0) -> float:
	if not pt.has_meta(key):
		return fallback
	return float(pt.get_meta(key))


static func _lock(pt: Node, n: Node, sec: float = 3.2) -> void:
	pt.set_meta("lock_n", n)
	pt.set_meta("lock_t", sec)


static func _locked(pt: Node, delta: float) -> Node:
	var t: float = _meta_f(pt, "lock_t", 0.0) - delta
	pt.set_meta("lock_t", t)
	if t <= 0.0:
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		return null
	return _meta_n(pt, "lock_n")


static func _bans(pt: Node) -> Array:
	if not pt.has_meta("skip_list"):
		return []
	var a: Variant = pt.get_meta("skip_list")
	return a if a is Array else []


static func _banned(pt: Node, n: Node) -> bool:
	if n == null:
		return true
	return _bans(pt).has(n)


static func _ban(pt: Node, n: Variant) -> void:
	if n == null:
		return
	var a: Array = _bans(pt)
	if not a.has(n):
		a.append(n)
	if a.size() > 16:
		a.pop_front()
	pt.set_meta("skip_list", a)


static func _seen(pt: Node) -> Dictionary:
	if not pt.has_meta("seen_map"):
		return {}
	var a: Variant = pt.get_meta("seen_map")
	return a if a is Dictionary else {}


static func _mark(pt: Node, c: Vector2i) -> void:
	var m: Dictionary = _seen(pt)
	m[c] = true
	if m.size() > 120:
		var k: Variant = m.keys()[0]
		m.erase(k)
	pt.set_meta("seen_map", m)


static func _near_prop(pt: Node, p: Node, lim: float) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = lim
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n) or _banned(pt, n):
			continue
		var k: String = str(n.get("kind"))
		if k.find("crystal") >= 0:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


static func use_prop(pt: Node, p: Node, dest: Node, _reach: float = 1.18) -> void:
	if dest == null:
		pt.move = Vector2.ZERO
		return
	var d: float = pt._dist(p, dest)
	pt.aim = pt._xz_to(p, dest)
	pt.path_goal = dest
	if d < 1.18:
		pt.path.clear()
		pt.move = Vector2.ZERO
		pt.interact = true
		pt.just["interact"] = true
		return
	pt.path.clear()
	pt.move = pt._safe_step(p, pt.aim)


static func wander(pt: Node, p: Node, _delta: float) -> void:
	var here: Vector2i = pt._cell_of_node(p)
	_mark(pt, here)
	var seen: Dictionary = _seen(pt)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var fresh: Vector2 = Vector2.ZERO
	var open_any: Vector2 = Vector2.ZERO
	for n: Vector2i in dirs:
		var d: Vector2 = Vector2(float(n.x), float(n.y))
		if not pt._dir_open(p, d):
			continue
		if open_any == Vector2.ZERO:
			open_any = d
		if not seen.has(here + n):
			fresh = d
			break
	var heading: Vector2 = fresh
	if heading == Vector2.ZERO:
		heading = open_any
	if heading == Vector2.ZERO:
		heading = pt._any_open(p)
	pt.wander_dir = heading
	pt.aim = heading
	pt.move = heading


static func think(pt: Node, p: Node, delta: float) -> void:
	var pos: Vector3 = (p as Node3D).global_position
	if pt.last_pos.distance_to(pos) > 0.08:
		pt.moved = true
		pt.stuck_t = 0.0
	else:
		pt.stuck_t += delta
	pt.last_pos = pos
	var here: Vector2i = pt._cell_of_node(p)
	var prev_c: Vector2i = Vector2i(-999, -999)
	if pt.has_meta("stuck_cell"):
		prev_c = pt.get_meta("stuck_cell")
	if here == prev_c:
		pt.set_meta("cell_t", _meta_f(pt, "cell_t", 0.0) + delta)
	else:
		pt.set_meta("stuck_cell", here)
		pt.set_meta("cell_t", 0.0)
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	if pt.stuck_t > 2.0 or _meta_f(pt, "cell_t", 0.0) > 1.6:
		_ban(pt, _meta_n(pt, "lock_n"))
		if pt.path_goal:
			_ban(pt, pt.path_goal)
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		pt.set_meta("lock_t", 0.0)
		pt.set_meta("cell_t", 0.0)
		pt.path.clear()
		pt.path_goal = null
		pt.stuck_t = 0.0
		pt.dash = true
		pt.just["dash"] = true
		PlaytestLog.decide(pt, p, "unstick", "cell_stall")
		pt._wander(p, delta)
		return
	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		PlaytestLog.decide(pt, p, "gathering", "busy", PlaytestLog.target(gathering))
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	var seen_e: Node = pt._nearest_visible_threat(p)
	if seen_e:
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		PlaytestLog.decide(pt, p, "fight", "threat", PlaytestLog.target(seen_e))
		pt._fight(p, seen_e)
		return
	var hold: Node = _locked(pt, delta)
	if hold and not _banned(pt, hold):
		var hk: String = str(hold.get("kind"))
		PlaytestLog.decide(pt, p, "hold", "lock", PlaytestLog.target(hold))
		if hk.find("clerk") >= 0 or hk == "mine" or hk == "wood" or hk.find("chest") >= 0 or hk.find("stairs") >= 0 or hk.find("door") >= 0:
			use_prop(pt, p, hold)
		elif pt._is_boss(hold):
			pt._approach_boss(p, hold)
		else:
			pt._follow_goal(p, hold)
		return
	var hunt: Node = pt._nearest_hunt(p)
	if hunt and pt._dist(p, hunt) <= NEAR:
		_lock(pt, hunt, 1.6)
		PlaytestLog.decide(pt, p, "hunt", "hunt", PlaytestLog.target(hunt))
		if pt._is_boss(hunt):
			pt._approach_boss(p, hunt)
		else:
			pt._follow_goal(p, hunt)
			pt.aim = pt._xz_to(p, hunt)
		return
	if App.extracted:
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs and not _banned(pt, stairs):
			_lock(pt, stairs, 4.0)
			PlaytestLog.decide(pt, p, "extract_stairs", "extracted", PlaytestLog.target(stairs))
			use_prop(pt, p, stairs)
			return
		PlaytestLog.decide(pt, p, "extract_seek", "no_stairs")
		pt._wander(p, delta)
		return
	var cargo: bool = int(App.gold) > 0 or pt._gather_cargo() > 0 or pt._misc_cargo() > 0
	var local: Node = _near_prop(pt, p, 16.0)
	if local:
		var lk: String = str(local.get("kind"))
		if cargo and lk.find("clerk") >= 0:
			_lock(pt, local, 4.0)
			PlaytestLog.decide(pt, p, "clerk", "cargo_local", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if (not cargo) and (lk == "mine" or lk == "wood" or lk.find("chest") >= 0 or lk.find("clerk") >= 0):
			_lock(pt, local, 3.5)
			PlaytestLog.decide(pt, p, "gather", "local_prop", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
		if lk.find("door") >= 0 or lk.find("stairs") >= 0:
			_lock(pt, local, 2.5)
			PlaytestLog.decide(pt, p, "door", "local_exit", PlaytestLog.target(local))
			use_prop(pt, p, local)
			return
	var clerk: Node = pt._best_clerk(p)
	if clerk and not _banned(pt, clerk) and cargo and pt._dist(p, clerk) <= 40.0:
		_lock(pt, clerk, 4.0)
		PlaytestLog.decide(pt, p, "clerk", "cargo_near", PlaytestLog.target(clerk))
		use_prop(pt, p, clerk)
		return
	var why: String = "no_local_prop"
	if cargo and clerk == null:
		why = "no_clerk"
	elif cargo and clerk and _banned(pt, clerk):
		why = "banned"
	elif cargo and clerk:
		why = "not_path"
	PlaytestLog.decide(pt, p, "wander", why)
	pt._wander(p, delta)


static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	var gate: Node = pt._closed_door()
	if gate != null and (pt._door_between(p, boss) or pt._near_closed_door(p) or not pt._has_path(p, boss)):
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
		if pt.spec_cd <= 0.0 and pt._in_primary(d) and randf() < 0.2:
			pt.special = true
			pt.just["special"] = true
			pt.spec_cd = 1.1
		pt._lock_aim(p, enemy)
		return
	if d > hold + 0.2:
		pt.move = pt._safe_step(p, pt.aim)
		pt.attack = pt._in_primary(d)
		pt._lock_aim(p, enemy)
		return
	var side: Vector2 = Vector2(-pt.aim.y, pt.aim.x) * pt.strafe_sign
	if pt.stuck_t > 0.35:
		pt.strafe_sign *= -1.0
		pt.move = pt._safe_step(p, -pt.aim)
		pt.dash = true
		pt.just["dash"] = true
	else:
		pt.move = pt._safe_step(p, side)
	pt.attack = pt._in_primary(d)
	if pt.spec_cd <= 0.0 and pt._in_primary(d) and randf() < 0.22:
		pt.special = true
		pt.just["special"] = true
		pt.spec_cd = 1.1
	pt._lock_aim(p, enemy)
