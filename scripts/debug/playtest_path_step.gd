extends Object

const Util := preload("res://scripts/debug/playtest_path_util.gd")
const REACH := 36
const Nav := preload("res://scripts/debug/playtest_path_nav.gd")

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
	var step: Vector2 = Nav.follow_or_direct(pt, p, dest)
	if step != Vector2.ZERO and pt._dir_open(p, step):
		pt.move = pt._steer(p, step)
	else:
		pt.move = pt._safe_step(p, step)
	if step != Vector2.ZERO:
		pt.aim = step

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
