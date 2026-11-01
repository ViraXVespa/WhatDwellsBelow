extends Object

## Hub bake only: the lamp count, and the overlay lines. Yard props (anvil, dumpster, banner, board, controls) use the
## player's live ActorLit mark (camp_build.mark_props) and stay out of the bake. Called from hub_shadow._hub_mesh_shadows.

const Pools := preload("res://scripts/graphics/light_rt/pools.gd")

## Hub lantern count (the pools are live: light_rt/pools.gd via camp/lamp_pools.gd; the bake writes none). The bake
## prints it as lamp_n so bake_repro still fails when the hub_lamp nodes go missing.
static func lamp_count(root: Node) -> int:
	return root.get_tree().get_nodes_in_group("hub_lamp").size()

## Overlay lines (tools/lib/bake/run_bake_camp.py draw_overlay): image origin and scale, every Layout spot, every
## collision box in the realized camp plus the banner poles (not realized in the bake), and every lamp pool.
static func overlay_dbg(org: Vector2, sub: float, root: Node, layout: Node) -> void:
	printerr("bake_dbg: org %.3f %.3f %.3f" % [org.x, org.y, sub])
	for id: String in layout.spot_ids():
		var p: Vector3 = layout.spot_pos(id)
		printerr("bake_dbg: spot %s %.3f %.3f" % [id, p.x, p.z])
	var rp: Vector3 = layout.reception_pos()
	printerr("bake_dbg: spot Reception %.3f %.3f" % [rp.x, rp.z])
	for found in root.find_children("*", "CollisionShape3D", true, false):
		var cs := found as CollisionShape3D
		if cs.shape == null:
			continue
		var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		printerr("bake_dbg: coll %s/%s %.3f %.3f %.3f %.3f" % [cs.get_parent().name, cs.name, bb.position.x, bb.position.z, bb.size.x, bb.size.z])
	for pole: Array in layout.banner_poles():
		var c: Vector3 = pole[0]
		var s: Vector3 = pole[1]
		printerr("bake_dbg: coll Banner/Pole %.3f %.3f %.3f %.3f" % [c.x - s.x * 0.5, c.z - s.z * 0.5, s.x, s.z])
	for lamp in root.get_tree().get_nodes_in_group("hub_lamp"):
		var p: Vector3 = (lamp as Node3D).global_position
		printerr("bake_dbg: lamp %.3f %.3f %.3f" % [p.x, p.z, float(Pools.LANTERN["range"])])
