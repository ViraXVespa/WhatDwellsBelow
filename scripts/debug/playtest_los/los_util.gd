# Utility functions for PlaytestLOS

const Cache := preload("res://scripts/debug/playtest_los/los_cache.gd")

static func world3(pt: Node) -> World3D:
	var tree: SceneTree = pt.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_viewport().world_3d

static func grid_dims(pt: Node) -> Dictionary:
	return Cache.dims(pt)

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

static func prop_cell(pt: Node, c: Vector2i) -> bool:
	if pt.get_tree() == null:
		return false
	return Cache.prop(pt, c)

static func closed_doors(pt: Node) -> Array:
	return Cache.doors(pt).duplicate()
