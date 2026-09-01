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
		if k.find("crystal") >= 0:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best
