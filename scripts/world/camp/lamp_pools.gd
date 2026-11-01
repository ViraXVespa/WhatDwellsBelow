extends Object

## Hub lantern pools (light_rt/pools.gd): one source per "hub_lamp" at its flame (the hung lantern when there is
## one), facing out of its face, cut above its awning hem; the guild/reception/stall body boxes occlude.

const Pools := preload("res://scripts/graphics/light_rt/pools.gd")
const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")

static func apply(root: Node, mats: Array) -> int:
	var rows: Array = []
	for lamp: Node in root.get_tree().get_nodes_in_group("hub_lamp"):
		var n := lamp as Node3D
		var flame: Node3D = n.get_meta("flame", n) as Node3D
		var face: Vector3 = n.global_basis.z
		var row: Dictionary = Pools.LANTERN.duplicate()
		row["pos"] = flame.global_position
		row["face"] = Vector2(face.x, face.z).normalized()
		var body: Node3D = n.get_parent().get_parent() as Node3D
		if n.has_meta("hem_y") and body != null:
			row["eave"] = body.global_position.y + float(n.get_meta("hem_y"))
		rows.append(row)
	Pools.set_sources(rows)
	var boxes: Array = []
	var seen: Array = []
	for body: Node in Hulls.owners:
		if seen.has(body) or not (body is StaticBody3D):
			continue
		seen.append(body)
		for c: Node in body.get_children():
			var cs := c as CollisionShape3D
			if cs == null or cs.shape == null or cs.name == "FrontFaceCollider":
				continue
			var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			boxes.append(Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z))
	Pools.set_boxes(boxes)
	var all: Array = []  # untyped: LightRt._mats is Array[ShaderMaterial], scene meshes add StandardMaterial3D
	all.append_array(mats)
	Hulls._scene_mats(root, all)
	return Pools.bind_all(all)
