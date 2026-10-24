extends Object

## Split from camp.gd: _bust_mat, _new_spot....

static func _bust_mat(tex: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform sampler2D albedo_tex : source_color, filter_nearest;
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (UV.y > 0.50 || c.a < 0.1) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", tex)
	return mat

static func _new_spot(host: Node3D, id: String, at: Vector3) -> Node3D:
	var SpotS: GDScript = load("res://scripts/world/interact.gd") as GDScript
	var spot: Node3D = SpotS.new() as Node3D
	spot.call("setup", id, at)
	host.add_child(spot)
	return spot

static func _add_spot(host: Node3D, id: String, at: Vector3) -> void:
	_new_spot(host, id, at)
