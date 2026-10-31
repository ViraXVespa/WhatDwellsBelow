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

## Gable ridge: each roof's two slopes share their top edge (within EPS) and nothing is laid over it (a cap read as
## a gap). "" when clean; plant_ridge proves a slope dropped 5 cm FAILs.
const EPS := 0.005
var ridge: String:
	get:
		return ridge_faults(gables(), 0.0)
var plant_ridge: String:
	get:
		return "caught" if ridge_faults(gables(), 0.05).contains("gap") else "missed"

static func gables() -> Array:
	var out: Array = []
	_walk_gable((Engine.get_main_loop() as SceneTree).root, out)
	return out

static func _walk_gable(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n.name == "Gable" or n.name == "RidgeCap"):
		out.append(n)
	for c in n.get_children():
		_walk_gable(c, out)

static func ridge_faults(gs: Array, drop: float) -> String:
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
	return " ".join(out)
