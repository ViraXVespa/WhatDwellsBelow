extends Object

const Los := preload("res://scripts/debug/playtest_los.gd")
const Path := preload("res://scripts/debug/playtest_path.gd")


static func world3(pt: Node) -> World3D:
	return Los.world3(pt)

static func has_los(pt: Node, a: Node, b: Node) -> bool:
	return Los.has_los(pt, a, b)

static func has_los_from(pt: Node, pos: Vector3, b: Node) -> bool:
	return Los.has_los_from(pt, pos, b)

static func go_open_door(pt: Node, p: Node, gate: Node) -> void:
	Los.go_open_door(pt, p, gate)

static func door_between(pt: Node, a: Node, b: Node) -> bool:
	return Los.door_between(pt, a, b)

static func door_blocks_cell(pt: Node, c: Vector2i) -> bool:
	return Los.door_blocks_cell(pt, c)

static func has_wide_los(pt: Node, a: Node, b: Node) -> bool:
	return Los.has_wide_los(pt, a, b)

static func has_los_from_wide(pt: Node, pos: Vector3, b: Node) -> bool:
	return Los.has_los_from_wide(pt, pos, b)

static func grid_dims(pt: Node) -> Dictionary:
	return Los.grid_dims(pt)

static func grid_floor(pt: Node, c: Vector2i) -> bool:
	return Los.grid_floor(pt, c)

static func door_cells(pt: Node, door: Node) -> Array:
	return Los.door_cells(pt, door)

static func obstacle_cell(pt: Node, c: Vector2i) -> bool:
	return Los.obstacle_cell(pt, c)

static func prop_cell(pt: Node, c: Vector2i) -> bool:
	return Los.prop_cell(pt, c)

static func floor_cell(pt: Node, grid: PackedByteArray, w: int, h: int, c: Vector2i) -> bool:
	return Los.floor_cell(pt, grid, w, h, c)

static func steer_floor(pt: Node, c: Vector2i) -> bool:
	return Los.steer_floor(pt, c)

static func pos_walkable(pt: Node, pos: Vector3) -> bool:
	return Los.pos_walkable(pt, pos)

static func dir_open(pt: Node, p: Node, dir: Vector2) -> bool:
	return Los.dir_open(pt, p, dir)

static func any_open(pt: Node, p: Node) -> Vector2:
	return Los.any_open(pt, p)

static func walk_clear(pt: Node, a: Node, b: Node) -> bool:
	return Los.walk_clear(pt, a, b)

static func stand_cell(pt: Node, p: Node, dest: Node) -> Vector2i:
	return Los.stand_cell(pt, p, dest)

static func closed_door(pt: Node) -> Node:
	return Los.closed_door(pt)

static func closed_doors(pt: Node) -> Array:
	return Los.closed_doors(pt)

static func near_closed_door(pt: Node, p: Node) -> bool:
	return Los.near_closed_door(pt, p)

static func dir_hits_door(pt: Node, p: Node, dir: Vector2) -> bool:
	return Los.dir_hits_door(pt, p, dir)

static func door_away(pt: Node, p: Node) -> Vector2:
	return Los.door_away(pt, p)

static func door_bypass(pt: Node, p: Node, boss: Node) -> Vector2:
	return Path.door_bypass(pt, p, boss)

static func safe_step(pt: Node, p: Node, desired: Vector2) -> Vector2:
	return Path.safe_step(pt, p, desired)

static func los_reposition(pt: Node, p: Node, target: Node) -> Vector2:
	return Path.los_reposition(pt, p, target)

static func clearance_target(pt: Node, c: Vector2i) -> Vector2:
	return Path.clearance_target(pt, c)

static func wall_sep(pt: Node, p: Node) -> Vector2:
	return Path.wall_sep(pt, p)

static func steer(pt: Node, p: Node, desired: Vector2) -> Vector2:
	return Path.steer(pt, p, desired)

static func step_dir(pt: Node, p: Node, desired: Vector2) -> Vector2:
	return Path.step_dir(pt, p, desired)

static func has_path(pt: Node, p: Node, dest: Node) -> bool:
	return Path.has_path(pt, p, dest)

static func follow_goal(pt: Node, p: Node, dest: Node) -> void:
	Path.follow_goal(pt, p, dest)

static func follow_or_direct(pt: Node, p: Node, dest: Node) -> Vector2:
	return Path.follow_or_direct(pt, p, dest)

static func astar(pt: Node, p: Node, dest: Node) -> Array[Vector2i]:
	return Path.astar(pt, p, dest)
