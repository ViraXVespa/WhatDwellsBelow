extends Object

## One spatial field shader. Albedo is world xz. Wear is a baked tileable sheet. Light is the buffer RT.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

## Bilinear light-buffer tap shared with wall_shader. Text only (no function): ground inlines it, wall wraps it
## in tap_lit(xz). Needs light_tex / light_origin / light_span uniforms and a vec2 `xz` in scope.
const TAP_BODY := """
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
"""
## Baked wear sheet (tools/bake.py ground): tileable, posterized, WEAR_PX_PER_M texels per metre. At wear 1 the
## darkest texel is WEAR_DEPTH darker (ground_wear 0.22 -> about 5%).
const WEAR_PATH := "res://assets/baked/ground_wear.png"
const WEAR_PX_PER_M := 32.0
const GROUND_WEAR_STAMP := "53a0e8143e252c4f"

const TAP_MIX := "mix(mix(s00, s10, fr.x), mix(s01, s11, fr.x), fr.y);\n"

static var _sh: Shader

static func shader() -> Shader:
	if _sh != null:
		return _sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
#define WEAR_DEPTH 0.22
render_mode unshaded;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform sampler2D wear_tex : filter_nearest, repeat_enable;
uniform float wear_uv = 0.03125;
uniform float wear = 0.0;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform vec4 feather_rect = vec4(0.0);
uniform float feather = 0.0;
uniform vec4 feather_rect2 = vec4(0.0);
uniform sampler2D under_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 under_uv = vec2(1.0);
varying vec3 world_pos;
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 g) {
	vec2 i = floor(g);
	vec2 f = smoothstep(0.0, 1.0, fract(g));
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 xz = world_pos.xz;
	vec3 c = texture(albedo_tex, xz * uv_scale + uv_off).rgb;
	if (feather > 0.0) {
		// Transition, not a cut: blend toward the surface below (under_tex) across the fade, alpha in 4 steps on the
		// 1/16 m texel grid; the blend centre wobbles a little (0.25 m at ~2 m plus 0.12 m at ~0.6 m).
		vec2 q = (floor(xz * 16.0) + 0.5) / 16.0;
		float d = min(min(q.x - feather_rect.x, feather_rect.z - q.x), min(q.y - feather_rect.y, feather_rect.w - q.y));
		if (feather_rect2.z > feather_rect2.x) {
			d = max(d, min(min(q.x - feather_rect2.x, feather_rect2.z - q.x), min(q.y - feather_rect2.y, feather_rect2.w - q.y)));
		}
		float k = smoothstep(0.0, feather, d - 0.25 * vnoise(q * 0.5) - 0.12 * vnoise(q * 1.7 + 9.0));
		k = floor(k * 4.0 + 0.5) / 4.0;
		c = mix(texture(under_tex, xz * under_uv).rgb, c, k);
	}
	float worn = 1.0 - clamp(wear, 0.0, 1.0) * WEAR_DEPTH * texture(wear_tex, xz * wear_uv).r;
	// Baked light on the ground's 1/32 m pixel grid (Chunky.GRID_M): shadow edges step with the ground pixels.
	xz = (floor(xz * 32.0) + 0.5) / 32.0;
""" + TAP_BODY + "	vec3 lit = " + TAP_MIX + """	ALBEDO = c * tint * worn * lit;
}
"""
	_sh = sh
	return sh

## feather > 0: inside rect (x0, z0, x1, z1), or the union with rect2, the plane blends to under_path's texture over its
## last `feather` metres (4 alpha steps on the 1/16 m texel grid, small slow wobble), so surfaces meet in a soft transition.
static func feathered(tex_path: String, fallback: Color, rect: Vector4, width: float, under_path: String, rect2: Vector4 = Vector4.ZERO) -> ShaderMaterial:
	var mat: ShaderMaterial = material(tex_path, fallback)
	mat.set_shader_parameter("feather_rect", rect)
	mat.set_shader_parameter("feather_rect2", rect2)
	mat.set_shader_parameter("feather", width)
	var under: ShaderMaterial = material(under_path, fallback)
	mat.set_shader_parameter("under_tex", under.get_shader_parameter("albedo_tex"))
	mat.set_shader_parameter("under_uv", under.get_shader_parameter("uv_scale"))
	return mat

static func material(tex_path: String, fallback: Color, tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	var albedo: Texture2D = albedo_tex(tex_path, fallback)
	var px: float = float(maxi(albedo.get_width(), 1))
	var density: float = T.GROUND_PX_PER_M
	var wear: float = 0.0
	if not Engine.is_editor_hint() and App.get("bal") != null:
		density = App.bal.getv("ground_px_per_m")
		if density < 1.0:
			density = T.GROUND_PX_PER_M
		wear = App.bal.getv("ground_wear")
	var repeats: float = density / px
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("uv_scale", Vector2(repeats, repeats))
	mat.set_shader_parameter("uv_off", Vector2.ZERO)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var wt: Texture2D = load(WEAR_PATH) as Texture2D
	mat.set_shader_parameter("wear_tex", wt)
	if wt != null:
		mat.set_shader_parameter("wear_uv", WEAR_PX_PER_M / float(maxi(wt.get_width(), 1)))
	mat.set_shader_parameter("wear", wear)
	LightRt.bind(mat)
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
