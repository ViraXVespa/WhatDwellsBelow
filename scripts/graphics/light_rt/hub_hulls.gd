extends Object

## Hub building shadows as exact projections for the ground shader: per building array mesh (walls, gables,
## awnings, roofs, tarps; fences, sprites and the crystal stay on the bake) the convex hull of its vertices dropped along the bake sun
## (hub_shadow._hub_ground: AWAY x REACH per metre of height). Each wall box, roof prism and awning is convex, so the
## hull is that part's true shadow. apply() stamps each 1/82.6 m cell once (inside: shade, within FINE_GAP: sun, else
## the bake). The ground and the mark sample that mask. They do not walk hull edges per pixel.

const Shadow := preload("res://scripts/graphics/light_rt/hub_shadow.gd")
const MAX_H := 32
const MAX_P := 256
## Debug plant: every hull shifted by this many metres (the edge check must catch it).
static var plant_shift := Vector2.ZERO
static var hulls: Array = []
## Per hull: the building it belongs to (the mesh's StaticBody3D), for gap checks.
static var owners: Array = []
static var _n := 0
## Same literal as ground_shader GRID (128 / PLAYER_H printed to 4 decimals). Cell centres land on these texels.
const MASK_GRID := 82.5806
static var _mask: Texture2D
static var _ox: int = 0
static var _oz: int = 0
## Bake shade under FINE_T, clear of the hulls by FINE_GAP m, is fine detail (fences, posts, signs, props, brackets):
## thresholded hard, so it keeps its shape without the faded contour.
const FINE_T := 0.66
const FINE_GAP := 0.1
## Shared by the ground shader and the actor marks (lit_k): one shade test, so a sun mark cancels exactly where
## the ground is in full shade. hub_sun: 1 sun, 0 shade; -1 when no hulls are bound (dungeon, editor).
const GLSL := """
uniform int hull_n = 0;
uniform sampler2D hull_mask : filter_nearest, repeat_disable;
uniform ivec2 hull_o = ivec2(0);
float hub_sun(vec2 q, float ll) {
	if (hull_n <= 0) { return -1.0; }
	ivec2 c = ivec2(floor(q * 82.5806)) - hull_o;
	ivec2 ts = textureSize(hull_mask, 0);
	float hd = -1.0;
	if (c.x >= 0 && c.y >= 0 && c.x < ts.x && c.y < ts.y) {
		float mark = texelFetch(hull_mask, c, 0).r;
		hd = mark > 0.75 ? 1.0 : (mark > 0.25 ? -0.05 : -1.0);
	}
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
	var kept: Array[PackedVector2Array] = []
	var pts: int = 0
	for h: PackedVector2Array in hs:
		if kept.size() >= MAX_H or pts + h.size() > MAX_P:
			break
		var shifted: PackedVector2Array = PackedVector2Array()
		for v in h:
			shifted.append(v + plant_shift)
		kept.append(shifted)
		pts += h.size()
	_n = kept.size()
	_mask = _mask_of(kept)
	if _mask == null:
		_n = 0
	var all: Array = []  # untyped: LightRt._mats is Array[ShaderMaterial], scene meshes add StandardMaterial3D
	all.append_array(mats)
	_scene_mats(root, all)
	var set: int = 0
	for m in all:
		if not (m is ShaderMaterial):
			continue
		if bind(m):
			set += 1
	var mw: int = 0 if _mask == null else _mask.get_width()
	var mh: int = 0 if _mask == null else _mask.get_height()
	last = "hulls=%d mats=%d/%d mask=%dx%d" % [_n, set, all.size(), mw, mh]
	return _n


## Pushes the current mask to one material (marks made after apply call this); false if it has no hull uniforms.
static func bind(m: ShaderMaterial) -> bool:
	if m == null or m.shader == null or not m.shader.code.contains("hull_mask"):
		return false
	m.set_shader_parameter("hull_n", _n)
	m.set_shader_parameter("hull_o", Vector2i(_ox, _oz))
	if _mask != null:
		m.set_shader_parameter("hull_mask", _mask)
	return true


## One texel per MASK_GRID cell over the shifted hulls. Red 255 inside, 165 within FINE_GAP, 0 farther (the bake decides).
static func _mask_of(polys: Array[PackedVector2Array]) -> Texture2D:
	if polys.is_empty():
		return null
	var min_x: float = 1.0e9
	var min_z: float = 1.0e9
	var max_x: float = -1.0e9
	var max_z: float = -1.0e9
	for poly in polys:
		for v in poly:
			min_x = minf(min_x, v.x)
			min_z = minf(min_z, v.y)
			max_x = maxf(max_x, v.x)
			max_z = maxf(max_z, v.y)
	var pad: float = FINE_GAP + (1.0 / MASK_GRID)
	_ox = int(floor((min_x - pad) * MASK_GRID))
	_oz = int(floor((min_z - pad) * MASK_GRID))
	var ix1: int = int(floor((max_x + pad) * MASK_GRID))
	var iz1: int = int(floor((max_z + pad) * MASK_GRID))
	var w: int = mini(4096, ix1 - _ox + 1)
	var h: int = mini(4096, iz1 - _oz + 1)
	if w < 1 or h < 1:
		return null
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(w * h * 4)
	for poly in polys:
		_stamp(buf, w, h, poly)
	var img: Image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, buf)
	return ImageTexture.create_from_image(img)


static func _stamp(buf: PackedByteArray, w: int, rows: int, poly: PackedVector2Array) -> void:
	var n: int = poly.size()
	if n < 3:
		return
	_fill_inside(buf, w, rows, poly)
	for i in n:
		_band(buf, w, rows, poly[i], poly[(i + 1) % n])


## Cell centres on or inside the convex hull. A horizontal line through the centre crosses two edges.
static func _fill_inside(buf: PackedByteArray, w: int, rows: int, poly: PackedVector2Array) -> void:
	var n: int = poly.size()
	var min_z: float = 1.0e9
	var max_z: float = -1.0e9
	for v in poly:
		min_z = minf(min_z, v.y)
		max_z = maxf(max_z, v.y)
	var iz0: int = maxi(0, int(floor(min_z * MASK_GRID)) - _oz)
	var iz1: int = mini(rows - 1, int(floor(max_z * MASK_GRID)) - _oz)
	for iz in range(iz0, iz1 + 1):
		var cz: float = (float(iz + _oz) + 0.5) / MASK_GRID
		var x_lo: float = 1.0e9
		var x_hi: float = -1.0e9
		var hits: int = 0
		for i in n:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			if not ((a.y <= cz and b.y > cz) or (b.y <= cz and a.y > cz)):
				continue
			var x: float = a.x + (cz - a.y) / (b.y - a.y) * (b.x - a.x)
			x_lo = minf(x_lo, x)
			x_hi = maxf(x_hi, x)
			hits += 1
		if hits < 2 or x_hi < x_lo:
			continue
		var ix_a: int = maxi(0, int(ceil(x_lo * MASK_GRID - 0.5)) - _ox)
		var ix_b: int = mini(w - 1, int(floor(x_hi * MASK_GRID - 0.5)) - _ox)
		for ix in range(ix_a, ix_b + 1):
			var at: int = (iz * w + ix) * 4
			buf[at] = 255
			buf[at + 1] = 255
			buf[at + 2] = 255
			buf[at + 3] = 255


## Cells within FINE_GAP of one edge, still outside every hull, stay in the sun band.
static func _band(buf: PackedByteArray, w: int, rows: int, a: Vector2, b: Vector2) -> void:
	var ix0: int = maxi(0, int(floor((minf(a.x, b.x) - FINE_GAP) * MASK_GRID)) - _ox)
	var iz0: int = maxi(0, int(floor((minf(a.y, b.y) - FINE_GAP) * MASK_GRID)) - _oz)
	var ix1: int = mini(w - 1, int(floor((maxf(a.x, b.x) + FINE_GAP) * MASK_GRID)) - _ox)
	var iz1: int = mini(rows - 1, int(floor((maxf(a.y, b.y) + FINE_GAP) * MASK_GRID)) - _oz)
	var ab: Vector2 = b - a
	var den: float = ab.length_squared()
	for iz in range(iz0, iz1 + 1):
		var cz: float = (float(iz + _oz) + 0.5) / MASK_GRID
		for ix in range(ix0, ix1 + 1):
			var at: int = (iz * w + ix) * 4
			if buf[at] != 0:
				continue
			var q: Vector2 = Vector2((float(ix + _ox) + 0.5) / MASK_GRID, cz)
			var along: float = 0.0
			if den > 1.0e-10:
				along = clampf((q - a).dot(ab) / den, 0.0, 1.0)
			if q.distance_to(a + ab * along) <= FINE_GAP:
				# 165 stays between the 0.25 and 0.75 cuts read raw (0.65) or sRGB-decoded (0.38); 200 read raw is 0.78,
				# inside, which widened every building shadow by FINE_GAP.
				buf[at] = 165
				buf[at + 1] = 165
				buf[at + 2] = 165
				buf[at + 3] = 255

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
