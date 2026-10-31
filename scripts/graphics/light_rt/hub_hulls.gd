extends Object

## Hub building shadows as exact projections for the ground shader: per building array mesh (walls, gables,
## awnings, roofs, tarps; fences, sprites and the crystal stay on the bake) the convex hull of its vertices dropped along the bake sun
## (hub_shadow._hub_ground: AWAY x REACH per metre of height). Each wall box, roof prism and awning is convex, so the
## hull is that part's true shadow. The ground shader classifies each 1/82.6 m cell centre against the hulls (inside:
## shade, near outside: sun), so edges are straight lines stepped only at the cell, not the faded, blurred bake contour.

const Shadow := preload("res://scripts/graphics/light_rt/hub_shadow.gd")
const MAX_H := 32
const MAX_P := 256
## Debug plant: every hull shifted by this many metres (the edge check must catch it).
static var plant_shift := Vector2.ZERO
static var hulls: Array = []
static var last := ""

static func build(root: Node) -> Array:
	var fence: Array = []
	for b in root.get_tree().get_nodes_in_group("hub_fence"):
		fence.append(b)
	var out: Array = []
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		# Runtime hub meshes cast no live shadow (the bake does), so pick the building parts directly: array meshes
		# (walls, gables, awnings, roofs, tarps) at least SKIP_H tall; quads (face art, lamps) and fences stay on the bake.
		if not (mi.mesh is ArrayMesh) or not mi.is_visible_in_tree() or (mi.global_transform * mi.get_aabb()).size.y < Shadow.SKIP_H:
			continue
		if fence.any(func(f: Node) -> bool: return f.is_ancestor_of(mi)):
			continue
		var pts: PackedVector2Array = PackedVector2Array()
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				pts.append(Shadow._hub_ground(mi.global_transform * v))
		var h: PackedVector2Array = Geometry2D.convex_hull(pts)
		if h.size() >= 4:
			h.remove_at(h.size() - 1)  # convex_hull repeats the first point
			var area := 0.0
			for i in h.size():
				area += h[i].cross(h[(i + 1) % h.size()])
			if area < 0.0:
				h.reverse()  # the shader wants positive cross products inside
			out.append(h)
	hulls = out
	return out

## Pushes hulls (plus plant_shift) to the ground materials; returns the hull count.
static func apply(root: Node, mats: Array) -> int:
	var hs: Array = build(root)
	var p: PackedVector2Array = PackedVector2Array()
	var s: PackedInt32Array = PackedInt32Array([0])
	for h: PackedVector2Array in hs:
		if s.size() > MAX_H or p.size() + h.size() > MAX_P:
			break
		for v in h:
			p.append(v + plant_shift)
		s.append(p.size())
	p.resize(MAX_P)
	s.resize(MAX_H + 1)
	var all: Array = mats.duplicate()
	_scene_mats(root, all)
	var set := 0
	for m in all:
		if not (m is ShaderMaterial):
			continue
		if m.shader != null and m.shader.code.contains("hull_p"):
			set += 1
			m.set_shader_parameter("hull_p", p)
			m.set_shader_parameter("hull_s", s)
			m.set_shader_parameter("hull_n", mini(hs.size(), MAX_H))
	last = "hulls=%d mats=%d/%d" % [mini(hs.size(), MAX_H), set, all.size()]
	return mini(hs.size(), MAX_H)


## Every material on the scene's meshes (path pads, yard pads), not only LightRt's list.
static func _scene_mats(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var ms: Array = [mi.material_override]
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				ms.append(mi.get_surface_override_material(i))
				ms.append(mi.mesh.surface_get_material(i))
		for m in ms:
			if m != null and not out.has(m):
				out.append(m)
	for c in n.get_children():
		_scene_mats(c, out)
