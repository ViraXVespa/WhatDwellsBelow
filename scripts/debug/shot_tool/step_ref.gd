extends RefCounted

## Shot flow target paths: "App.gold", "host.ui.mode", "kind:receptionist.prompt", "group:player.hp".
## First token picks the root (autoload name, host, kind:K, group:G, node:Path); the rest are properties,
## child nodes, dictionary keys or [index]. Values from JSON are cleaned (integral floats become ints).

static func clean(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1.0e9:
		return int(v)
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(clean(x))
		return out
	return v

static func find_kind(host: Node, kind: String) -> Node:
	for n: Node in host.find_children("*", "Node3D", true, false):
		if "kind" in n and str(n.get("kind")) == kind:
			return n
	return null

static func _root(host: Node, token: String) -> Variant:
	if token == "host":
		return host
	if token.begins_with("kind:"):
		return find_kind(host, token.substr(5))
	if token.begins_with("group:"):
		return host.get_tree().get_first_node_in_group(token.substr(6))
	if token.begins_with("node:"):
		return host.get_node_or_null(token.substr(5))
	return host.get_tree().root.get_node_or_null(token)

static func _step(cur: Variant, seg: String) -> Variant:
	if cur is Dictionary:
		return (cur as Dictionary).get(seg, null)
	if cur is Array:
		var a: Array = cur
		var i: int = seg.to_int()
		return a[i] if i >= 0 and i < a.size() else null
	if cur is Object and is_instance_valid(cur):
		var o: Object = cur
		var v: Variant = o.get(seg)
		if v == null and seg == "ui" and o.has_method("world_ui"):
			return o.call("world_ui")
		if v == null and o is Node:
			return (o as Node).get_node_or_null(seg)
		return v
	return null

static func tokens(expr: String) -> PackedStringArray:
	return expr.replace("[", ".").replace("]", "").split(".", false)

static func get_value(host: Node, expr: String) -> Variant:
	var parts: PackedStringArray = tokens(expr)
	if parts.is_empty():
		return null
	var cur: Variant = _root(host, parts[0])
	var i: int = 1
	while i < parts.size() and cur != null:
		cur = _step(cur, parts[i])
		i += 1
	return cur

static func set_value(host: Node, expr: String, value: Variant) -> bool:
	var parts: PackedStringArray = tokens(expr)
	if parts.size() < 2:
		return false
	var last: String = parts[parts.size() - 1]
	var owner_v: Variant = get_value(host, ".".join(parts.slice(0, parts.size() - 1)))
	var want: Variant = clean(value)
	if owner_v is Dictionary:
		(owner_v as Dictionary)[last] = want
		return true
	if owner_v is Object and is_instance_valid(owner_v):
		var o: Object = owner_v
		if typeof(o.get(last)) == TYPE_FLOAT and want is int:
			want = float(want)
		o.set(last, want)
		return true
	return false

static func call_value(host: Node, expr: String, method: String, args: Array) -> Variant:
	var target: Variant = get_value(host, expr)
	if not (target is Object) or not is_instance_valid(target):
		return null
	var o: Object = target
	if not o.has_method(method):
		return null
	return o.callv(method, clean(args))
