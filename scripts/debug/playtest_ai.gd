extends Object


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
	if bool(n.get("is_boss")):
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


static func use_prop(pt: Node, p: Node, dest: Node, reach: float) -> void:
	if pt._dist(p, dest) < reach:
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, dest)
		pt.interact = true
		pt.just["interact"] = true
		return
	pt._follow_goal(p, dest)
	pt.aim = pt._xz_to(p, dest)


static func wander(pt: Node, p: Node, delta: float) -> void:
	pt.wander_t -= delta
	if pt.wander_t <= 0.0 or pt.wander_dir == Vector2.ZERO or not pt._dir_open(p, pt.wander_dir):
		pt.wander_t = 1.2
		pt.wander_dir = pt._any_open(p)
	pt.move = pt._safe_step(p, pt.wander_dir)
	pt.aim = pt.move if pt.move.length() > 0.1 else pt.wander_dir


static func think(pt: Node, p: Node, delta: float) -> void:
	var pos: Vector3 = (p as Node3D).global_position
	if pt.last_pos.distance_to(pos) > 0.08:
		pt.moved = true
		pt.stuck_t = 0.0
	else:
		pt.stuck_t += delta
	pt.last_pos = pos
	if p.get("hp") != null and float(p.hp) / maxf(1.0, float(p.max_hp)) < 0.35:
		pt.potion = true
		pt.just["potion"] = true
	var gathering: Variant = p.get("gathering")
	if gathering != null and is_instance_valid(gathering):
		pt.path.clear()
		pt.path_goal = null
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, gathering)
		return
	var seen: Node = pt._nearest_visible_threat(p)
	if seen:
		pt._fight(p, seen)
		return
	var hunt: Node = pt._nearest_hunt(p)
	if hunt:
		if pt._is_boss(hunt):
			pt._approach_boss(p, hunt)
		else:
			pt._follow_goal(p, hunt)
			pt.aim = pt._xz_to(p, hunt)
		return
	if App.extracted:
		var stairs: Node = pt._reachable_kind(p, "stairs")
		if stairs == null:
			var wait_boss: Node = pt._nearest_boss(p)
			if wait_boss:
				pt._approach_boss(p, wait_boss)
				return
		pt._follow_goal(p, stairs)
		if stairs and pt._dist(p, stairs) < 1.15:
			pt.interact = true
			pt.just["interact"] = true
		return
	var clerk: Node = pt._best_clerk(p)
	if clerk:
		pt._use_prop(p, clerk, 1.25)
		return
	var node: Node = pt._best_gather(p)
	if node:
		pt._use_prop(p, node, 1.05)
		return
	var chest: Node = pt._best_chest(p)
	if chest:
		pt._use_prop(p, chest, 1.2)
		return
	var boss: Node = pt._nearest_boss(p)
	if boss and (pt._near_closed_door(p) or pt._dist(p, boss) <= 8.5 or pt._has_los(p, boss)):
		pt._approach_boss(p, boss)
		return
	var dest: Node = pt._reachable_kind(p, "stairs")
	if dest == null:
		dest = pt._reachable_kind(p, "crystal")
	if dest:
		pt._follow_goal(p, dest)
		return
	pt._wander(p, delta)


static func approach_boss(pt: Node, p: Node, boss: Node) -> void:
	var gate: Node = pt._closed_door()
	if gate != null and (pt._door_between(p, boss) or pt._near_closed_door(p) or not pt._has_path(p, boss)):
		pt._go_open_door(p, gate)
		return
	if pt._has_los(p, boss) and pt._dist(p, boss) <= 6.5:
		pt._fight(p, boss)
		return
	if pt._has_path(p, boss):
		pt._follow_goal(p, boss)
		pt.aim = pt._xz_to(p, boss)
		return
	pt.move = pt._steer(p, Vector2.ZERO)


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
