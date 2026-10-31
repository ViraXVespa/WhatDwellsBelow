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
