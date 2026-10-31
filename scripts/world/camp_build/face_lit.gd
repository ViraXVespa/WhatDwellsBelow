extends Object

## Building face art (guild, reception, stall fronts) lit by the hub light map: each column takes the baked light
## on the yard just in front of the face (the building's own shade, neighbour shadows, lantern pools), mixed by K.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const AHEAD := 0.3
const K := 0.85

static var _sh: Shader

static func mat(tex: Texture2D) -> ShaderMaterial:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform float ahead = 0.3;
uniform float k = 0.85;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec2 luv = clamp((vec2(wpos.x, wpos.z + ahead) - light_origin) / max(light_span, vec2(0.001)), vec2(0.0), vec2(1.0));
	ALBEDO = c.rgb * mix(vec3(1.0), texture(light_tex, luv).rgb, k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _sh
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("ahead", AHEAD)
	m.set_shader_parameter("k", K)
	LightRt.bind(m)
	return m
