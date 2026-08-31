extends Object

const Combat := preload("res://scripts/combat/combat.gd")


static func world3(pt: Node) -> World3D:
	var tree: SceneTree = pt.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_viewport().world_3d


static func has_los(pt: Node, a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var w3: World3D = world3(pt)
	if w3 == null:
		return true
	return Combat.los((a as Node3D).global_position, (b as Node3D).global_position, w3)


static func has_los_from(pt: Node, pos: Vector3, b: Node) -> bool:
	if b == null:
		return false
	var w3: World3D = world3(pt)
	if w3 == null:
		return true
	return Combat.los(pos, (b as Node3D).global_position, w3)


static func go_open_door(pt: Node, p: Node, gate: Node) -> void:
	if gate == null:
		pt.move = pt._steer(p, Vector2.ZERO)
		return
	pt.aim = pt._xz_to(p, gate)
	pt.attack = false
	if pt._dist(p, gate) <= 1.85:
		pt._use_prop(p, gate, 1.7)
		return
	if pt.path_goal != gate:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = gate
	pt.move = pt._steer(p, pt._follow_or_direct(p, gate))


static func door_between(pt: Node, a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var av: Vector2 = Vector2((a as Node3D).global_position.x, (a as Node3D).global_position.z)
	var bv: Vector2 = Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z)
	var ab: Vector2 = bv - av
	var den: float = ab.length_squared()
	if den < 0.0001:
		return false
	for door: Node in pt._closed_doors():
		for cell: Variant in pt._door_cells(door):
			var cv: Vector2 = Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
			var t: float = clampf((cv - av).dot(ab) / den, 0.0, 1.0)
			if t < 0.08 or t > 0.92:
				continue
			if av.lerp(bv, t).distance_to(cv) < 1.05:
				return true
	return false


static func door_blocks_cell(pt: Node, c: Vector2i) -> bool:
	for d: Node in pt._closed_doors():
		if d.has_method("occupies_cell") and d.occupies_cell(c):
			return true
		for cell: Variant in pt._door_cells(d):
			if cell == c:
				return true
	return false


static func has_wide_los(pt: Node, a: Node, b: Node) -> bool:
	if pt._door_between(a, b):
		return false
	if not pt._has_los(a, b):
		return false
	if not pt._is_bow():
		return true
	var w3: World3D = world3(pt)
	if w3 == null:
		return true
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var d: Vector3 = Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
	if d.length() < 0.001:
		return true
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	if not Combat.los(pa + perp, pb + perp, w3):
		return false
	if not Combat.los(pa - perp, pb - perp, w3):
		return false
	return true


static func has_los_from_wide(pt: Node, pos: Vector3, b: Node) -> bool:
	if not pt._has_los_from(pos, b):
		return false
	if not pt._is_bow():
		return true
	var w3: World3D = world3(pt)
	if w3 == null:
		return true
	var pb: Vector3 = (b as Node3D).global_position
	var d: Vector3 = Vector3(pb.x - pos.x, 0.0, pb.z - pos.z)
	if d.length() < 0.001:
		return true
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	return Combat.los(pos + perp, pb + perp, w3) and Combat.los(pos - perp, pb - perp, w3)


static func grid_dims(pt: Node) -> Dictionary:
	var dung: Node = pt._dungeon()
	if dung == null:
		return {}
	var data: Dictionary = dung.data
	return {"grid": data.grid, "w": int(data.w), "h": int(data.h)}


static func grid_floor(pt: Node, c: Vector2i) -> bool:
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty():
		return false
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return false
	return grid[c.y * w + c.x] == 1


static func door_cells(pt: Node, door: Node) -> Array:
	var out: Array = []
	if door == null:
		return out
	var occ: Variant = door.get("cells")
	if occ is Array and not (occ as Array).is_empty():
		for raw: Variant in occ:
			out.append(Vector2i(raw))
		return out
	out.append(pt._cell_of_node(door))
	return out


static func obstacle_cell(pt: Node, c: Vector2i) -> bool:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return false
	for g: Node in tree.get_nodes_in_group("gates"):
		if g and is_instance_valid(g) and not bool(g.get("open")) and pt._cell_of_node(g) == c:
			return true
	if pt._door_blocks_cell(c):
		return true
	for b: Node in tree.get_nodes_in_group("breakables"):
		if b and is_instance_valid(b) and pt._cell_of_node(b) == c:
			return true
	return false


static func prop_cell(pt: Node, c: Vector2i) -> bool:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k.ends_with("chest") or k.begins_with("clerk") or k.find("patty") >= 0 or k.find("misc") >= 0:
			if pt._cell_of_node(n) == c:
				return true
	for n2: Node in tree.get_nodes_in_group("gather"):
		if n2 and is_instance_valid(n2) and pt._cell_of_node(n2) == c:
			return true
	return false


static func floor_cell(pt: Node, _grid: PackedByteArray, _w: int, _h: int, c: Vector2i) -> bool:
	return pt._grid_floor(c) and not pt._obstacle_cell(c) and not pt._prop_cell(c)


static func steer_floor(pt: Node, c: Vector2i) -> bool:
	return pt._grid_floor(c) and not pt._obstacle_cell(c)


static func pos_walkable(pt: Node, pos: Vector3) -> bool:
	return pt._steer_floor(pt._cell_of_pos(pos))


static func dir_open(pt: Node, p: Node, dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return true
	var n: Vector2 = dir.normalized()
	if pt._dir_hits_door(p, n):
		return false
	var pos: Vector3 = (p as Node3D).global_position
	for t: float in [0.18, 0.34]:
		var q: Vector3 = Vector3(pos.x + n.x * t, pos.y, pos.z + n.y * t)
		if not pt._pos_walkable(q):
			return false
	return true


static func any_open(pt: Node, p: Node) -> Vector2:
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d: Vector2 in dirs:
		if pt._dir_open(p, d):
			return d
	return Vector2.ZERO


static func walk_clear(pt: Node, a: Node, b: Node) -> bool:
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty() or a == null or b == null:
		return false
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var s: Vector2i = pt._cell_of_pos((a as Node3D).global_position)
	var g: Vector2i = pt._stand_cell(a, b)
	var x: int = s.x
	var y: int = s.y
	var x1: int = g.x
	var y1: int = g.y
	var dx: int = absi(x1 - x)
	var dy: int = absi(y1 - y)
	var sx: int = 1 if x < x1 else -1
	var sy: int = 1 if y < y1 else -1
	var err: int = dx - dy
	var guard: int = 0
	while guard < 80:
		guard += 1
		if not pt._floor_cell(grid, w, h, Vector2i(x, y)):
			return false
		if x == x1 and y == y1:
			return true
		var e2: int = err * 2
		var step_x: bool = e2 > -dy
		var step_y: bool = e2 < dx
		if step_x and step_y:
			if not pt._floor_cell(grid, w, h, Vector2i(x + sx, y)):
				return false
			if not pt._floor_cell(grid, w, h, Vector2i(x, y + sy)):
				return false
			x += sx
			y += sy
			err += dx - dy
		elif step_x:
			x += sx
			err -= dy
		else:
			y += sy
			err += dx
	return false


static func stand_cell(pt: Node, p: Node, dest: Node) -> Vector2i:
	var raw: Vector2i = pt._cell_of_node(dest)
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var best: Vector2i = Vector2i(-999, -999)
	var best_d: int = 999
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = raw + n
		if not pt._steer_floor(c):
			continue
		if pt._prop_cell(c):
			continue
		var d: int = absi(c.x - here.x) + absi(c.y - here.y)
		if d < best_d:
			best_d = d
			best = c
	if best.x > -900:
		return best
	if pt._steer_floor(raw) and not pt._prop_cell(raw):
		return raw
	for n2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if pt._steer_floor(raw + n2) and not pt._prop_cell(raw + n2):
			return raw + n2
	return raw


static func closed_door(pt: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var p: Node = tree.get_first_node_in_group("player")
	var best: Node = null
	var best_d: float = 99999.0
	for d: Node in pt._closed_doors():
		var dd: float = pt._dist(p, d) if p else 0.0
		if dd < best_d:
			best_d = dd
			best = d
	return best


static func closed_doors(pt: Node) -> Array:
	var out: Array = []
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return out
	for d: Node in tree.get_nodes_in_group("boss_door"):
		if d and is_instance_valid(d) and not bool(d.get("open")):
			out.append(d)
	return out


static func near_closed_door(pt: Node, p: Node) -> bool:
	var d: Node = pt._closed_door()
	return d != null and pt._dist(p, d) < 1.85


static func dir_hits_door(pt: Node, p: Node, dir: Vector2) -> bool:
	if dir.length() < 0.05:
		return false
	var from: Vector3 = (p as Node3D).global_position
	var n: Vector2 = dir.normalized()
	var probes: PackedFloat32Array = PackedFloat32Array([0.55, 0.95, 1.25])
	for step: float in probes:
		var nxt: Vector3 = from + Vector3(n.x, 0.0, n.y) * step
		if pt._door_blocks_cell(pt._cell_of_pos(nxt)):
			return true
	return false


static func door_away(pt: Node, p: Node) -> Vector2:
	var d: Node = pt._closed_door()
	if d == null:
		return Vector2.ZERO
	return -pt._xz_to(p, d)


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
		var score: int = - to_boss * 3 - to_here
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


static func has_path(pt: Node, p: Node, dest: Node) -> bool:
	if dest == null:
		return false
	if pt._dist(p, dest) < 1.25:
		return true
	return not pt._astar(p, dest).is_empty()


static func follow_goal(pt: Node, p: Node, dest: Node) -> void:
	if dest == null:
		pt.move = pt._steer(p, Vector2.ZERO)
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
	pt.move = pt._steer(p, pt._follow_or_direct(p, dest))


static func follow_or_direct(pt: Node, p: Node, dest: Node) -> Vector2:
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = pt._astar(p, dest)
		pt.path_i = 0
	if pt.path.is_empty():
		return pt._step_dir(p, pt._xz_to(p, dest))
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	while pt.path_i < pt.path.size() and pt.path[pt.path_i] == here:
		pt.path_i += 1
	if pt.path_i >= pt.path.size():
		return Vector2.ZERO
	var c: Vector2i = pt.path[pt.path_i]
	var target: Vector2 = pt._clearance_target(c)
	var pos: Vector3 = (p as Node3D).global_position
	var d: Vector2 = Vector2(target.x - pos.x, target.y - pos.z)
	if d.length() < 0.28:
		pt.path_i += 1
		if pt.path_i >= pt.path.size():
			return Vector2.ZERO
		return pt._follow_or_direct(p, dest)
	if not pt._dir_open(p, d):
		return pt._step_dir(p, d)
	return d.normalized()


static func astar(pt: Node, p: Node, dest: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty() or dest == null:
		return out
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var goal: Vector2i = pt._stand_cell(p, dest)
	if not pt._steer_floor(start) or pt._prop_cell(start):
		for n: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if pt._steer_floor(start + n) and not pt._prop_cell(start + n):
				start += n
				break
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
	while not open.is_empty() and guard < 2500:
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
