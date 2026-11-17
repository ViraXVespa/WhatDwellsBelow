extends Object

const REACH := 36
const Nav := preload("res://scripts/debug/playtest_path/path_nav.gd")
const Util := preload("res://scripts/debug/playtest_path/path_util.gd")

static func door_bypass(pt: PlayHost, p: Node, boss: Node) -> Vector2:
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

static func _back_along(pt: PlayHost, p: Node, pos: Vector3, here: Vector2i, cells: Array) -> Vector2:
	var i: int = cells.size() - 1
	while i >= 0:
		var c: Variant = cells[i]
		if c is Vector2i and (c as Vector2i) != here:
			var cell: Vector2i = c as Vector2i
			var step: Vector2 = Vector2(float(cell.x) + 0.5 - pos.x, float(cell.y) + 0.5 - pos.z)
			if step.length_squared() > 0.04 and pt._dir_open(p, step):
				return step.normalized()
		i -= 1
	return Vector2.ZERO

static func retreat_dir(pt: PlayHost, p: Node) -> Vector2:
	var pos: Vector3 = (p as Node3D).global_position
	var here: Vector2i = pt._cell_of_pos(pos)
	var crumb: Array = []
	if pt.has_meta("crumb") and pt.get_meta("crumb") is Array:
		crumb = pt.get_meta("crumb")
	var back: Vector2 = _back_along(pt, p, pos, here, crumb)
	if back != Vector2.ZERO:
		return back
	var trail: Array = []
	if pt.has_meta("trail") and pt.get_meta("trail") is Array:
		trail = pt.get_meta("trail")
	return _back_along(pt, p, pos, here, trail)

static func follow_goal(pt: PlayHost, p: Node, dest: Node) -> void:
	if dest == null:
		pt.move = pt._steer(p, Vector2.ZERO)
		return
	if pt._dist(p, dest) < 1.55 and not Util.seek_unreached(pt, p, dest):
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
		pt.move = Vector2.ZERO
		pt.aim = pt._xz_to(p, dest)
		return
	if pt._door_between(p, dest):
		pt._go_open_door(p, pt._closed_door())
		return
	if pt._near_closed_door(p):
		var gate: Node = pt._closed_door()
		if gate != null and pt._dist(gate, dest) < pt._dist(p, dest):
			pt._go_open_door(p, gate)
			return
	var cell_t: float = 0.0
	if pt.has_meta("cell_t"):
		cell_t = float(pt.get_meta("cell_t"))
	if pt.stuck_t > 0.7 or cell_t > 2.0:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
		var back: Vector2 = retreat_dir(pt, p)
		pt.move = pt._steer(p, back)
		pt.aim = back
		if pt.stuck_t > 1.0 and back != Vector2.ZERO:
			pt.dash = true
			pt.just["dash"] = true
		return
	if pt.path_goal != dest:
		pt.path.clear()
		pt.path_i = 0
		pt.path_goal = dest
	var step: Vector2 = Nav.follow_or_direct(pt, p, dest)
	pt.move = pt._steer(p, step)
	if step != Vector2.ZERO:
		pt.aim = step

static func wall_sep(pt: PlayHost, p: Node) -> Vector2:
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
