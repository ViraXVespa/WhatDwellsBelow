extends RefCounted

## Hub face light check (camp-prop-shadows flow): every building face sprite (face_lit.gd) samples the real hub light
## map: its light_tex is LightRt.tex (not the 1x1 white stand-in an unbound face gets) and its mix k is on.
## Flow: assert script:debug/hub_face_check.bad equals "" and .plant equals "caught" (a face with its light map
## swapped for the white stand-in must FAIL).

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const MIN_FACES := 3

var bad: String:
	get:
		return faults(faces(), LightRt.tex)
var plant: String:
	get:
		var white := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
		var fs: Array = faces()
		if fs.is_empty():
			return "no_faces"
		var m: ShaderMaterial = (fs[0] as Sprite3D).material_override.duplicate()
		m.set_shader_parameter("light_tex", white)
		var probe := Sprite3D.new()
		probe.material_override = m
		var got: String = faults([probe] + fs.slice(1), LightRt.tex)
		probe.free()
		return "caught" if got.contains("unlit") else "missed"

static func faces() -> Array:
	var out: Array = []
	_walk((Engine.get_main_loop() as SceneTree).root, out)
	return out

static func _walk(n: Node, out: Array) -> void:
	if n is Sprite3D and (n as Sprite3D).material_override is ShaderMaterial:
		var m: ShaderMaterial = (n as Sprite3D).material_override
		if m.get_shader_parameter("ahead") != null:
			out.append(n)
	for c in n.get_children():
		_walk(c, out)

static func faults(fs: Array, want: Texture2D) -> String:
	var out: PackedStringArray = PackedStringArray()
	if fs.size() < MIN_FACES:
		out.append("faces=%d<%d" % [fs.size(), MIN_FACES])
	for s: Sprite3D in fs:
		var who: String = str(s.get_parent().name) if s.get_parent() != null else "probe"
		var m: ShaderMaterial = s.material_override
		var t: Texture2D = m.get_shader_parameter("light_tex")
		if t == null or t != want or t.get_width() < 2:
			out.append("%s:unlit" % who)
		elif float(m.get_shader_parameter("k")) < 0.5:
			out.append("%s:k_off" % who)
	return " ".join(out)

## Gable ridge: each roof's two slopes share their top edge (within EPS), nothing is laid over it (a cap read as a
## gap), and the tiles line up there: at each ridge x both slopes sample the same sheet u and v (uv * uv_scale +
## uv_off), and that v is Mat.RIDGE_V past a whole tile (the mortar band middle). plant_ridge drops a slope 5 cm; plant_uv mirrors the
## north slope's u (the old layout, joints off by a half brick) and shifts v by a third of a tile. Both must FAIL.
const EPS := 0.005
const Mat := preload("res://scripts/world/camp_build/mesh_mat.gd")
var ridge: String:
	get:
		return ridge_faults(gables(), 0.0)
var plant_ridge: String:
	get:
		return "caught" if ridge_faults(gables(), 0.05).contains("gap") else "missed"
var plant_uv: String:
	get:
		var a: String = ridge_faults(gables(), 0.0, true)
		var b: String = ridge_faults(gables(), 0.0, false, 0.33)
		return "caught" if a.contains("u_off") and b.contains("v_seam") else "missed"

static func gables() -> Array:
	var out: Array = []
	_walk_gable((Engine.get_main_loop() as SceneTree).root, out)
	return out

static func _walk_gable(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n.name == "Gable" or n.name == "RidgeCap"):
		out.append(n)
	for c in n.get_children():
		_walk_gable(c, out)

static func ridge_faults(gs: Array, drop: float, flip_u := false, v_shift := 0.0) -> String:
	var out: PackedStringArray = PackedStringArray()
	if gs.is_empty():
		out.append("no_gables")
	for g: MeshInstance3D in gs:
		var who: String = str(g.get_parent().name)
		if g.name == "RidgeCap":
			out.append("%s:cap" % who)
			continue
		var v: PackedVector3Array = g.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var top: Array = [-INF, -INF]  # highest vertex y on the south (z>=0) and north (z<=0) slope triangles
		for i in range(0, v.size(), 3):
			var cz: float = (v[i].z + v[i + 1].z + v[i + 2].z) / 3.0
			var s: int = 0 if cz > 0.0 else 1
			for k in 3:
				top[s] = maxf(top[s], v[i + k].y - (drop if s == 0 else 0.0))
		if absf(top[0] - top[1]) > EPS:
			out.append("%s:gap=%.3f" % [who, absf(top[0] - top[1])])
		out.append_array(_uv_faults(g, who, flip_u, v_shift))
	return " ".join(out)

## Sheet coords of the ridge vertices, south vs north at the same x.
static func _uv_faults(g: MeshInstance3D, who: String, flip_u: bool, v_shift: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var arr: Array = g.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var m: ShaderMaterial = g.material_override as ShaderMaterial
	if m == null:
		return PackedStringArray(["%s:no_roof_mat" % who])
	var sc: Vector2 = m.get_shader_parameter("uv_scale")
	var off: Vector2 = m.get_shader_parameter("uv_off")
	var y_top: float = -INF
	for p in v:
		y_top = maxf(y_top, p.y)
	var south: Dictionary = {}
	var north: Dictionary = {}
	for i in range(0, v.size(), 3):
		var cz: float = (v[i].z + v[i + 1].z + v[i + 2].z) / 3.0
		for k in 3:
			var p: Vector3 = v[i + k]
			if absf(p.y - y_top) > EPS:
				continue
			var t: Vector2 = uv[i + k]
			if cz <= 0.0:
				if flip_u:
					t.x = 1.0 - t.x
				t.y += v_shift / maxf(sc.y, 0.001)
			(south if cz > 0.0 else north)[snappedf(p.x, 0.01)] = t * sc + off
	if south.is_empty() or south.size() != north.size():
		out.append("%s:ridge_verts=%d/%d" % [who, south.size(), north.size()])
		return out
	for x in south:
		var a: Vector2 = south[x]
		var b: Vector2 = north.get(x, Vector2(INF, INF))
		var du: float = absf(fposmod(a.x - b.x + 0.5, 1.0) - 0.5)
		if du > 0.002:
			out.append("%s:u_off=%.3f" % [who, du])
		var seam: float = maxf(absf(fposmod(a.y - Mat.RIDGE_V + 0.5, 1.0) - 0.5), absf(fposmod(b.y - Mat.RIDGE_V + 0.5, 1.0) - 0.5))
		if seam > 0.002:
			out.append("%s:v_seam=%.3f" % [who, seam])
	return out
