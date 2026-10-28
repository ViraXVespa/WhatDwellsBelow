extends Object

## Hub bake only: the lamp pools, and the overlay lines. Yard props (anvil, dumpster, banner, board, controls) use the
## player's live ActorLit mark (camp_build.mark_props) and stay out of the bake. Called from hub_shadow._hub_mesh_shadows.

const Spec := preload("res://scripts/world/camp/layout_spec.gd")

## Warm pool on the yard under each "hub_lamp" (guild lanterns): lifts toward LAMP.pool within pool_r metres, centred
## pool_ahead metres in front of the lamp.
static func lamp_glow(img: Image, org: Vector2, sub: float, layout: Node) -> int:
	if layout == null or not layout.has_method("hall_pos"):
		return 0
	var wrote: int = 0
	var glow: Color = Spec.LAMP["pool"]
	var r: float = Spec.LAMP["pool_r"]
	var ahead: float = float(Spec.LAMP["pool_ahead"])
	# Hall lamps (texel centers projected to face; approximate face-local X from known art width)
	var hall: Vector3 = layout.hall_pos()
	var hall_face_z: float = hall.z + layout.hall_box.z * 0.5
	var hall_lamps: Array = Spec.HALL["lamps"]
	for tex: Vector2 in hall_lamps:
		var lx: float = hall.x + (tex.x - 160.0) * 0.012  # rough texel-to-metre on guild face
		var lz: float = hall_face_z + ahead
		wrote += _paint_pool(img, org, sub, lx, lz, r, glow)
	# Wing lamp (the painted lantern above the reception window)
	var wing: Vector3 = layout.wing_pos()
	var wing_face_z: float = layout.wing_face_z()
	var wing_lamps: Array = Spec.WING["lamps"]
	for tex: Vector2 in wing_lamps:
		var lx: float = wing.x + (tex.x - 160.0) * 0.010
		var lz: float = wing_face_z + ahead
		wrote += _paint_pool(img, org, sub, lx, lz, r, glow)
	return wrote

static func _paint_pool(img: Image, org: Vector2, sub: float, cx: float, cz: float, r: float, glow: Color) -> int:
	var wrote: int = 0
	for y in range(maxi(0, int((cz - r - org.y) * sub)), mini(img.get_height(), int((cz + r - org.y) * sub))):
		for x in range(maxi(0, int((cx - r - org.x) * sub)), mini(img.get_width(), int((cx + r - org.x) * sub))):
			var d: float = Vector2(org.x + (x + 0.5) / sub - cx, org.y + (y + 0.5) / sub - cz).length() / r
			if d >= 1.0:
				continue
			var k: float = (1.0 - d) * (1.0 - d) * 0.45
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(glow, k))
			wrote += 1
	return wrote
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
		printerr("bake_dbg: lamp %.3f %.3f %.3f" % [p.x, p.z + float(Spec.LAMP["pool_ahead"]), float(Spec.LAMP["pool_r"])])
