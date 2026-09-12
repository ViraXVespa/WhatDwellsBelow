extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Util := preload("res://scripts/debug/playtest_los_util.gd")

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

static func pos_walkable(pt: Node, pos: Vector3) -> bool:
	if not pt._steer_floor(pt._cell_of_pos(pos)):
		return false
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	var space: PhysicsDirectSpaceState3D = w3.direct_space_state
	if space == null:
		return true
	var from: Vector3 = Vector3(pos.x, pos.y + 0.85, pos.z)
	var to: Vector3 = Vector3(pos.x, pos.y + 0.10, pos.z)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Variant = hit.get("collider")
	if col is CharacterBody3D:
		return true
	return false

static func has_los_from_wide(pt: Node, pos: Vector3, b: Node) -> bool:
	if not pt._has_los_from(pos, b):
		return false
	if not pt._is_bow():
		return true
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	var pb: Vector3 = (b as Node3D).global_position
	var d: Vector3 = Vector3(pb.x - pos.x, 0.0, pb.z - pos.z)
	if d.length() < 0.001:
		return true
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	return Combat.los(pos + perp, pb + perp, w3) and Combat.los(pos - perp, pb - perp, w3)
