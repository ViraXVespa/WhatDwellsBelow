extends Object

## Playtest log field formatters. Host module is playtest_log_util.gd.


static func _util():
	return load("res://scripts/debug/playtest_log_util.gd")


static func near(pt: Node, p: Node, lim: float = 40.0) -> Array:
	var U = _util()
	var out: Array = []
	var tree: SceneTree = pt.get_tree()
	if tree == null or p == null:
		return out
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var d: float = pt._dist(p, n)
		if d > lim:
			continue
		var c: Vector2i = pt._cell_of_node(n)
		var k: String = str(n.get("kind"))
		var row: Array = [k, snappedf(d, 0.1), c.x, c.y]
		var flags: Dictionary = {}
		if n.get("used") == true:
			flags["used"] = 1
		if k == "mine" or k == "wood":
			flags["hits"] = int(n.get("hits"))
			if not U._kind_tool_ok(k):
				flags["tool"] = 0
		if U._banned_n(pt, n):
			flags["ban"] = 1
		if not flags.is_empty():
			row.append(flags)
		out.append(row)
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	if out.size() > 6:
		out.resize(6)
	return out


static func skip_hint(pt: Node, p: Node) -> String:
	var U = _util()
	if p == null or pt.get_tree() == null:
		return ""
	var best: Node = null
	var best_d: float = 8.0
	for n: Node in pt.get_tree().get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k.find("crystal") >= 0:
			continue
		var d: float = pt._dist(p, n)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return ""
	var kind: String = str(best.get("kind"))
	if U._banned_n(pt, best):
		return "banned:" + kind
	if best.get("used") == true:
		return "used:" + kind
	if (kind == "mine" or kind == "wood") and not U._kind_tool_ok(kind):
		return "wrong_tool:" + kind
	if (kind == "mine" or kind == "wood") and int(best.get("hits")) <= 0:
		return "hits0:" + kind
	return ""


static func lock_fields(pt: Node, p: Node) -> Dictionary:
	var U = _util()
	var out: Dictionary = {}
	if not pt.has_meta("lock_n"):
		return out
	var n: Variant = pt.get_meta("lock_n")
	if n == null or not is_instance_valid(n):
		return out
	var node: Node = n
	out["lock_k"] = str(node.get("kind"))
	out["lock_c"] = U._xy(pt, node)
	if p:
		out["lock_d"] = snappedf(pt._dist(p, node), 0.1)
	if pt.has_meta("lock_t"):
		out["lock_t"] = snappedf(float(pt.get_meta("lock_t")), 0.1)
	return out


static func path_fields(pt: Node) -> Dictionary:
	var out: Dictionary = {}
	var path: Variant = pt.get("path")
	if path == null or not (path is Array) or (path as Array).is_empty():
		return out
	var arr: Array = path
	var i: int = 0
	if pt.get("path_i") != null:
		i = clampi(int(pt.path_i), 0, arr.size() - 1)
	var a: Variant = arr[i]
	var b: Variant = arr[arr.size() - 1]
	if a is Vector2i:
		out["p0"] = [(a as Vector2i).x, (a as Vector2i).y]
	elif a is Vector2:
		out["p0"] = [int(round((a as Vector2).x)), int(round((a as Vector2).y))]
	if b is Vector2i:
		out["pe"] = [(b as Vector2i).x, (b as Vector2i).y]
	elif b is Vector2:
		out["pe"] = [int(round((b as Vector2).x)), int(round((b as Vector2).y))]
	out["pn"] = arr.size()
	return out
