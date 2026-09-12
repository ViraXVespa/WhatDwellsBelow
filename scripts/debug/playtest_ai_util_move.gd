extends Object


static func _near_prop(pt: Node, p: Node, lim: float) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = lim
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n) or load("res://scripts/debug/playtest_ai_util.gd")._banned(pt, n):
			continue
		var k: String = str(n.get("kind"))
		if k.find("crystal") >= 0 or k == "vendor" or k == "shop":
			continue
		if n.get("used") == true:
			continue
		if (k == "mine" or k == "wood") and not load("res://scripts/debug/playtest_ai_util.gd").tool_ok(n):
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best



static func tick_motion(pt: Node, p: Node, delta: float) -> void:
	var pos: Vector3 = (p as Node3D).global_position
	if pt.last_pos.distance_to(pos) > 0.08:
		pt.moved = true
		pt.stuck_t = 0.0
	else:
		pt.stuck_t += delta
	pt.last_pos = pos
	var here: Vector2i = pt._cell_of_node(p)
	var prev_c: Vector2i = Vector2i(-999, -999)
	if pt.has_meta("stuck_cell"):
		prev_c = pt.get_meta("stuck_cell")
	if here == prev_c:
		pt.set_meta("cell_t", load("res://scripts/debug/playtest_ai_util.gd")._meta_f(pt, "cell_t", 0.0) + delta)
	else:
		pt.set_meta("stuck_cell", here)
		pt.set_meta("cell_t", 0.0)
		load("res://scripts/debug/playtest_ai_util.gd")._trail(pt, here)
		load("res://scripts/debug/playtest_ai_util.gd")._mark(pt, here)
	pt.set_meta("wander_hold", maxf(0.0, load("res://scripts/debug/playtest_ai_util.gd")._meta_f(pt, "wander_hold", 0.0) - delta))
	pt.set_meta("dash_cd", maxf(0.0, load("res://scripts/debug/playtest_ai_util.gd")._meta_f(pt, "dash_cd", 0.0) - delta))



static func do_unstick(pt: Node) -> void:
	load("res://scripts/debug/playtest_ai_util.gd")._ban(pt, load("res://scripts/debug/playtest_ai_util.gd")._meta_n(pt, "lock_n"))
	if pt.path_goal:
		load("res://scripts/debug/playtest_ai_util.gd")._ban(pt, pt.path_goal)
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)
	pt.set_meta("cell_t", 0.0)
	pt.set_meta("wander_hold", 0.0)
	if pt.has_meta("wander_cell"):
		pt.remove_meta("wander_cell")
	pt.path.clear()
	pt.path_goal = null
	pt.stuck_t = 0.0
	load("res://scripts/debug/playtest_ai_util.gd").want_dash(pt)



static func _pick_front(pt: Node, here: Vector2i, last: Vector2) -> Vector2i:
	var seen: Dictionary = load("res://scripts/debug/playtest_ai_util.gd")._seen(pt)
	var recent: Array = load("res://scripts/debug/playtest_ai_util.gd")._recent(pt)
	var best: Vector2i = here
	var best_s: float = -9999.0
	for dy: int in range(-7, 8):
		for dx: int in range(-7, 8):
			if dx == 0 and dy == 0:
				continue
			var c: Vector2i = here + Vector2i(dx, dy)
			if not pt._steer_floor(c):
				continue
			var md: int = absi(dx) + absi(dy)
			if md < 3:
				continue
			var visits: int = int(seen.get(c, 0))
			if recent.has(c):
				continue
			var open_n: int = load("res://scripts/debug/playtest_ai_util.gd")._openness(pt, c)
			if open_n <= 1:
				continue
			var s: float = float(open_n) * 5.0 - float(visits) * 6.0 + float(md) * 0.35
			if visits == 0:
				s += 16.0
			if last != Vector2.ZERO:
				var v: Vector2 = Vector2(float(dx), float(dy))
				s += v.normalized().dot(last) * 4.0
			if s > best_s:
				best_s = s
				best = c
	return best



static func wander(pt: Node, p: Node, _delta: float = 0.0) -> void:
	var here: Vector2i = pt._cell_of_node(p)
	load("res://scripts/debug/playtest_ai_util.gd")._mark(pt, here)
	load("res://scripts/debug/playtest_ai_util.gd")._trail(pt, here)
	var last: Vector2 = pt.wander_dir if pt.get("wander_dir") != null else Vector2.ZERO
	var dest: Vector2i = here
	if pt.has_meta("wander_cell"):
		dest = pt.get_meta("wander_cell")
	var need: bool = load("res://scripts/debug/playtest_ai_util.gd").spinning(pt) or load("res://scripts/debug/playtest_ai_util.gd")._meta_f(pt, "wander_hold", 0.0) <= 0.0
	if dest == here or absi(dest.x - here.x) + absi(dest.y - here.y) <= 1:
		need = true
	if need:
		dest = _pick_front(pt, here, last)
		pt.set_meta("wander_cell", dest)
		pt.set_meta("wander_hold", 2.8)
	var pos: Vector3 = (p as Node3D).global_position
	var tgt: Vector2 = Vector2(float(dest.x) + 0.5, float(dest.y) + 0.5)
	var heading: Vector2 = Vector2(tgt.x - pos.x, tgt.y - pos.z)
	if heading.length() < 0.12:
		pt.remove_meta("wander_cell")
		heading = last if last != Vector2.ZERO else pt._any_open(p)
	heading = heading.normalized()
	var drift: float = sin(pos.x * 1.7 + pos.z * 1.1) * 0.18
	var perp: Vector2 = Vector2(-heading.y, heading.x)
	var desired: Vector2 = (heading + perp * drift).normalized()
	if not pt._dir_open(p, desired):
		desired = heading
	if not pt._dir_open(p, desired):
		desired = pt._any_open(p)
	pt.wander_dir = heading
	pt.aim = heading
	pt.move = pt._steer(p, desired)
	pt.path.clear()
	pt.path_goal = null

