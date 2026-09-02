extends Object

const REACH := 36
const Util := preload("res://scripts/debug/playtest_path_util.gd")


static func door_bypass(pt: Node, p: Node, boss: Node) -> Vector2:
	var door: Node = pt._closed_door()
	if door == null:
		return Vector2.ZERO
	var dc: Vector2i = pt._cell_of_node(door)
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var goal: Vector2i = pt._cell_of_node(boss)
	var best: Vector2i = Vector2i(-999, -999)
	var best_score: int = -9999
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var c: Vector2i = dc + n
		if c == dc or not pt._steer_floor(c):
			continue
		var to_boss: int = absi(c.x - goal.x) + absi(c.y - goal.y)
		var to_here: int = absi(c.x - here.x) + absi(c.y - here.y)
		var score: int = -to_boss * 3 - to_here
		if score > best_score:
			best_score = score
			best = c
	if best.x < -900:
		return Vector2.ZERO
	var pos: Vector3 = (p as Node3D).global_position
	var t: Vector2 = pt._clearance_target(best)
	var v: Vector2 = Vector2(t.x - pos.x, t.y - pos.z)
	if v.length() < 0.18:
		return Vector2.ZERO
	if not pt._dir_open(p, v):
		v = Vector2(-v.y, v.x)
		if not pt._dir_open(p, v):
			return pt._door_away(p)
	return v.normalized()


static func safe_step(pt: Node, p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return pt._steer(p, Vector2.ZERO)
	if pt._dir_open(p, desired):
		return pt._steer(p, desired.normalized())
	var step: Vector2 = pt._step_dir(p, desired)
	if step != Vector2.ZERO and pt._dir_open(p, step):
		return step
	var side: Vector2 = Vector2(-desired.y, desired.x) * pt.strafe_sign
	step = pt._step_dir(p, side)
	if step != Vector2.ZERO and pt._dir_open(p, step):
		return step
	return pt._steer(p, pt._any_open(p))


static func los_reposition(pt: Node, p: Node, target: Node) -> Vector2:
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var best: Vector2i = Vector2i(-999, -999)
	var best_score: float = -9999.0
	var rng: float = pt._weapon_range()
	if pt._is_staff():
		rng = pt._staff_hold() + 0.4
	for dy: int in range(-6, 7):
		for dx: int in range(-6, 7):
			var c: Vector2i = Vector2i(here.x + dx, here.y + dy)
			if not pt._steer_floor(c) or pt._prop_cell(c):
				continue
			var pos: Vector3 = Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)
			if pt._is_bow():
				if not pt._has_los_from_wide(pos, target):
					continue
			elif not pt._has_los_from(pos, target):
				continue
			var td: float = Vector2(pos.x - (target as Node3D).global_position.x, pos.z - (target as Node3D).global_position.z).length()
			if td > rng + 0.4:
				continue
			var walk: float = float(absi(dx) + absi(dy))
			var score: float = 12.0 - walk - absf(td - rng * 0.65)
			if score > best_score:
				best_score = score
				best = c
	if best.x < -900:
		return Vector2.ZERO
	var ppos: Vector3 = (p as Node3D).global_position
	var t: Vector2 = pt._clearance_target(best)
	var v: Vector2 = Vector2(t.x - ppos.x, t.y - ppos.z)
	if v.length() < 0.16 or not pt._dir_open(p, v):
		return Vector2.ZERO
	return v.normalized()


static func clearance_target(pt: Node, c: Vector2i) -> Vector2:
	var t: Vector2 = Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
	var push: Vector2 = Vector2.ZERO
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not pt._steer_floor(c + n):
			push -= Vector2(float(n.x), float(n.y))
	if push.length() > 0.001:
		t += push.normalized() * 0.28
	return t


static func wall_sep(pt: Node, p: Node) -> Vector2:
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var pos: Vector3 = (p as Node3D).global_position
	var center: Vector2 = Vector2(float(here.x) + 0.5, float(here.y) + 0.5)
	var off: Vector2 = Vector2(pos.x - center.x, pos.z - center.y)
	var sep: Vector2 = Vector2.ZERO
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if pt._steer_floor(here + n):
			continue
		var axis: Vector2 = Vector2(float(n.x), float(n.y))
		if off.dot(axis) > 0.04:
			sep -= axis
		else:
			var probe: Vector3 = Vector3(pos.x + axis.x * 0.34, pos.y, pos.z + axis.y * 0.34)
			if not pt._pos_walkable(probe):
				sep -= axis
	if sep.length() < 0.001:
		return Vector2.ZERO
	return sep.normalized()


static func hall_center(pt: Node, p: Node) -> Vector2:
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var pos: Vector3 = (p as Node3D).global_position
	var pull: Vector2 = Vector2.ZERO
	var open_x: bool = pt._steer_floor(here + Vector2i(1, 0)) and pt._steer_floor(here + Vector2i(-1, 0))
	var open_y: bool = pt._steer_floor(here + Vector2i(0, 1)) and pt._steer_floor(here + Vector2i(0, -1))
	var cx: float = float(here.x) + 0.5
	var cy: float = float(here.y) + 0.5
	if not open_x:
		pull.x += (cx - pos.x)
	if not open_y:
		pull.y += (cy - pos.z)
	if pull.length() < 0.04:
		return Vector2.ZERO
	return pull.normalized()


static func steer(pt: Node, p: Node, desired: Vector2) -> Vector2:
	var heading: Vector2 = desired
	if heading.length() > 0.001:
		heading = heading.normalized()
		if not pt._dir_open(p, heading):
			heading = Vector2.ZERO
	var mid: Vector2 = hall_center(pt, p)
	var sep: Vector2 = pt._wall_sep(p)
	var out: Vector2 = heading * 1.0 + mid * 0.55 + sep * 0.28
	if out.length() < 0.001:
		out = mid if mid != Vector2.ZERO else sep
	if out == Vector2.ZERO or not pt._dir_open(p, out):
		out = pt._any_open(p)
	return out.normalized() if out.length() > 0.001 else out


static func step_dir(pt: Node, p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return pt._steer(p, Vector2.ZERO)
	desired = desired.normalized()
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var best: Vector2 = Vector2.ZERO
	var best_score: float = -999.0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for n: Vector2i in dirs:
		var nxt: Vector2i = here + n
		if not pt._steer_floor(nxt):
			continue
		var dir: Vector2 = Vector2(float(n.x), float(n.y)).normalized()
		if not pt._dir_open(p, dir):
			continue
		var score: float = dir.dot(desired)
		if n.x != 0 and n.y != 0:
			score += 0.08
		if score > best_score:
			best_score = score
			best = dir
	if best == Vector2.ZERO:
		return pt._steer(p, Vector2.ZERO)
	return pt._steer(p, best)


static func has_path(pt: Node, p: Node, dest: Node) -> bool:
	if dest == null:
		return false
	if pt._dist(p, dest) < 1.35:
		return true
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var goal: Vector2i = pt._stand_cell(p, dest)
	var md: int = Util._manh(start, goal)
	if md <= REACH:
		return not Util.astar(pt, p, dest).is_empty()
	var mid: Vector2i = Util._toward(pt, start, goal)
	return Util._manh(start, mid) >= 3


static func follow_goal(pt: Node, p: Node, dest: Node) -> void:
	if dest == null:
		pt.move = pt._steer(p, Vector2.ZERO)
		return
	if pt._dist(p, dest) < 1.55:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, dest)
		return
	if pt._door_between(p, dest):
		pt._go_open_door(p, pt._closed_door())
		return
	if pt.stuck_t > 0.7:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
		pt.move = pt._steer(p, pt._any_open(p))
		if pt.stuck_t > 1.0:
			pt.dash = true
			pt.just["dash"] = true
		return
	if pt.path_goal != dest:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
	var step: Vector2 = follow_or_direct(pt, p, dest)
	if step != Vector2.ZERO and pt._dir_open(p, step):
		pt.move = pt._steer(p, step)
	else:
		pt.move = pt._safe_step(p, step)
	if step != Vector2.ZERO:
		pt.aim = step


static func follow_or_direct(pt: Node, p: Node, dest: Node) -> Vector2:
	if pt._dist(p, dest) < 1.55:
		pt.path.clear()
		return Vector2.ZERO
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = Util.astar(pt, p, dest)
		pt.path_i = 0
	if pt.path.is_empty() or pt.path.size() <= 1:
		return _cut(pt, p, dest)
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var i: int = pt.path_i
	while i < pt.path.size():
		if pt.path[i] == here:
			pt.path_i = i + 1
			break
		i += 1
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = Util.astar(pt, p, dest)
		pt.path_i = 0
	if pt.path.is_empty() or pt.path.size() <= 1:
		return _cut(pt, p, dest)
	while pt.path_i < pt.path.size() and pt.path[pt.path_i] == here:
		pt.path_i += 1
	if pt.path_i >= pt.path.size():
		pt.path.clear()
		return _cut(pt, p, dest)
	var aim_i: int = pt.path_i
	var last_ok: int = aim_i
	var cap: int = mini(pt.path.size() - 1, pt.path_i + 5)
	while aim_i <= cap:
		var ac: Vector2i = pt.path[aim_i]
		var av: Vector2 = Vector2(float(ac.x) + 0.5, float(ac.y) + 0.5)
		var pos: Vector3 = (p as Node3D).global_position
		var dir: Vector2 = Vector2(av.x - pos.x, av.y - pos.z)
		if dir.length() < 0.08 or not pt._dir_open(p, dir):
			break
		last_ok = aim_i
		aim_i += 1
	var c: Vector2i = pt.path[last_ok]
	var t: Vector2 = pt._clearance_target(c)
	var pos2: Vector3 = (p as Node3D).global_position
	var step: Vector2 = Vector2(t.x - pos2.x, t.y - pos2.z)
	if step.length() < 0.08:
		pt.path_i = last_ok + 1
		return follow_or_direct(pt, p, dest)
	if not pt._dir_open(p, step):
		return pt._step_dir(p, step)
	return step.normalized()


static func _cut(pt: Node, p: Node, dest: Node) -> Vector2:
	var cut: Vector2 = pt._xz_to(p, dest)
	if cut != Vector2.ZERO and pt._dir_open(p, cut):
		return cut
	if pt._dist(p, dest) > 1.7:
		return pt._any_open(p)
	return Vector2.ZERO


static func astar(pt: Node, p: Node, dest: Node) -> Array[Vector2i]:
	return Util.astar(pt, p, dest)
