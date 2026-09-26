extends Object

## One spatial field shader. Albedo is world xz. Light is the buffer RT.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

static var _sh: Shader


static func shader() -> Shader:
	if _sh != null:
		return _sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform float hash_m = 4.0;
uniform float variant_n = 3.0;
uniform float wear = 0.0;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = world_pos.xz;
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
	vec2 uv = fract(xz * uv_scale + uv_off);
	vec3 c = texture(albedo_tex, uv).rgb;
	float worn = mix(1.0, mix(0.78, 1.0, h), clamp(wear, 0.0, 1.0));
	vec2 span = max(light_span, vec2(0.001));
	vec2 luv = clamp((xz - light_origin) / span, vec2(0.0), vec2(1.0));
	ivec2 ts = max(textureSize(light_tex, 0), ivec2(1));
	vec2 max_p = max(vec2(ts) - vec2(1.0001), vec2(0.0));
	vec2 p = clamp(luv * vec2(ts) - vec2(0.5), vec2(0.0), max_p);
	vec2 fr = fract(p);
	ivec2 i0 = ivec2(floor(p));
	ivec2 i1 = min(i0 + ivec2(1), ts - ivec2(1));
	vec3 s00 = texelFetch(light_tex, i0, 0).rgb;
	vec3 s10 = texelFetch(light_tex, ivec2(i1.x, i0.y), 0).rgb;
	vec3 s01 = texelFetch(light_tex, ivec2(i0.x, i1.y), 0).rgb;
	vec3 s11 = texelFetch(light_tex, i1, 0).rgb;
	vec3 lit = mix(mix(s00, s10, fr.x), mix(s01, s11, fr.x), fr.y);
	ALBEDO = c * tint * quilt_tint * worn * lit;
}
"""
	_sh = sh
	return sh


static func material(tex_path: String, fallback: Color, tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	var albedo: Texture2D = _albedo(tex_path, fallback)
	var px: float = float(maxi(albedo.get_width(), 1))
	var density: float = App.bal.getv("ground_px_per_m")
	if density < 1.0:
		density = T.GROUND_PX_PER_M
	var hash_m: float = App.bal.getv("ground_hash_m")
	if hash_m < 1.0:
		hash_m = T.GROUND_HASH_M
	var variants: float = App.bal.getv("ground_variants")
	if variants < 1.0:
		variants = T.GROUND_VARIANTS
	var repeats: float = density / px
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("uv_scale", Vector2(repeats, repeats))
	mat.set_shader_parameter("uv_off", Vector2.ZERO)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("hash_m", hash_m)
	mat.set_shader_parameter("variant_n", variants)
	mat.set_shader_parameter("wear", App.bal.getv("ground_wear"))
	LightRt.bind(mat)
	return mat


static func _albedo(tex_path: String, fallback: Color) -> Texture2D:
	if ResourceLoader.exists(tex_path):
		var loaded: Texture2D = load(tex_path) as Texture2D
		if loaded != null:
			return loaded
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(fallback)
	var made: ImageTexture = ImageTexture.create_from_image(img)
	return made
