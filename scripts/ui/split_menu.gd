extends Object

const View := preload("res://scripts/ui/split_menu_view.gd")


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


static func preview(host: Node, i: int) -> void:
	var n: int = rows(host).size()
	if n <= 0:
		return
	host.selected = clampi(i, 0, n - 1)
	_sync_page(host)
	View.paint_list(host)
	View.apply_col(host)


static func _sync_page(host: Node) -> void:
	var row: Dictionary = current(host)
	if host.has_method("split_build_page"):
		host.split_build_page(str(row.get("id", "")))


static func list_pressed(host: Node, i: int) -> void:
	var same_open: bool = str(host.get("col")) == "detail" and int(host.get("selected")) == i
	preview(host, i)
	var row: Dictionary = row_at(host, i)
	if is_leaf(row):
		if host.has_method("split_activate_leaf"):
			host.split_activate_leaf(str(row.get("id", "")))
		return
	if same_open:
		enter_list(host)
		return
	enter_detail(host)


static func enter_detail(host: Node) -> void:
	var row: Dictionary = current(host)
	if not is_page(row):
		return
	host.col = "detail"
	View.apply_col(host)
	View.focus_col(host)


static func enter_list(host: Node) -> void:
	host.col = "list"
	View.apply_col(host)
	View.focus_col(host)


static func back(host: Node) -> bool:
	if str(host.get("col")) == "detail":
		enter_list(host)
		return true
	if host.has_method("split_close"):
		host.split_close()
	return false


static func rebuild(host: Node) -> void:
	View.rebuild_list(host)
	_sync_page(host)
	View.apply_col(host)
	View.focus_col(host)
