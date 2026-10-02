extends Object

## Nearest valid node of a group under `radius` (strict <, first wins) that passes `ok(n) -> bool`.
## Playtest AI picker shared by goals_best, goals_near and util_move.

static func nearest(pt: Node, p: Node, group: String, radius: float, ok: Callable) -> Node:
	var best: Node = null
	var best_d: float = radius
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(group):
		if n == null or not is_instance_valid(n):
			continue
		if not ok.call(n):
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	return best
