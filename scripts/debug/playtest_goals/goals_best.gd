extends Object

const SEE := 36.0
const ROOM := 11.0
const Pick := preload("res://scripts/debug/playtest_goals/pick.gd")

static func best_chest(pt: Node, p: Node) -> Node:
	var best: Node = Pick.nearest(pt, p, "interact", 18.0, func(n: Node) -> bool: return pt._is_chest(n) and n.get("used") != true)
	if best and not pt._has_path(p, best):
		return null
	return best

static func closest_kind(pt: Node, p: Node, kind: String, radius: float) -> Node:
	return Pick.nearest(pt, p, "interact", radius, func(n: Node) -> bool: return str(n.get("kind")) == kind)

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
