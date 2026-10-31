extends RefCounted

## Roof running bond (camp-prop-shadows flow): plaza_roof.png is COURSES courses, each offset from the next. bond
## FAILs when two adjacent courses share their vertical joints (stack bond), in the sheet itself or across a guild
## ridge, where the first course of each slope (sheet uv as the shader maps it) must be two neighbouring sheet
## courses. plant_bond maps the north slope the old mirrored way (v from 0 at the ridge, its first course = the
## south one) and must FAIL "stack".

const Face := preload("res://scripts/debug/hub_face_check.gd")
const COURSES := 22
const SAME := 0.5  # joint overlap above this share = stacked

var bond: String:
	get:
		return bond_faults(Face.gables(), false)
var plant_bond: String:
	get:
		return "caught" if bond_faults(Face.gables(), true).contains("stack") else "missed"

static func bond_faults(gs: Array, mirror: bool) -> String:
	var out: PackedStringArray = PackedStringArray()
	if gs.is_empty():
		return "no_gables"
	var m0: ShaderMaterial = (gs[0] as MeshInstance3D).material_override as ShaderMaterial
	var img: Image = (m0.get_shader_parameter("albedo_tex") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var joints: Array = []
	for c in COURSES:
		joints.append(_joints(img, c))
	for c in COURSES:
		var o: float = _overlap(joints[c], joints[(c + 1) % COURSES])
		if o > SAME:
			out.append("sheet:stack c%d/c%d=%.2f" % [c, (c + 1) % COURSES, o])
	for g: MeshInstance3D in gs:
		var cs: Array = _first_courses(g, mirror)
		if cs.is_empty():
			out.append("%s:no_slopes" % g.get_parent().name)
			continue
		var o: float = _overlap(joints[cs[0]], joints[cs[1]])
		if o > SAME:
			out.append("%s:stack c%d/c%d=%.2f" % [g.get_parent().name, cs[0], cs[1], o])
	return " ".join(out)

## Sheet course of the first row down each slope from the ridge: [south, north].
static func _first_courses(g: MeshInstance3D, mirror: bool) -> Array:
	var arr: Array = g.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var m: ShaderMaterial = g.material_override as ShaderMaterial
	var sc: Vector2 = m.get_shader_parameter("uv_scale")
	var off: Vector2 = m.get_shader_parameter("uv_off")
	var y_top: float = -INF
	for p in v:
		y_top = maxf(y_top, p.y)
	var ridge: Array = [NAN, NAN]
	var eave: Array = [NAN, NAN]
	for i in v.size():
		if absf(v[i].y - y_top) >= 0.005:
			var s: int = 0 if v[i].z > 0.0 else 1
			eave[s] = (absf(uv[i].y) if s == 1 and mirror else uv[i].y) * sc.y + off.y
	for i in v.size():
		if absf(v[i].y - y_top) >= 0.005:
			continue
		var tri: int = i / 3 * 3
		var cz: float = (v[tri].z + v[tri + 1].z + v[tri + 2].z) / 3.0
		var s: int = 0 if cz > 0.0 else 1
		var t: float = uv[i].y
		if s == 1 and mirror:
			t = absf(t)
		ridge[s] = t * sc.y + off.y
	if is_nan(ridge[0]) or is_nan(ridge[1]) or is_nan(eave[0]) or is_nan(eave[1]):
		return []
	var out: Array = []
	for s in 2:
		var dir: float = signf(eave[s] - ridge[s])
		var mid: float = fposmod(ridge[s] + dir * 0.5 / COURSES, 1.0)
		out.append(int(floor(mid * COURSES)) % COURSES)
	return out

## Joint columns (dark mortar) along the middle row of course c.
static func _joints(img: Image, c: int) -> PackedInt32Array:
	var y: int = int((c + 0.45) * img.get_height() / COURSES)
	var lum: PackedFloat32Array = PackedFloat32Array()
	var tot: float = 0.0
	for x in img.get_width():
		var l: float = img.get_pixel(x, y).get_luminance()
		lum.append(l)
		tot += l
	var cut: float = tot / img.get_width() * 0.6
	var out: PackedInt32Array = PackedInt32Array()
	for x in lum.size():
		if lum[x] < cut:
			out.append(x)
	return out

static func _overlap(a: PackedInt32Array, b: PackedInt32Array) -> float:
	if a.is_empty():
		return 1.0
	var hit: int = 0
	for x in a:
		if b.has(x) or b.has(x - 1) or b.has(x + 1):
			hit += 1
	return float(hit) / a.size()
