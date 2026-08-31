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
