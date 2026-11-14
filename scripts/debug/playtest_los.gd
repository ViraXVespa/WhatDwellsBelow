extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Util := preload("res://scripts/debug/playtest_los/los_util.gd")
const Walk := preload("res://scripts/debug/playtest_los/los_walk.gd")
const Door := preload("res://scripts/debug/playtest_los/los_door.gd")
const Cache := preload("res://scripts/debug/playtest_los/los_cache.gd")

static func grid_dims(pt: PlayHost) -> Dictionary:
	return Util.grid_dims(pt)

static func door_cells(pt: PlayHost, door: Node) -> Array:
	return Util.door_cells(pt, door)

static func prop_cell(pt: PlayHost, c: Vector2i) -> bool:
	return Util.prop_cell(pt, c)

static func closed_doors(pt: PlayHost) -> Array:
	return Util.closed_doors(pt)

static func has_los(pt: PlayHost, a: Node, b: Node) -> bool:
	if a == null or b == null:
		return false
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	return Combat.los((a as Node3D).global_position, (b as Node3D).global_position, w3)

static func has_los_from(pt: PlayHost, pos: Vector3, b: Node) -> bool:
	if b == null:
		return false
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	return Combat.los(pos, (b as Node3D).global_position, w3)

static func go_open_door(pt: PlayHost, p: Node, gate: Node) -> void:
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

static func door_between(pt: PlayHost, a: Node, b: Node) -> bool:
	return Walk.door_between(pt, a, b)

static func door_blocks_cell(pt: PlayHost, c: Vector2i) -> bool:
	return Cache.door_blocks(pt, c)

static func has_wide_los(pt: PlayHost, a: Node, b: Node) -> bool:
	return Door.has_wide_los(pt, a, b)

static func has_los_from_wide(pt: PlayHost, pos: Vector3, b: Node) -> bool:
	return Walk.has_los_from_wide(pt, pos, b)

static func floor_cell(pt: PlayHost, _grid: PackedByteArray, _w: int, _h: int, c: Vector2i) -> bool:
	return Cache.floor_cell(pt, c)

static func steer_floor(pt: PlayHost, c: Vector2i) -> bool:
	return Cache.steer_floor(pt, c)

static func pos_walkable(pt: PlayHost, pos: Vector3) -> bool:
	return Walk.pos_walkable(pt, pos)

static func dir_open(pt: PlayHost, p: Node, dir: Vector2) -> bool:
	return Door.dir_open(pt, p, dir)

static func any_open(pt: PlayHost, p: Node) -> Vector2:
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d: Vector2 in dirs:
		if pt._dir_open(p, d):
			return d
	return Vector2.ZERO

static func walk_clear(pt: PlayHost, a: Node, b: Node) -> bool:
	return Walk.walk_clear(pt, a, b)

static func stand_cell(pt: PlayHost, p: Node, dest: Node) -> Vector2i:
	return Walk.stand_cell(pt, p, dest)

static func closed_door(pt: PlayHost) -> Node:
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

static func near_closed_door(pt: PlayHost, p: Node) -> bool:
	var d: Node = pt._closed_door()
	return d != null and pt._dist(p, d) < 1.85

static func dir_hits_door(pt: PlayHost, p: Node, dir: Vector2) -> bool:
	return Door.dir_hits_door(pt, p, dir)

static func door_away(pt: PlayHost, p: Node) -> Vector2:
	var d: Node = pt._closed_door()
	if d == null:
		return Vector2.ZERO
	return -pt._xz_to(p, d)
