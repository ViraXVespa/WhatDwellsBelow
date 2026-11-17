extends Object

const REACH := 36
const Util := preload("res://scripts/debug/playtest_path/path_util.gd")
const Cache := preload("res://scripts/debug/playtest_los/los_cache.gd")
const Nav := preload("res://scripts/debug/playtest_path/path_nav.gd")
const Step := preload("res://scripts/debug/playtest_path/path_step.gd")

static func door_bypass(pt: PlayHost, p: Node, boss: Node) -> Vector2:
	return Step.door_bypass(pt, p, boss)

static func safe_step(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
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

static func los_reposition(pt: PlayHost, p: Node, target: Node) -> Vector2:
	return Nav.los_reposition(pt, p, target)

static func clearance_target(pt: PlayHost, c: Vector2i) -> Vector2:
	var t: Vector2 = Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
	var push: Vector2 = Vector2.ZERO
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not pt._steer_floor(c + n):
			push -= Vector2(float(n.x), float(n.y))
	if push.length() > 0.001:
		t += push.normalized() * 0.28
	return t

static func wall_sep(pt: PlayHost, p: Node) -> Vector2:
	return Step.wall_sep(pt, p)

static func hall_center(pt: PlayHost, p: Node) -> Vector2:
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
	return pull

static func gap_align(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return Vector2.ZERO
	var heading: Vector2 = desired.normalized()
	var ax: int = 0
	var ay: int = 0
	if absf(heading.x) >= absf(heading.y):
		ax = 1 if heading.x > 0.0 else -1
	else:
		ay = 1 if heading.y > 0.0 else -1
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var ahead: Vector2i = here + Vector2i(ax, ay)
	if not pt._steer_floor(ahead):
		return Vector2.ZERO
	var pos: Vector3 = (p as Node3D).global_position
	var slide: Vector2 = Vector2((float(ahead.x) + 0.5) - pos.x, (float(ahead.y) + 0.5) - pos.z)
	if ax != 0:
		slide.x = 0.0
	else:
		slide.y = 0.0
	if slide.length() < 0.05:
		return Vector2.ZERO
	if not pt._dir_open(p, slide):
		return Vector2.ZERO
	return slide.normalized()

static func _best_cardinal(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
	var heading: Vector2 = Vector2.ZERO
	if desired.length() > 0.001:
		heading = desired.normalized()
	var best: Vector2 = Vector2.ZERO
	var best_score: float = 0.15
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for d: Vector2 in dirs:
		if not pt._dir_open(p, d):
			continue
		var score: float = d.dot(heading)
		if score > best_score:
			best_score = score
			best = d
	return best

static func steer(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
	var heading: Vector2 = desired
	if heading.length() > 0.001:
		heading = heading.normalized()
		if not pt._dir_open(p, heading):
			var lined: Vector2 = gap_align(pt, p, heading)
			if lined != Vector2.ZERO:
				heading = lined
			else:
				heading = Vector2.ZERO
	var mid: Vector2 = hall_center(pt, p)
	var sep: Vector2 = pt._wall_sep(p)
	var out: Vector2 = heading * 1.0 + mid * 0.55 + sep * 0.28
	if out.length() < 0.001:
		out = mid if mid.length() > 0.001 else sep
	if out.length() < 0.001 or not pt._dir_open(p, out):
		var lined_out: Vector2 = gap_align(pt, p, desired)
		if lined_out != Vector2.ZERO and pt._dir_open(p, lined_out):
			out = lined_out
		else:
			out = _best_cardinal(pt, p, desired)
	return out.normalized() if out.length() > 0.001 else out

static func step_dir(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
	return Nav.step_dir(pt, p, desired)

static func has_path(pt: PlayHost, p: Node, dest: Node) -> bool:
	if dest == null:
		return false
	if pt._dist(p, dest) < 1.35:
		return true
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var goal: Vector2i = pt._stand_cell(p, dest)
	var md: int = Util._manh(start, goal)
	if md <= REACH:
		# Same (start, goal) asked again in this physics frame (hunt/clerk/chest/fight all test the same foe): reuse the answer.
		var key := Vector4i(start.x, start.y, goal.x, goal.y)
		var hit: Variant = Cache.path_get(pt, key)
		if hit != null:
			return bool(hit)
		var ok: bool = not Util.astar(pt, p, dest).is_empty()
		Cache.path_put(pt, key, ok)
		return ok
	var mid: Vector2i = Util._toward(pt, start, goal)
	return Util._manh(start, mid) >= 3

static func follow_goal(pt: PlayHost, p: Node, dest: Node) -> void:
	Step.follow_goal(pt, p, dest)

static func follow_or_direct(pt: PlayHost, p: Node, dest: Node) -> Vector2:
	return Nav.follow_or_direct(pt, p, dest)

static func _cut(pt: PlayHost, p: Node, dest: Node) -> Vector2:
	var cut: Vector2 = pt._xz_to(p, dest)
	if cut != Vector2.ZERO and pt._dir_open(p, cut):
		return cut
	var lined: Vector2 = gap_align(pt, p, cut)
	if lined != Vector2.ZERO:
		return lined
	if pt._dist(p, dest) > 1.7:
		var back: Vector2 = Step.retreat_dir(pt, p)
		if back != Vector2.ZERO:
			return back
	return Vector2.ZERO
