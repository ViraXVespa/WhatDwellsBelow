extends Object

## Building face art (guild, reception, stall fronts) lit by the hub light map: each column takes the baked light
## on the yard just in front of the face (the building's own shade, neighbour shadows, lantern pools), mixed by K.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const AHEAD := 0.3
const K := 0.85
## The bake floors every shade at HubCast.SHADE_NEAR and a south face always stands in its own building's shade, so
## the light is remapped: the floor reads SHADE_TO, full sun 1, lantern pools up to LIFT (the shade gradient, shadow
## edges and pools keep their variation). On the face art the awning shades the top (HEM over HEM_SPAN of the height)
## and the base darkens toward the ground (BASE from BASE_FROM down). The light map is near-uniform own shade across a
## front, so each surface also falls off toward its side ends (EDGE at the end, full over EDGE_SPAN of the width):
## the corner shading the yard map cannot carry (hub_light_spread.gd measures the result per surface).
const LIFT := 1.35
const SHADE_TO := 0.9
const EDGE := 0.74
const EDGE_SPAN := 0.3
const HEM := 0.72
## Awning cloth (wrap_shader face_light): darker under the eave at the wall (v 0), opening to full light by EAVE_SPAN.
const EAVE := 0.7
const EAVE_SPAN := 1.0
const HEM_SPAN := 0.18
const BASE := 0.8
const BASE_FROM := 0.6
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")

static var _sh: Shader

## The shader's remap and band on the CPU (hub_light_spread.gd measures each surface with them). flat: shade_to 1.
static func rel(l: float, flat := false) -> float:
	var to: float = 1.0 if flat else SHADE_TO
	return clampf(lerpf(to, 1.0, (l - HubCast.SHADE_NEAR) / (1.0 - HubCast.SHADE_NEAR)), 0.0, 1.0 if flat else LIFT)
static func edge(u: float, flat := false) -> float:
	return 1.0 if flat else lerpf(EDGE, 1.0, smoothstep(0.0, EDGE_SPAN, minf(u, 1.0 - u)))
static func eave(v: float, flat := false) -> float:
	return 1.0 if flat else lerpf(EAVE, 1.0, smoothstep(0.0, EAVE_SPAN, v))
static func band(v: float) -> float:
	return lerpf(HEM, 1.0, smoothstep(0.0, HEM_SPAN, v)) * lerpf(1.0, BASE, smoothstep(BASE_FROM, 1.0, v))

static func mat(tex: Texture2D) -> ShaderMaterial:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = ("""
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform float ahead = 0.3;
uniform float k = 0.85;
uniform float floor_l = 0.46;
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
	vec3 l = texture(light_tex, luv).rgb;
	vec3 rel = clamp(mix(vec3(SHADE_TO), vec3(1.0), (l - floor_l) / (1.0 - floor_l)), vec3(0.0), vec3(LIFT));
	float band = mix(HEM, 1.0, smoothstep(0.0, HEM_SPAN, UV.y)) * mix(1.0, BASE, smoothstep(BASE_FROM, 1.0, UV.y));
	float edge = mix(EDGE, 1.0, smoothstep(0.0, EDGE_SPAN, min(UV.x, 1.0 - UV.x)));
	ALBEDO = c.rgb * mix(vec3(1.0), rel * band * edge, k);
}
""").replace("EDGE_SPAN", str(EDGE_SPAN)).replace("EDGE", str(EDGE)).replace("LIFT", str(LIFT)).replace("SHADE_TO", str(SHADE_TO)).replace("HEM_SPAN", str(HEM_SPAN)).replace("HEM", str(HEM)).replace("BASE_FROM", str(BASE_FROM)).replace("BASE", str(BASE))
	var m := ShaderMaterial.new()
	m.shader = _sh
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("ahead", AHEAD)
	m.set_shader_parameter("k", K)
	m.set_shader_parameter("floor_l", HubCast.SHADE_NEAR)
	LightRt.bind(m)
	return m
