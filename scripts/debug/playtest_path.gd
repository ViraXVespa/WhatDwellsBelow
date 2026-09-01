extends Object

## Local streamed-neighborhood pathing. Far goals are reachable only if
## the window can actually advance; otherwise the AI must pick another job.

const REACH := 36
const ASTAR_GUARD := 720


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
		t += push.normalized() * 0.20
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
		if off.dot(axis) > 0.08:
			sep -= axis
		else:
			var probe: Vector3 = Vector3(pos.x + axis.x * 0.34, pos.y, pos.z + axis.y * 0.34)
			if not pt._pos_walkable(probe):
				sep -= axis
	if sep.length() < 0.001:
		return Vector2.ZERO
	return sep.normalized()


static func steer(pt: Node, p: Node, desired: Vector2) -> Vector2:
	var sep: Vector2 = pt._wall_sep(p)
	var out: Vector2 = desired
	if desired != Vector2.ZERO and not pt._dir_open(p, desired):
		out = Vector2.ZERO
	if out == Vector2.ZERO:
		out = sep
	elif sep != Vector2.ZERO:
		out = (out * 0.40 + sep * 1.15).normalized()
	if out == Vector2.ZERO or not pt._dir_open(p, out):
		out = pt._any_open(p)
	return out


static func step_dir(pt: Node, p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return pt._steer(p, Vector2.ZERO)
	desired = desired.normalized()
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var best: Vector2 = Vector2.ZERO
	var best_score: float = -999.0
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nxt: Vector2i = here + n
		if not pt._steer_floor(nxt):
			continue
		var dir: Vector2 = Vector2(float(n.x), float(n.y))
		if not pt._dir_open(p, dir):
			continue
		var score: float = dir.dot(desired)
		if score > best_score:
			best_score = score
			best = dir
	if best == Vector2.ZERO:
		return pt._steer(p, Vector2.ZERO)
	return pt._steer(p, best)


static func _manh(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func has_path(pt: Node, p: Node, dest: Node) -> bool:
	if dest == null:
		return false
	if pt._dist(p, dest) < 1.35:
		return true
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var goal: Vector2i = pt._stand_cell(p, dest)
	var md: int = _manh(start, goal)
	if md <= REACH:
		return not astar(pt, p, dest).is_empty()
	var mid: Vector2i = _toward(pt, start, goal)
	return _manh(start, mid) >= 3


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
	pt.move = pt._steer(p, follow_or_direct(pt, p, dest))


static func follow_or_direct(pt: Node, p: Node, dest: Node) -> Vector2:
	if pt._dist(p, dest) < 1.55:
		pt.path.clear()
		return Vector2.ZERO
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = astar(pt, p, dest)
		pt.path_i = 0
	if pt.path.is_empty() or pt.path.size() <= 1:
		if pt._dist(p, dest) > 1.7:
			return pt._any_open(p)
		return Vector2.ZERO
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	while pt.path_i < pt.path.size() and pt.path[pt.path_i] == here:
		pt.path_i += 1
	if pt.path_i >= pt.path.size():
		pt.path.clear()
		if pt._dist(p, dest) > 1.7:
			return pt._any_open(p)
		return Vector2.ZERO
	var c: Vector2i = pt.path[pt.path_i]
	var target: Vector2 = pt._clearance_target(c)
	var pos: Vector3 = (p as Node3D).global_position
	var d: Vector2 = Vector2(target.x - pos.x, target.y - pos.z)
	if d.length() < 0.28:
		pt.path_i += 1
		if pt.path_i >= pt.path.size():
			return Vector2.ZERO
		return follow_or_direct(pt, p, dest)
	if not pt._dir_open(p, d):
		return pt._step_dir(p, d)
	return d.normalized()


static func _toward(pt: Node, start: Vector2i, goal: Vector2i) -> Vector2i:
	var md: int = _manh(start, goal)
	if md <= REACH:
		return goal
	var cur: Vector2i = start
	var i: int = 0
	while i < REACH:
		i += 1
		var step: Vector2i = Vector2i.ZERO
		if absi(goal.x - cur.x) >= absi(goal.y - cur.y):
			step.x = signi(goal.x - cur.x)
		else:
			step.y = signi(goal.y - cur.y)
		var nxt: Vector2i = cur + step
		if pt._steer_floor(nxt) and not pt._prop_cell(nxt):
			cur = nxt
			continue
		var alt: Vector2i = Vector2i(step.y, step.x)
		if alt == Vector2i.ZERO:
			alt = Vector2i(signi(goal.x - cur.x), 0)
		if pt._steer_floor(cur + alt) and not pt._prop_cell(cur + alt):
			cur = cur + alt
			continue
		alt = Vector2i(-alt.x, -alt.y)
		if pt._steer_floor(cur + alt) and not pt._prop_cell(cur + alt):
			cur = cur + alt
			continue
		break
	return cur


static func astar(pt: Node, p: Node, dest: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty() or dest == null:
		return out
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var raw_goal: Vector2i = pt._stand_cell(p, dest)
	if not pt._steer_floor(start) or pt._prop_cell(start):
		for n: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if pt._steer_floor(start + n) and not pt._prop_cell(start + n):
				start += n
				break
	var goal: Vector2i = _toward(pt, start, raw_goal)
	if not pt._steer_floor(goal) or pt._prop_cell(goal):
		return out
	if start == goal:
		out.append(goal)
		return out
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var gscore: Dictionary = {}
	var fscore: Dictionary = {}
	gscore[start] = 0
	fscore[start] = start.distance_to(goal)
	var closed: Dictionary = {}
	var guard: int = 0
	var min_x: int = start.x - REACH - 1
	var max_x: int = start.x + REACH + 1
	var min_y: int = start.y - REACH - 1
	var max_y: int = start.y + REACH + 1
	while not open.is_empty() and guard < ASTAR_GUARD:
		guard += 1
		var best_i: int = 0
		var best_f: float = float(fscore.get(open[0], 1e9))
		for i: int in open.size():
			var f: float = float(fscore.get(open[i], 1e9))
			if f < best_f:
				best_f = f
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		if cur == goal:
			var step: Vector2i = cur
			var rev: Array[Vector2i] = []
			while step != start:
				rev.append(step)
				if not came.has(step):
					break
				step = came[step]
			rev.reverse()
			return rev
		closed[cur] = true
		for n2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + n2
			if nxt.x < min_x or nxt.x > max_x or nxt.y < min_y or nxt.y > max_y:
				continue
			if closed.has(nxt) or not pt._floor_cell(grid, w, h, nxt):
				continue
			var tg: int = int(gscore.get(cur, 0)) + 1
			if tg < int(gscore.get(nxt, 1 << 30)):
				came[nxt] = cur
				gscore[nxt] = tg
				fscore[nxt] = float(tg) + nxt.distance_to(goal)
				if open.find(nxt) < 0:
					open.append(nxt)
	return out
