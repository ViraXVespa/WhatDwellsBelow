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
## Per hull: the building it belongs to (the mesh's StaticBody3D), for gap checks.
static var owners: Array = []
static var _p := PackedVector2Array()
static var _s := PackedInt32Array()
static var _n := 0
## Bake shade under FINE_T, clear of the hulls by FINE_GAP m, is fine detail (fences, posts, signs, props, brackets):
## thresholded hard, so it keeps its shape without the faded contour.
const FINE_T := 0.66
const FINE_GAP := 0.1
## Shared by the ground shader and the actor marks (lit_k): one shade test, so a sun mark cancels exactly where
## the ground is in full shade. hub_sun: 1 sun, 0 shade; -1 when no hulls are bound (dungeon, editor).
const GLSL := """
uniform int hull_n = 0;
uniform int hull_s[33];
uniform vec2 hull_p[256];
float hull_d(vec2 q) {
	float best = -1e9;
	for (int i = 0; i < hull_n; i++) {
		int a = hull_s[i];
		int b = hull_s[i + 1];
		float d = 1e9;
		for (int j = a; j < b; j++) {
			vec2 p0 = hull_p[j];
			vec2 e = hull_p[j + 1 < b ? j + 1 : a] - p0;
			d = min(d, (e.x * (q.y - p0.y) - e.y * (q.x - p0.x)) / max(length(e), 1e-5));
		}
		best = max(best, d);
	}
	return best;
}
float hub_sun(vec2 q, float ll) {
	if (hull_n <= 0) { return -1.0; }
	float hd = hull_d(q);
	return (hd >= 0.0 || (hd < -0.1 && ll < 0.66)) ? 0.0 : 1.0;
}
"""
static var last := ""

static func build(root: Node) -> Array:
	var fence: Array = []
	for b in root.get_tree().get_nodes_in_group("hub_fence"):
		fence.append(b)
	var out: Array = []
	owners = []
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		# Runtime hub meshes cast no live shadow (the bake does), so pick the building parts directly: every solid mesh
		# (array walls, gables, awnings, roofs, tarps, kept boxes) at least SKIP_H tall; flat quads (face art, lamps) and
		# fences stay on the bake.
		if mi.mesh == null or mi.mesh is PlaneMesh or mi.mesh is QuadMesh or not mi.is_visible_in_tree() or (mi.global_transform * mi.get_aabb()).size.y < Shadow.SKIP_H:
			continue
		if fence.any(func(f: Node) -> bool: return f.is_ancestor_of(mi)):
			continue
		var pts: PackedVector2Array = PackedVector2Array()
		for v in mi.mesh.get_faces():
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
			var top: Node = mi
			while top != null and not (top is StaticBody3D):
				top = top.get_parent()
			owners.append(top if top != null else mi)
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
	_p = p
	_s = s
	_n = mini(hs.size(), MAX_H)
	var all: Array = mats.duplicate()
	_scene_mats(root, all)
	var set := 0
	for m in all:
		if not (m is ShaderMaterial):
			continue
		if bind(m):
			set += 1
	last = "hulls=%d mats=%d/%d" % [mini(hs.size(), MAX_H), set, all.size()]
	return mini(hs.size(), MAX_H)


## Pushes the current hulls to one material (marks made after apply call this); false if it has no hull uniforms.
static func bind(m: ShaderMaterial) -> bool:
	if m == null or m.shader == null or not m.shader.code.contains("hull_p"):
		return false
	m.set_shader_parameter("hull_p", _p)
	m.set_shader_parameter("hull_s", _s)
	m.set_shader_parameter("hull_n", _n)
	return true

## CPU twin of GLSL hub_sun on the unshifted hulls: 1 sun, 0 shade, at ground point q with bake light ll.
static func sun_at(q: Vector2, ll: float) -> float:
	var best := -1e9
	for h: PackedVector2Array in hulls:
		var d := 1e9
		for i in h.size():
			var e: Vector2 = h[(i + 1) % h.size()] - h[i]
			d = minf(d, e.cross(q - h[i]) / maxf(e.length(), 1e-5))
		best = maxf(best, d)
	return 0.0 if best >= 0.0 or (best < -FINE_GAP and ll < FINE_T) else 1.0

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
