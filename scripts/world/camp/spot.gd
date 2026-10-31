extends Object

## Split from camp.gd: _bust_mat, _new_spot....

## Receptionist at the hub pixel size (Chunky) with a one-cell warm rim where she meets the dark window, and her
## shadows lifted a little, so hair and shoulders stay readable against the interior.
static func _bust_mat(tex: Texture2D, px: float = 0.0) -> ShaderMaterial:
	const Chunky = preload("res://scripts/graphics/chunky.gd")
	tex = Chunky.tex(tex, px)
	var cell := Vector2.ZERO
	if px > 0.0 and tex != null:
		var f: float = maxf(1.0, Chunky.GRID_M / px)
		cell = Vector2(f / tex.get_width(), f / tex.get_height())
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform float cut = 0.5;
uniform vec2 cell = vec2(0.0);
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (UV.y > cut || c.a < 0.1) {
		discard;
	}
	vec3 rgb = c.rgb * 0.85 + 0.08;
	if (cell.x > 0.0) {
		float open = 0.0;
		open = max(open, step(texture(albedo_tex, UV + vec2(cell.x, 0.0)).a, 0.1));
		open = max(open, step(texture(albedo_tex, UV - vec2(cell.x, 0.0)).a, 0.1));
		open = max(open, step(texture(albedo_tex, UV - vec2(0.0, cell.y)).a, 0.1));
		rgb = mix(rgb, vec3(1.0, 0.82, 0.55), 0.5 * open);
	}
	ALBEDO = rgb;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("cell", cell)
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
