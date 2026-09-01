# Utility functions for PlaytestLOS

const Combat := preload("res://scripts/combat/combat.gd")


static func world3(pt: Node) -> World3D:
	var tree: SceneTree = pt.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_viewport().world_3d


static func grid_dims(pt: Node) -> Dictionary:
	var dung: Node = pt._dungeon()
	if dung == null:
		return {}
	var data: Dictionary = dung.data
	return {"grid": data.grid, "w": int(data.w), "h": int(data.h)}


static func door_cells(pt: Node, door: Node) -> Array:
	var out: Array = []
	if door == null:
		return out
	var occ: Variant = door.get("cells")
	if occ is Array and not (occ as Array).is_empty():
		for raw: Variant in occ:
			out.append(Vector2i(raw))
		return out
	out.append(pt._cell_of_node(door))
	return out


static func obstacle_cell(pt: Node, c: Vector2i) -> bool:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return false
	for g: Node in tree.get_nodes_in_group("gates"):
		if g and is_instance_valid(g) and not bool(g.get("open")) and pt._cell_of_node(g) == c:
			return true
	if pt._door_blocks_cell(c):
		return true
	for b: Node in tree.get_nodes_in_group("breakables"):
		if b and is_instance_valid(b) and pt._cell_of_node(b) == c:
			return true
	return false


static func prop_cell(pt: Node, c: Vector2i) -> bool:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k.ends_with("chest") or k.begins_with("clerk") or k.find("patty") >= 0 or k.find("misc") >= 0:
			if pt._cell_of_node(n) == c:
				return true
	for n2: Node in tree.get_nodes_in_group("gather"):
		if n2 and is_instance_valid(n2) and pt._cell_of_node(n2) == c:
			return true
	return false


static func closed_doors(pt: Node) -> Array:
	var out: Array = []
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return out
	for d: Node in tree.get_nodes_in_group("boss_door"):
		if d and is_instance_valid(d) and not bool(d.get("open")):
			out.append(d)
	return out
