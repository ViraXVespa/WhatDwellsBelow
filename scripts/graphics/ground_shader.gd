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
## Baked wear sheet (tools/bake_ground_wear.py): tileable, posterized, WEAR_PX_PER_M texels per metre. At wear 1 the
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
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 xz = world_pos.xz;
	vec2 uv = xz * uv_scale + uv_off;
	vec3 c = texture(albedo_tex, uv).rgb;
	float worn = 1.0 - clamp(wear, 0.0, 1.0) * WEAR_DEPTH * texture(wear_tex, xz * wear_uv).r;
""" + TAP_BODY + "	vec3 lit = " + TAP_MIX + """	ALBEDO = c * tint * worn * lit;
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
