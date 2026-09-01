# Utility functions for PlaytestAI

const PlaytestLog := preload("res://scripts/debug/playtest_log.gd")
const NEAR := 22.0


static func weapon_range() -> float:
	var w: String = str(App.weapon)
	if w == "longbow":
		return maxf(2.4, float(App.bal.bow_range))
	if w == "staff":
		return maxf(1.05, float(App.bal.staff_range))
	return maxf(1.15, float(App.bal.axe_range))


static func is_boss(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.get("is_boss") == true:
		return true
	return n.is_in_group("boss")


static func alive_enemy(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("is_alive") and not n.is_alive():
		return false
	return true


static func notice_range(pt: Node) -> float:
	if pt._is_staff():
		return maxf(6.2, float(App.bal.staff_special_radius) + 4.0)
	if pt._is_bow():
		return maxf(6.0, float(App.bal.bow_range) + 0.4)
	return maxf(4.4, pt._weapon_range() + 1.6)


static func try_staff_special(pt: Node, d: float, los: bool) -> void:
	if not los or pt.spec_cd > 0.0:
		return
	if d < 1.45 or d > pt._staff_hold() + 1.8:
		return
	pt.special = true
	pt.just["special"] = true
	pt.spec_cd = 1.15


static func _meta_n(pt: Node, key: String) -> Node:
	if not pt.has_meta(key):
		return null
	var v: Variant = pt.get_meta(key)
	if v == null or not is_instance_valid(v):
		return null
	return v


static func _meta_f(pt: Node, key: String, fallback: float = 0.0) -> float:
	if not pt.has_meta(key):
		return fallback
	return float(pt.get_meta(key))


static func _lock(pt: Node, n: Node, sec: float = 3.2) -> void:
	pt.set_meta("lock_n", n)
	pt.set_meta("lock_t", sec)


static func _locked(pt: Node, delta: float) -> Node:
	var t: float = _meta_f(pt, "lock_t", 0.0) - delta
	pt.set_meta("lock_t", t)
	if t <= 0.0:
		if pt.has_meta("lock_n"):
			pt.remove_meta("lock_n")
		return null
	return _meta_n(pt, "lock_n")


static func _bans(pt: Node) -> Array:
	if not pt.has_meta("skip_list"):
		return []
	var a: Variant = pt.get_meta("skip_list")
	return a if a is Array else []


static func _banned(pt: Node, n: Node) -> bool:
	if n == null:
		return true
	return _bans(pt).has(n)


static func _ban(pt: Node, n: Variant) -> void:
	if n == null:
		return
	var a: Array = _bans(pt)
	if not a.has(n):
		a.append(n)
	if a.size() > 16:
		a.pop_front()
	pt.set_meta("skip_list", a)


static func _seen(pt: Node) -> Dictionary:
	if not pt.has_meta("seen_map"):
		return {}
	var a: Variant = pt.get_meta("seen_map")
	return a if a is Dictionary else {}


static func _mark(pt: Node, c: Vector2i) -> void:
	var m: Dictionary = _seen(pt)
	m[c] = true
	if m.size() > 120:
		var k: Variant = m.keys()[0]
		m.erase(k)
	pt.set_meta("seen_map", m)


static func tool_type() -> String:
	if App.prog:
		return str(App.prog.tool_type)
	return "pickaxe"


static func tool_ok(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var k: String = str(n.get("kind"))
	var tool: String = tool_type()
	if k == "wood":
		return tool == "hatchet"
	if k == "mine":
		return tool == "pickaxe"
	return true


static func is_clerk_kind(k: String) -> bool:
	return k.find("clerk") >= 0 or k.find("patty") >= 0 or k.find("misc") >= 0


static func is_loot_kind(k: String) -> bool:
	return k == "mine" or k == "wood" or k.find("chest") >= 0


static func is_use_kind(k: String) -> bool:
	return is_clerk_kind(k) or is_loot_kind(k) or k.find("stairs") >= 0 or k.find("door") >= 0


static func can_use(pt: Node, n: Node) -> bool:
	if n == null or not is_instance_valid(n) or _banned(pt, n):
		return false
	if n.get("used") == true:
		return false
	if is_loot_kind(str(n.get("kind"))) and not tool_ok(n):
		_ban(pt, n)
		return false
	return true


static func _near_prop(pt: Node, p: Node, lim: float) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var best: Node = null
	var best_d: float = lim
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n) or _banned(pt, n):
			continue
		var k: String = str(n.get("kind"))
		if k.find("crystal") >= 0 or k == "vendor" or k == "shop" or k == "receptionist":
			continue
		if n.get("used") == true:
			continue
		if (k == "mine" or k == "wood") and not tool_ok(n):
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
		pt.set_meta("cell_t", _meta_f(pt, "cell_t", 0.0) + delta)
	else:
		pt.set_meta("stuck_cell", here)
		pt.set_meta("cell_t", 0.0)
		_trail(pt, here)


static func _trail(pt: Node, c: Vector2i) -> void:
	var a: Array = []
	if pt.has_meta("trail") and pt.get_meta("trail") is Array:
		a = pt.get_meta("trail")
	if a.is_empty() or a[a.size() - 1] != c:
		a.append(c)
	if a.size() > 14:
		a.pop_front()
	pt.set_meta("trail", a)


static func _recent(pt: Node) -> Array:
	if pt.has_meta("trail") and pt.get_meta("trail") is Array:
		return pt.get_meta("trail")
	return []


static func at_prop(pt: Node, p: Node) -> bool:
	var n: Node = _meta_n(pt, "lock_n")
	if n == null or not is_instance_valid(n):
		n = pt.path_goal if pt.get("path_goal") else null
	if n == null or not is_instance_valid(n):
		return false
	return pt._dist(p, n) < 1.35


static func should_unstick(pt: Node, p: Node) -> bool:
	if at_prop(pt, p):
		return pt.stuck_t > 5.0
	return pt.stuck_t > 2.0 or _meta_f(pt, "cell_t", 0.0) > 2.2


static func do_unstick(pt: Node) -> void:
	_ban(pt, _meta_n(pt, "lock_n"))
	if pt.path_goal:
		_ban(pt, pt.path_goal)
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)
	pt.set_meta("cell_t", 0.0)
	pt.path.clear()
	pt.path_goal = null
	pt.stuck_t = 0.0
	pt.dash = true
	pt.just["dash"] = true


static func wander(pt: Node, p: Node) -> void:
	var here: Vector2i = pt._cell_of_node(p)
	_mark(pt, here)
	_trail(pt, here)
	var seen: Dictionary = _seen(pt)
	var recent: Array = _recent(pt)
	var last: Vector2 = pt.wander_dir if pt.get("wander_dir") != null else Vector2.ZERO
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var best: Vector2 = Vector2.ZERO
	var best_s: int = -999
	for n: Vector2i in dirs:
		var d: Vector2 = Vector2(float(n.x), float(n.y))
		var nxt: Vector2i = here + n
		if not pt._steer_floor(nxt):
			continue
		if not pt._dir_open(p, d):
			continue
		var s: int = 1
		if not seen.has(nxt):
			s += 12
		if recent.find(nxt) < 0:
			s += 6
		if last != Vector2.ZERO and d.dot(last) > 0.5:
			s += 2
		if last != Vector2.ZERO and d.dot(last) < -0.5:
			s -= 10
		if s > best_s:
			best_s = s
			best = d
	if best == Vector2.ZERO:
		best = pt._any_open(p)
	pt.wander_dir = best
	pt.aim = best
	pt.move = best
