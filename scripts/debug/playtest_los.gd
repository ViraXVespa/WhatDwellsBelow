extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Util := preload("res://scripts/debug/playtest_los_util.gd")
const Walk := preload("res://scripts/debug/playtest_los_walk.gd")
const Door := preload("res://scripts/debug/playtest_los_door.gd")


static func world3(pt: Node) -> World3D:
	return Util.world3(pt)

static func grid_dims(pt: Node) -> Dictionary:
	return Util.grid_dims(pt)

static func door_cells(pt: Node, door: Node) -> Array:
	return Util.door_cells(pt, door)

static func obstacle_cell(pt: Node, c: Vector2i) -> bool:
	return Util.obstacle_cell(pt, c)

static func prop_cell(pt: Node, c: Vector2i) -> bool:
	return Util.prop_cell(pt, c)

static func closed_doors(pt: Node) -> Array:
	return Util.closed_doors(pt)

static func has_los(pt: Node, a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	return Combat.los((a as Node3D).global_position, (b as Node3D).global_position, w3)

static func has_los_from(pt: Node, pos: Vector3, b: Node) -> bool:
	if b == null:
		return false
	var w3: World3D = Util.world3(pt)
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
	return Walk.door_between(pt, a, b)

static func door_blocks_cell(pt: Node, c: Vector2i) -> bool:
	for d: Node in pt._closed_doors():
		if d.has_method("occupies_cell") and d.occupies_cell(c):
			return true
		for cell: Variant in pt._door_cells(d):
			if cell == c:
				return true
	return false

static func has_wide_los(pt: Node, a: Node, b: Node) -> bool:
	return Door.has_wide_los(pt, a, b)

static func has_los_from_wide(pt: Node, pos: Vector3, b: Node) -> bool:
	return Walk.has_los_from_wide(pt, pos, b)

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

static func floor_cell(pt: Node, _grid: PackedByteArray, _w: int, _h: int, c: Vector2i) -> bool:
	return pt._grid_floor(c) and not pt._obstacle_cell(c) and not pt._prop_cell(c)

static func steer_floor(pt: Node, c: Vector2i) -> bool:
	return pt._grid_floor(c) and not pt._obstacle_cell(c)

static func pos_walkable(pt: Node, pos: Vector3) -> bool:
	return Walk.pos_walkable(pt, pos)

static func dir_open(pt: Node, p: Node, dir: Vector2) -> bool:
	return Door.dir_open(pt, p, dir)

static func any_open(pt: Node, p: Node) -> Vector2:
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d: Vector2 in dirs:
		if pt._dir_open(p, d):
			return d
	return Vector2.ZERO

static func walk_clear(pt: Node, a: Node, b: Node) -> bool:
	return Walk.walk_clear(pt, a, b)

static func stand_cell(pt: Node, p: Node, dest: Node) -> Vector2i:
	return Walk.stand_cell(pt, p, dest)

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

static func near_closed_door(pt: Node, p: Node) -> bool:
	var d: Node = pt._closed_door()
	return d != null and pt._dist(p, d) < 1.85

static func dir_hits_door(pt: Node, p: Node, dir: Vector2) -> bool:
	return Door.dir_hits_door(pt, p, dir)

static func door_away(pt: Node, p: Node) -> Vector2:
	var d: Node = pt._closed_door()
	if d == null:
		return Vector2.ZERO
	return -pt._xz_to(p, d)
