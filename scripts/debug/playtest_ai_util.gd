extends Object

const NEAR := 22.0
const CRYSTAL_IN := 2.4
const CRYSTAL_OUT := 5.5


static func weapon_range() -> float:
	var w: String = str(App.weapon)
	if w == "longbow":
		return maxf(2.4, float(App.bal.bow_range))
	if w == "staff":
		return maxf(1.05, float(App.bal.staff_range))
	return maxf(1.15, float(App.bal.axe_range))


static func is_boss(n: Node) -> bool:
	return n != null and is_instance_valid(n) and (n.get("is_boss") == true or n.is_in_group("boss"))


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


static func try_bow_special(pt: Node, d: float, los: bool) -> void:
	if not pt._is_bow() or not los or pt.spec_cd > 0.0:
		return
	if d > pt._weapon_range() + 0.2:
		return
	pt.special = true
	pt.just["special"] = true
	pt.spec_cd = 1.2


static func try_axe_special(pt: Node, d: float, los: bool, enemy: Node) -> void:
	if not pt._is_axe() or not los or pt.spec_cd > 0.0:
		return
	var slam: float = float(App.bal.slam_radius) + 0.12
	if d > slam:
		return
	if not is_boss(enemy) and d > slam * 0.72:
		return
	pt.special = true
	pt.just["special"] = true
	pt.spec_cd = 1.1


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
	return n == null or _bans(pt).has(n)


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
	m[c] = int(m.get(c, 0)) + 1
	pt.set_meta("seen_map", m)


static func tool_type() -> String:
	return str(App.prog.tool_type) if App.prog else "pickaxe"


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


static func is_foe_lock(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.is_in_group("enemies"):
		return true
	var k: String = str(n.get("kind"))
	return k == "" or k.begins_with("<")


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
		_mark(pt, here)
	pt.set_meta("wander_hold", maxf(0.0, _meta_f(pt, "wander_hold", 0.0) - delta))
	pt.set_meta("dash_cd", maxf(0.0, _meta_f(pt, "dash_cd", 0.0) - delta))


static func _trail(pt: Node, c: Vector2i) -> void:
	var a: Array = []
	if pt.has_meta("trail") and pt.get_meta("trail") is Array:
		a = pt.get_meta("trail")
	if a.is_empty() or a[a.size() - 1] != c:
		a.append(c)
	if a.size() > 22:
		a.pop_front()
	pt.set_meta("trail", a)


static func _recent(pt: Node) -> Array:
	if pt.has_meta("trail") and pt.get_meta("trail") is Array:
		return pt.get_meta("trail")
	return []


static func spinning(pt: Node) -> bool:
	var a: Array = _recent(pt)
	if a.size() < 4:
		return false
	var n: int = a.size()
	return a[n - 1] == a[n - 3] and a[n - 2] == a[n - 4] and a[n - 1] != a[n - 2]


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
	if spinning(pt) and pt.stuck_t > 0.4:
		return true
	return pt.stuck_t > 1.6 or _meta_f(pt, "cell_t", 0.0) > 1.8


static func want_dash(pt: Node) -> bool:
	if _meta_f(pt, "dash_cd", 0.0) > 0.0:
		return false
	pt.set_meta("dash_cd", 0.85)
	pt.dash = true
	pt.just["dash"] = true
	return true


static func do_unstick(pt: Node) -> void:
	_ban(pt, _meta_n(pt, "lock_n"))
	if pt.path_goal:
		_ban(pt, pt.path_goal)
	if pt.has_meta("lock_n"):
		pt.remove_meta("lock_n")
	pt.set_meta("lock_t", 0.0)
	pt.set_meta("cell_t", 0.0)
	pt.set_meta("wander_hold", 0.0)
	pt.path.clear()
	pt.path_goal = null
	pt.stuck_t = 0.0
	want_dash(pt)


static func stop_gather(p: Node) -> void:
	if p == null:
		return
	if p.get("gathering") != null:
		p.set("gathering", null)
	if p.has_method("stop_gather"):
		p.call("stop_gather")


static func note_threat(pt: Node, p: Node, enemy: Node) -> void:
	var d: float = 99.0
	if enemy != null and is_instance_valid(enemy) and p != null:
		d = pt._dist(p, enemy)
	pt.set_meta("log_threat_d", d)


static func really_extracted() -> bool:
	if not App.extracted:
		return false
	if App.tel != null and float(App.tel.clerk_t) >= 0.0:
		return true
	return false


static func _front(seen: Dictionary, here: Vector2i, step: Vector2i) -> int:
	var s: int = 0
	var side: Vector2i = Vector2i(-step.y, step.x)
	for i: int in range(1, 4):
		var c: Vector2i = here + step * i
		if int(seen.get(c, 0)) == 0:
			s += 3
		else:
			s -= int(seen.get(c, 0))
		if int(seen.get(c + side, 0)) == 0:
			s += 1
		if int(seen.get(c - side, 0)) == 0:
			s += 1
	return s


static func wander(pt: Node, p: Node, _delta: float = 0.0) -> void:
	var here: Vector2i = pt._cell_of_node(p)
	_mark(pt, here)
	_trail(pt, here)
	var seen: Dictionary = _seen(pt)
	var recent: Array = _recent(pt)
	var last: Vector2 = pt.wander_dir if pt.get("wander_dir") != null else Vector2.ZERO
	var spin: bool = spinning(pt)
	if (not spin) and _meta_f(pt, "wander_hold", 0.0) > 0.0 and last != Vector2.ZERO and pt._dir_open(p, last):
		var nxt_h: Vector2i = here + Vector2i(int(signf(last.x)), int(signf(last.y)))
		if recent.find(nxt_h) < 0 or int(seen.get(nxt_h, 0)) < 2:
			pt.aim = last
			pt.move = last
			return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var best: Vector2 = Vector2.ZERO
	var best_s: int = -9999
	for n: Vector2i in dirs:
		var d: Vector2 = Vector2(float(n.x), float(n.y))
		var nxt: Vector2i = here + n
		if pt.has_method("_steer_floor") and not pt._steer_floor(nxt):
			continue
		if not pt._dir_open(p, d):
			continue
		var visits: int = int(seen.get(nxt, 0))
		var s: int = _front(seen, here, n) - visits * 6
		var ri: int = recent.find(nxt)
		if ri >= 0 and ri >= recent.size() - 8:
			s -= 24
		elif visits == 0:
			s += 14
		if last != Vector2.ZERO and d.dot(last) > 0.5:
			s += 8
		if last != Vector2.ZERO and d.dot(last) < -0.5:
			s -= 30
		if spin and d.dot(last) > 0.1:
			s -= 12
		if s > best_s:
			best_s = s
			best = d
	if best == Vector2.ZERO:
		best = pt._any_open(p)
	pt.wander_dir = best
	pt.aim = best
	pt.move = best
	pt.set_meta("wander_hold", 1.6 if spin else 2.2)
	pt.path.clear()
	pt.path_goal = null
