extends Object

const Util := preload("res://scripts/debug/playtest_path/path_util.gd")
const REACH := 36

static func follow_or_direct(pt: PlayHost, p: Node, dest: Node) -> Vector2:
	var _fac = load("res://scripts/debug/playtest_path.gd")
	var known_only: bool = dest != null and str(dest.name) == "CampaignSeekMark"
	if pt._dist(p, dest) < 1.55 and not Util.seek_unreached(pt, p, dest):
		pt.path.clear()
		return Vector2.ZERO
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = Util.astar(pt, p, dest, known_only)
		pt.path_i = 0
	if pt.path.is_empty() or pt.path.size() <= 1:
		return _fac._cut(pt, p, dest)
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var i: int = pt.path_i
	while i < pt.path.size():
		if pt.path[i] == here:
			pt.path_i = i + 1
			break
		i += 1
	if pt.path.is_empty() or pt.path_i >= pt.path.size():
		pt.path = Util.astar(pt, p, dest, known_only)
		pt.path_i = 0
	if pt.path.is_empty() or pt.path.size() <= 1:
		return _fac._cut(pt, p, dest)
	while pt.path_i < pt.path.size() and pt.path[pt.path_i] == here:
		pt.path_i += 1
	if pt.path_i >= pt.path.size():
		pt.path.clear()
		return _fac._cut(pt, p, dest)
	var aim_i: int = pt.path_i
	var last_ok: int = aim_i
	var cap: int = mini(pt.path.size() - 1, pt.path_i + 5)
	while aim_i <= cap:
		var ac: Vector2i = pt.path[aim_i]
		var av: Vector2 = Vector2(float(ac.x) + 0.5, float(ac.y) + 0.5)
		var pos: Vector3 = (p as Node3D).global_position
		var dir: Vector2 = Vector2(av.x - pos.x, av.y - pos.z)
		if dir.length() < 0.08 or not pt._dir_open(p, dir):
			break
		last_ok = aim_i
		aim_i += 1
	var c: Vector2i = pt.path[last_ok]
	var t: Vector2 = pt._clearance_target(c)
	var pos2: Vector3 = (p as Node3D).global_position
	var step: Vector2 = Vector2(t.x - pos2.x, t.y - pos2.z)
	if step.length() < 0.08:
		pt.path_i = last_ok + 1
		return follow_or_direct(pt, p, dest)
	if not pt._dir_open(p, step):
		return pt._step_dir(p, step)
	return step.normalized()

static func los_reposition(pt: PlayHost, p: Node, target: Node) -> Vector2:
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

static func step_dir(pt: PlayHost, p: Node, desired: Vector2) -> Vector2:
	if desired.length() < 0.001:
		return pt._steer(p, Vector2.ZERO)
	desired = desired.normalized()
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var ax: int = 0
	var ay: int = 0
	if absf(desired.x) >= absf(desired.y):
		ax = 1 if desired.x > 0.0 else -1
	else:
		ay = 1 if desired.y > 0.0 else -1
	var primary: Vector2 = Vector2(float(ax), float(ay))
	var ahead: Vector2i = here + Vector2i(ax, ay)
	var fac: GDScript = load("res://scripts/debug/playtest_path.gd") as GDScript
	if pt._steer_floor(ahead):
		if pt._dir_open(p, primary):
			return pt._steer(p, primary)
		var gap: Vector2 = fac.gap_align(pt, p, primary)
		if gap != Vector2.ZERO:
			return gap
		return Vector2.ZERO
	var best: Vector2 = Vector2.ZERO
	var best_score: float = 0.2
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for n: Vector2i in dirs:
		var nxt: Vector2i = here + n
		if not pt._steer_floor(nxt):
			continue
		var dir: Vector2 = Vector2(float(n.x), float(n.y)).normalized()
		if not pt._dir_open(p, dir):
			continue
		var score: float = dir.dot(desired)
		if score > best_score:
			best_score = score
			best = dir
	if best == Vector2.ZERO:
		return Vector2.ZERO
	return pt._steer(p, best)
