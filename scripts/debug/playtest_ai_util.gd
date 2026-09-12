extends Object

const Move := preload("res://scripts/debug/playtest_ai_util_move.gd")

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
	return not (n.has_method("is_alive") and not n.is_alive())



static func notice_range(pt: Node) -> float:
	if pt._is_staff():
		return maxf(6.2, float(App.bal.staff_special_radius) + 4.0)
	if pt._is_bow():
		return maxf(6.0, float(App.bal.bow_range) + 0.4)
	return maxf(4.4, pt._weapon_range() + 1.6)



static func _spec(pt: Node, cd: float) -> void:
	pt.special = true
	pt.just["special"] = true
	pt.spec_cd = cd



static func try_staff_special(pt: Node, d: float, los: bool) -> void:
	if los and pt.spec_cd <= 0.0 and d >= 1.45 and d <= pt._staff_hold() + 1.8:
		_spec(pt, 1.15)



static func try_bow_special(pt: Node, d: float, los: bool) -> void:
	if pt._is_bow() and los and pt.spec_cd <= 0.0 and d <= pt._weapon_range() + 0.2:
		_spec(pt, 1.2)



static func try_axe_special(pt: Node, d: float, los: bool, enemy: Node) -> void:
	if not pt._is_axe() or not los or pt.spec_cd > 0.0:
		return
	var slam: float = float(App.bal.slam_radius) + 0.12
	if d <= slam and (is_boss(enemy) or d <= slam * 0.72):
		_spec(pt, 1.1)



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
	return k == "extract_gate" or k.find("clerk") >= 0 or k.find("patty") >= 0 or k.find("misc") >= 0



static func is_loot_kind(k: String) -> bool:
	return k == "mine" or k == "wood" or k.find("chest") >= 0



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
	return Move._near_prop(pt, p, lim)

static func tick_motion(pt: Node, p: Node, delta: float) -> void:
	Move.tick_motion(pt, p, delta)

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
	if n == null:
		n = pt.path_goal if pt.get("path_goal") else null
	return n != null and is_instance_valid(n) and pt._dist(p, n) < 1.35



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
	Move.do_unstick(pt)

static func stop_gather(p: Node) -> void:
	if p == null:
		return
	if p.get("gathering") != null:
		p.set("gathering", null)



static func note_threat(pt: Node, p: Node, enemy: Node) -> void:
	pt.set_meta("log_threat_d", pt._dist(p, enemy) if enemy != null and is_instance_valid(enemy) and p != null else 99.0)



static func really_extracted() -> bool:
	return App.extracted and App.tel != null and float(App.tel.clerk_t) >= 0.0



static func _openness(pt: Node, c: Vector2i) -> int:
	var n: int = 0
	for s: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if pt._steer_floor(c + s):
			n += 1
	return n



static func _pick_front(pt: Node, here: Vector2i, last: Vector2) -> Vector2i:
	return Move._pick_front(pt, here, last)

static func wander(pt: Node, p: Node, _delta: float = 0.0) -> void:
	Move.wander(pt, p, _delta)

