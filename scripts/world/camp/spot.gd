extends Object

## Split from camp.gd: _bust_mat, _new_spot....

## Receptionist at her own sprite pixel (character art stays native), mipmapped for the pitched view. No rim or lift: her own colours under a faint warm cast from the
## window lamps; half-covered cells are cut (alpha 0.5) so the box-shrunk edge never shows a pale fringe.
static func _bust_mat(tex: Texture2D, px: float = 0.0) -> ShaderMaterial:
	const Chunky = preload("res://scripts/graphics/chunky.gd")
	tex = Chunky.tex(tex, px)
	# Mipmapped: the -58 deg view shows her rows at half height; nearest dropped rows (eyes, mouth), mips blend them.
	var img: Image = tex.get_image().duplicate() if tex != null and tex.get_image() != null else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float cut = 0.5;
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (UV.y > cut || c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * vec3(1.06, 1.0, 0.9);
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("cut", preload("res://scripts/world/camp/layout_spec.gd").RECEPTION_CUT)
	return mat

static func _new_spot(host: Node3D, id: String, at: Vector3) -> Node3D:
	var SpotS: GDScript = load("res://scripts/world/interact.gd") as GDScript
	var spot: Node3D = SpotS.new() as Node3D
	spot.call("setup", id, at)
	host.add_child(spot)
	return spot

static func _add_spot(host: Node3D, id: String, at: Vector3) -> void:
	_new_spot(host, id, at)
