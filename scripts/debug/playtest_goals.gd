extends Object

const SEE := 36.0
const ROOM := 11.0


static func world_ui(pt: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var s: Node = tree.current_scene
	if s and s.has_method("world_ui"):
		return s.world_ui()
	return null


static func role_has_cargo(pt: Node, role: String) -> bool:
	if role == "gather":
		return pt._gather_cargo() > 0
	if role == "misc":
		return pt._misc_cargo() > 0
	if role == "patty" or role == "gate":
		return (pt._gather_cargo() + pt._misc_cargo()) > 0
	return false


static func dismiss_world_ui(pt: Node) -> bool:
	var w: Node = pt._world_ui()
	if w == null or not bool(w.get("open")):
		if not App.ui_open:
			return false
		w = pt._world_ui()
		if w == null:
			App.ui_open = false
			if pt.get_tree():
				pt.get_tree().paused = false
			return false
	var mode: String = str(w.get("mode"))
	if mode == "extract":
		var role: String = str(w.get("extract_role"))
		if pt._role_has_cargo(role):
			App.note_clerk()
			App.prog.extract_all(role)
		if w.has_method("close_ui"):
			w.close_ui()
		return true
	if w.has_method("close_ui"):
		w.close_ui()
		return true
	return false


static func nearest_visible_threat(pt: Node, p: Node) -> Node:
	var best: Node = null
	var best_d: float = maxf(pt._notice_range(), 8.0)
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(n):
			continue
		var d: float = pt._dist(p, n)
		if d >= best_d:
			continue
		if pt._is_boss(n) and d > 6.5:
			continue
		if pt._door_between(p, n):
			continue
		if not pt._has_los(p, n):
			continue
		best_d = d
		best = n
	return best


static func nearest_room_threat(pt: Node, p: Node, radius: float = ROOM) -> Node:
	var best: Node = null
	var best_d: float = radius
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(n):
			continue
		var d: float = pt._dist(p, n)
		if d >= best_d:
			continue
		if pt._door_between(p, n):
			continue
		best_d = d
		best = n
	return best


static func nearest_foe(pt: Node, p: Node) -> Node:
	var seen: Node = nearest_visible_threat(pt, p)
	if seen:
		return seen
	return nearest_room_threat(pt, p)


static func nearest_hunt(pt: Node, p: Node) -> Node:
	var best: Node = null
	var best_d: float = 14.0
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(n):
			continue
		var d: float = pt._dist(p, n)
		if pt._is_boss(n):
			if d > 10.0:
				continue
		elif d > best_d:
			continue
		if pt._door_between(p, n):
			continue
		if pt._has_los(p, n):
			continue
		var score: float = d
		if pt._is_boss(n):
			score -= 1.5
		if score < best_d:
			best_d = score
			best = n
	if best and not pt._has_path(p, best):
		return null
	return best


static func nearest_boss(pt: Node, p: Node) -> Node:
	var best: Node = null
	var best_d: float = 10.0
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(n) or not pt._is_boss(n):
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


static func closest_kind(pt: Node, p: Node, kind: String, radius: float) -> Node:
	var best: Node = null
	var best_d: float = radius
	var tree: SceneTree = p.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")) != kind:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best


static func away_open(pt: Node, p: Node, node: Node) -> Vector2:
	var away: Vector2 = -pt._xz_to(p, node)
	if away.length() < 0.05:
		away = Vector2.RIGHT
	var tried: Array[Vector2] = [
		away,
		Vector2(-away.y, away.x),
		Vector2(away.y, -away.x),
	]
	for raw: Vector2 in tried:
		var stepped: Vector2 = pt._safe_step(p, raw)
		if stepped.length() >= 0.35 and stepped.dot(away) >= 0.12:
			return stepped
	return Vector2.ZERO


static func mail_at(pt: Node, clerk: Node) -> void:
	if clerk == null or pt._is_chest(clerk):
		return
	var role: String = pt._clerk_role(clerk)
	if role == "" or not pt._clerk_accepts(clerk):
		return
	App.note_clerk()
	App.prog.extract_all(role)
	var ui: Node = pt._world_ui()
	if ui and bool(ui.get("open")) and ui.has_method("close_ui"):
		ui.close_ui()


static func clerk_role(n: Node) -> String:
	var k: String = str(n.get("kind"))
	if k == "extract_gate":
		return "gate"
	if k.find("patty") >= 0:
		return "patty"
	if k.find("misc") >= 0:
		return "misc"
	if k.begins_with("clerk"):
		return "gather"
	return ""


static func gather_cargo() -> int:
	var root_n: int = 0
	if App.prog:
		root_n = int(App.prog.root)
	return App.ore + App.wood + root_n


static func misc_cargo() -> int:
	var n: int = App.gold
	if App.prog == null:
		return n
	for it: Variant in App.prog.bag:
		if it is Dictionary and it.get("extract") == true and str(it.get("kind", "")) != "artifact" and str(it.get("kind", "")) != "tool" and it.get("hold") != true:
			n += 1
	return n


static func clerk_accepts(pt: Node, n: Node) -> bool:
	var role: String = pt._clerk_role(n)
	if role == "gather":
		return pt._gather_cargo() > 0
	if role == "misc":
		return pt._misc_cargo() > 0
	if role == "patty" or role == "gate":
		return (pt._gather_cargo() + pt._misc_cargo()) > 0
	return false


static func best_clerk(pt: Node, p: Node) -> Node:
	var best: Node = null
	var best_d: float = SEE
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k == "vendor" or k == "shop" or k == "receptionist":
			continue
		if pt._clerk_role(n) == "":
			continue
		if not pt._clerk_accepts(n):
			continue
		var d: float = pt._dist(p, n)
		if pt._clerk_role(n) == "patty" and pt._gather_cargo() > 0 and pt._misc_cargo() > 0:
			d *= 0.55
		if d < best_d:
			best_d = d
			best = n
	if best and not pt._has_path(p, best):
		return null
	return best


static func best_gather(pt: Node, p: Node) -> Node:
	if pt._gather_cargo() >= 8:
		return null
	var tool: String = str(App.prog.tool_type) if App.prog else "pickaxe"
	var best: Node = null
	var best_d: float = SEE
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("gather"):
		if n == null or not is_instance_valid(n):
			continue
		if int(n.get("hits")) <= 0:
			continue
		var k: String = str(n.get("kind"))
		if k == "wood" and tool != "hatchet":
			continue
		if k != "wood" and tool != "pickaxe":
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best and not pt._has_path(p, best):
		return null
	return best


static func best_chest(pt: Node, p: Node) -> Node:
	var best: Node = null
	var best_d: float = 18.0
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if not pt._is_chest(n) or n.get("used") == true:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best and not pt._has_path(p, best):
		return null
	return best


static func reachable_kind(pt: Node, p: Node, prefix: String) -> Node:
	var best: Node = null
	var best_d: float = SEE
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("kind")).find(prefix) < 0:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best and not pt._has_path(p, best):
		return null
	return best


static func crowd(pt: Node, p: Node) -> int:
	var n_hit: int = 0
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return 0
	for e: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(e) or pt._is_boss(e):
			continue
		if pt._dist(p, e) <= 2.4 and pt._has_los(p, e):
			n_hit += 1
	return n_hit


static func dist(a: Node, b: Node) -> float:
	if a == null or b == null:
		return 999.0
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	return Vector2(pa.x - pb.x, pa.z - pb.z).length()


static func xz_to(a: Node, b: Node) -> Vector2:
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var v: Vector2 = Vector2(pb.x - pa.x, pb.z - pa.z)
	if v.length() < 0.001:
		return Vector2.DOWN
	return v.normalized()


static func dungeon(pt: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var s: Node = tree.current_scene
	if s and s.get("data") != null:
		return s
	return null
