extends RefCounted

## Hub face/awning light spread (camp-prop-shadows flow): each building face sprite (face_lit.gd) and each awning
## (wrap_shader face_light) is sampled the way its shader lights it (the baked light `ahead` of the column, remapped
## by FaceLit.rel, times the side fall-off FaceLit.edge; the face's fixed hem/base band is left out so only light-map shading counts) across the surface. Per surface: p10/p50/p90 of the light
## multiplier. A surface fails when p90 - p10 < MIN_SPREAD (shading flattened) or p90 < LIT_MIN (lit parts far below
## main's unlit 1.0). Flow: assert .bad equals "" and .plant equals "caught" (the same surfaces with a flat remap,
## shade_to 1 and no fall-off, must FAIL flat). .report prints every row.

const FaceLit := preload("res://scripts/world/camp_build/face_lit.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const MIN_SPREAD := 0.12
const LIT_MIN := 0.9
const GRID := 24

var bad: String:
	get:
		return faults(rows(false))
var plant: String:
	get:
		return "caught" if faults(rows(true)).contains("flat") else "missed"
var report: String:
	get:
		var out: PackedStringArray = PackedStringArray()
		for r: Dictionary in rows(false):
			out.append("%s p10=%.2f p50=%.2f p90=%.2f spread=%.2f raw=%.2f..%.2f" % [r.who, r.p10, r.p50, r.p90, r.p90 - r.p10, r.lo, r.hi])
		return " | ".join(out)

static func faults(rs: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	if rs.size() < 4:
		out.append("surfaces=%d<4" % rs.size())
	for r: Dictionary in rs:
		if r.p90 - r.p10 < MIN_SPREAD:
			out.append("%s:flat=%.2f" % [r.who, r.p90 - r.p10])
		if r.p90 < LIT_MIN:
			out.append("%s:dark=%.2f" % [r.who, r.p90])
	return " ".join(out)

static func rows(flat: bool) -> Array:
	var out: Array = []
	_walk((Engine.get_main_loop() as SceneTree).root, out, flat)
	return out

static func _walk(n: Node, out: Array, flat: bool) -> void:
	if n is Sprite3D and (n as Sprite3D).material_override is ShaderMaterial and (n as Sprite3D).texture != null:
		var m: ShaderMaterial = (n as Sprite3D).material_override
		if m.get_shader_parameter("ahead") != null and m.get_shader_parameter("face_light") == null:
			out.append(_face(n as Sprite3D, flat))
	elif n is MeshInstance3D and n.name == "Awning" and (n as MeshInstance3D).material_override is ShaderMaterial:
		out.append(_cloth(n as MeshInstance3D, flat))
	for c in n.get_children():
		_walk(c, out, flat)

static func _face(s: Sprite3D, flat: bool) -> Dictionary:
	var w: float = s.texture.get_width() * s.pixel_size * s.global_basis.get_scale().x
	var z: float = s.global_position.z + FaceLit.AHEAD
	var vals: Array = []
	var raw: Array = []
	for i in GRID:
		var l: float = _l(Vector2(s.global_position.x + w * ((i + 0.5) / GRID - 0.5), z))
		raw.append(l)
		vals.append(lerpf(1.0, FaceLit.rel(l, flat) * FaceLit.edge((i + 0.5) / GRID, flat), FaceLit.K))
	return _stats("face@%.1f" % s.global_position.x, vals, raw)

static func _cloth(c: MeshInstance3D, flat: bool) -> Dictionary:
	var box: AABB = c.global_transform * c.get_aabb()
	var face_z: float = float(c.material_override.get_shader_parameter("face_z"))
	var vals: Array = []
	var raw: Array = []
	for i in GRID:
		for j in GRID:
			var x: float = box.position.x + box.size.x * (i + 0.5) / GRID
			var z: float = maxf(box.position.z + box.size.z * (j + 0.5) / GRID, face_z) + FaceLit.AHEAD
			var l: float = _l(Vector2(x, z))
			raw.append(l)
			vals.append(lerpf(1.0, FaceLit.rel(l, flat) * FaceLit.edge((i + 0.5) / GRID, flat), FaceLit.K))
	return _stats("awning@%.1f" % box.get_center().x, vals, raw)

static func _l(xz: Vector2) -> float:
	var c: Color = LightRt.sample_xz(xz)
	return (c.r + c.g + c.b) / 3.0

static func _stats(who: String, vals: Array, raw: Array) -> Dictionary:
	vals.sort()
	raw.sort()
	var at := func(q: float) -> float: return float(vals[clampi(int(q * (vals.size() - 1)), 0, vals.size() - 1)])
	return {"who": who, "p10": at.call(0.1), "p50": at.call(0.5), "p90": at.call(0.9), "lo": raw[0], "hi": raw[-1]}
