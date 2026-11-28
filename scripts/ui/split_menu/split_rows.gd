extends Object

## Split menu row reads (leaf: loads no script). The facade split_menu.gd and its view both use these.

static func rows(host: Node) -> Array:
	if host.has_method("split_rows"):
		return host.split_rows()
	return []

static func row_at(host: Node, i: int) -> Dictionary:
	var list: Array = rows(host)
	if i < 0 or i >= list.size():
		return {}
	var raw: Variant = list[i]
	if raw is Dictionary:
		return raw
	return {}

static func current(host: Node) -> Dictionary:
	return row_at(host, int(host.get("selected")))

static func is_page(row: Dictionary) -> bool:
	return str(row.get("kind", "page")) == "page"

static func is_leaf(row: Dictionary) -> bool:
	return str(row.get("kind", "")) == "leaf"
