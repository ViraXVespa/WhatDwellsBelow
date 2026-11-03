extends Object

## Rendered shade-level check: every ground point inside a building shadow polygon (hub_hulls.gd), including the ring
## against the wall base, must be ONE shade level. Buildings and sprites hidden, the ground drawn twice with force_draw:
## as is, and with a white light texture and no hulls (pure albedo). Their ratio is the light factor; inside a hull it
## must sit within TOL of shade_l: higher is a lit gap (the warm sun once read as a lamp pool), lower is two shadows
## stacking. plant "bake": hull_n 0 (bake contour only), which must fail.

const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")
const Chunky := preload("res://scripts/graphics/chunky.gd")
const SHADE_L := 0.46  # ground_shader.gd shade_l default
const TOL := 0.1
const STEP := 0.05
const LIT := 0  # lit points allowed per hull (a gap is lit ground inside the shadow)
const BAD := 0.01  # share of points allowed off level per hull

static func run(plant: String = "") -> String:
	var root: Node = (Engine.get_main_loop() as SceneTree).current_scene
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var hs: Array = Hulls.build(root)
	var g: float = Chunky.GRID_M
	var mats: Array = []
	var y := 0.0
	var hid: Array = []
	var foot: Array = []
	var grounds: Array = root.get_tree().get_nodes_in_group("hub_ground")
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		if grounds.any(func(gn: Node) -> bool: return v.is_ancestor_of(gn)):
			continue
		if v.is_in_group("hub_ground"):
			y = maxf(y, v.global_position.y)
			var m := (v as MeshInstance3D).material_override as ShaderMaterial
			if m and m.get_shader_parameter("hull_n") != null:
				mats.append(m)
		elif v.visible and v is GeometryInstance3D:
			var bb: AABB = v.global_transform * v.get_aabb()
			if v is MeshInstance3D and (v as MeshInstance3D).mesh is ArrayMesh and bb.size.y >= 0.2:
				foot.append(Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z).grow(0.05))
			v.visible = false
			hid.append(v)
	if mats.is_empty():
		for v in hid:
			v.visible = true
		return "no_ground"
	var keep: Array = mats.map(func(m: ShaderMaterial) -> Array: return [m.get_shader_parameter("light_tex"), m.get_shader_parameter("hull_n"), m.get_shader_parameter("pool_n")])
	var sv: Variant = mats[0].get_shader_parameter("shade_l")
	if sv == null:
		sv = RenderingServer.shader_get_parameter_default(mats[0].shader.get_rid(), "shade_l")
	var shade: float = sv if sv != null else SHADE_L
	for m in mats:
		m.set_shader_parameter("pool_n", 0)  # lantern pools are added light, not a shade level
	if plant == "bake":
		for m in mats:
			m.set_shader_parameter("hull_n", 0)
	RenderingServer.force_draw(false)
	var a: Image = root.get_viewport().get_texture().get_image()
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	for m in mats:
		m.set_shader_parameter("light_tex", ImageTexture.create_from_image(white))
		m.set_shader_parameter("hull_n", 0)
	RenderingServer.force_draw(false)
	var b: Image = root.get_viewport().get_texture().get_image()
	for i in mats.size():
		mats[i].set_shader_parameter("light_tex", keep[i][0])
		mats[i].set_shader_parameter("hull_n", keep[i][1])
		mats[i].set_shader_parameter("pool_n", keep[i][2] if keep[i][2] != null else 0)
	for v in hid:
		v.visible = true
	var bad := PackedStringArray()
	var used := 0
	for hi in hs.size():
		var h: PackedVector2Array = hs[hi]
		var r := Rect2(h[0], Vector2.ZERO)
		for p in h:
			r = r.expand(p)
		var tot := 0
		var off := 0
		var lit := 0
		var rs: Array = []
		var x := r.position.x
		while x < r.end.x:
			var z := r.position.y
			while z < r.end.y:
				var q := Vector2(x, z)
				z += STEP
				if foot.any(func(f: Rect2) -> bool: return f.has_point(q)) or not _deep(h, q, g):
					continue
				var s: Vector2 = cam.unproject_position(Vector3(q.x, y, q.y))
				if cam.is_position_behind(Vector3(q.x, y, q.y)) or not Rect2(Vector2.ZERO, Vector2(a.get_size() - Vector2i.ONE)).has_point(s):
					continue
				var lb: float = b.get_pixelv(s).get_luminance()
				if lb < 0.05:
					continue
				tot += 1
				rs.append(a.get_pixelv(s).get_luminance() / lb)
				if a.get_pixelv(s).get_luminance() / lb > shade + TOL:
					lit += 1
				if absf(a.get_pixelv(s).get_luminance() / lb - shade) > TOL:
					off += 1
			x += STEP
		used += tot
		if tot > 0 and (float(off) / tot > BAD or lit > LIT):
			rs.sort()
			bad.append("h%d=%d/%d lit%d med%.2f p5 %.2f p95 %.2f sh%.2f" % [hi, off, tot, lit, rs[tot / 2], rs[tot / 20], rs[tot * 19 / 20], shade])
	if used < 50:
		return "no_points"
	return ", ".join(bad)

## q inside the convex hull h by at least m (positive-area hull: inside is left of every edge).
static func _deep(h: PackedVector2Array, q: Vector2, m: float) -> bool:
	for i in h.size():
		var e: Vector2 = (h[(i + 1) % h.size()] - h[i]).normalized()
		if -e.orthogonal().dot(q - h[i]) < m:
			return false
	return true
