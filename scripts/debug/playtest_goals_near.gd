extends Object

const SEE := 36.0
const ROOM := 11.0

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
