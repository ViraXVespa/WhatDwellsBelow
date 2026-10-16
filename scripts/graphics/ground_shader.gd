extends Object

## One spatial field shader. Albedo is world xz. Light is the buffer RT.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

## One LOD-0 light tap shared with wall_shader. Text only (no function): ground inlines it, wall wraps it
## in tap_lit(xz). Needs light_tex / light_origin / light_span uniforms and a vec2 `xz` in scope.
## The hub bake has no mip chain. texture() was sampling a missing mip and the yard repainted on web.
const TAP_BODY := """
	vec2 span = max(light_span, vec2(0.001));
	vec2 luv = clamp((xz - light_origin) / span, vec2(0.0), vec2(1.0));
"""
const TAP_MIX := "textureLod(light_tex, luv, 0.0).rgb;\n"

static var _sh: Shader

static func shader() -> Shader:
	if _sh != null:
		return _sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 path_uv = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform float hash_m = 4.0;
uniform float variant_n = 3.0;
uniform float wear = 0.0;
uniform float yard = 0.0;
uniform vec4 grass_lim = vec4(2.0, 31.0, 4.0, 25.0);
uniform vec4 path_a = vec4(6.0, 13.0, 27.0, 17.0);
uniform vec4 path_b = vec4(15.0, 8.0, 18.0, 23.0);
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

bool in_rect(vec4 r, vec2 xz) {
	return xz.x >= r.x && xz.x < r.z && xz.y >= r.y && xz.y < r.w;
}

void fragment() {
	vec2 xz = world_pos.xz;
	vec2 uv = xz * uv_scale + uv_off;
	vec3 c = texture(albedo_tex, uv).rgb;
	if (yard > 0.5) {
		if (in_rect(path_a, xz) || in_rect(path_b, xz)) {
			c = texture(path_tex, xz * path_uv + uv_off).rgb;
		} else if (xz.x < grass_lim.x || xz.x >= grass_lim.y || xz.y < grass_lim.z || xz.y >= grass_lim.w) {
			c = texture(grass_tex, uv).rgb;
		}
	}
	float cell = max(hash_m, 0.001);
	vec2 q = xz / cell;
	vec2 qi = floor(q);
	vec2 qf = fract(q);
	qf = qf * qf * (3.0 - 2.0 * qf);
	float h00 = fract(sin(dot(qi, vec2(127.1, 311.7))) * 43758.5453);
	float h10 = fract(sin(dot(qi + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float h01 = fract(sin(dot(qi + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float h11 = fract(sin(dot(qi + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float h = mix(mix(h00, h10, qf.x), mix(h01, h11, qf.x), qf.y);
	float nvar = max(variant_n, 1.0);
	vec3 quilt_tint = vec3(1.0);
	if (nvar > 1.5) {
		float pick = h;
		quilt_tint = mix(vec3(0.98), vec3(1.02), pick);
	}
	float worn = mix(1.0, mix(0.78, 1.0, h), clamp(wear, 0.0, 1.0));
""" + TAP_BODY + "	vec3 lit = " + TAP_MIX + """	ALBEDO = c * tint * quilt_tint * worn * lit;
}
"""
	_sh = sh
	return sh

static func material(tex_path: String, fallback: Color, tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	var albedo: Texture2D = albedo_tex(tex_path, fallback)
	var px: float = float(maxi(albedo.get_width(), 1))
	var density: float = T.GROUND_PX_PER_M
	var hash_m: float = T.GROUND_HASH_M
	var variants: float = T.GROUND_VARIANTS
	var wear: float = 0.0
	if not Engine.is_editor_hint() and App.get("bal") != null:
		density = App.bal.getv("ground_px_per_m")
		if density < 1.0:
			density = T.GROUND_PX_PER_M
		hash_m = App.bal.getv("ground_hash_m")
		if hash_m < 1.0:
			hash_m = T.GROUND_HASH_M
		variants = App.bal.getv("ground_variants")
		if variants < 1.0:
			variants = T.GROUND_VARIANTS
		wear = App.bal.getv("ground_wear")
	var repeats: float = density / px
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("path_tex", albedo)
	mat.set_shader_parameter("grass_tex", albedo)
	mat.set_shader_parameter("yard", 0.0)
	mat.set_shader_parameter("uv_scale", Vector2(repeats, repeats))
	mat.set_shader_parameter("uv_off", Vector2.ZERO)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("hash_m", hash_m)
	mat.set_shader_parameter("variant_n", variants)
	mat.set_shader_parameter("wear", wear)
	LightRt.bind(mat)
	return mat

## One inner-slab sheet: grass frame, packed dirt, and the path. No second plane on top.
static func yard_material() -> ShaderMaterial:
	var mat: ShaderMaterial = material("res://assets/tiles/packed_dirt.png", Color(0.46, 0.42, 0.30))
	var grass: Texture2D = albedo_tex("res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	var path_albedo: Texture2D = albedo_tex("res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28))
	mat.set_shader_parameter("grass_tex", grass)
	mat.set_shader_parameter("path_tex", path_albedo)
	var path_px: float = float(maxi(path_albedo.get_width(), 1))
	var path_density: float = T.GROUND_PX_PER_M
	if not Engine.is_editor_hint() and App.get("bal") != null:
		path_density = App.bal.getv("ground_px_per_m")
		if path_density < 1.0:
			path_density = T.GROUND_PX_PER_M
	mat.set_shader_parameter("path_uv", Vector2(path_density / path_px, path_density / path_px))
	mat.set_shader_parameter("yard", 1.0)
	mat.set_shader_parameter("grass_lim", Vector4(2.0, 31.0, 4.0, 25.0))
	mat.set_shader_parameter("path_a", Vector4(6.0, 13.0, 27.0, 17.0))
	mat.set_shader_parameter("path_b", Vector4(15.0, 8.0, 18.0, 23.0))
	return mat

static func albedo_tex(tex_path: String, fallback: Color) -> Texture2D:
	if ResourceLoader.exists(tex_path):
		var loaded: Texture2D = load(tex_path) as Texture2D
		if loaded != null:
			return loaded
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fallback)
	var made: ImageTexture = ImageTexture.create_from_image(img)
	return made
