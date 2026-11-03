extends Object

## Building face art (guild, reception, stall fronts) lit by the hub light map: each column takes the baked light
## on the yard just in front of the face (the building's own shade, neighbour shadows, lantern pools) and its sun Lambert, mixed by K.

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Pools := preload("res://scripts/graphics/light_rt/pools.gd")
## Lantern light on the face itself (live pools, wrap: a lamp hung on the wall grazes it), evaluated per texel cell.
const POOL_WRAP := 0.0
const AHEAD := 0.3
const K := 1.0
## Sun model shared with the awnings (wrap_shader face_light): a surface takes sun by its Lambert against flat ground
## (lam, 0 for a face turned from the sun) times the yard light in front of it (shadows); the rest sits at SHADE, the
## bake's shaded-ground level, so a face in its building's own shade reads as dark as the shaded ground beside it.
## Lantern pools add on top, capped at SUN_CAP (sunlit art): a lamp never lights a spot past full sun.
const SHADE := 0.46  # HubCast.SHADE_NEAR (awnings, tarps)
## A wall face in its own shade still sees the open sky and the sunlit yard (bounce), so it sits above the shaded
## ground: FILL. With the hem/base band and the side falloff a south front measures ~0.75 of its art, against the
## ground's 0.51 (sun 1). At SHADE the fronts read heavier than the ground beside them.
const FILL := 0.64
const SUN_CAP := 1.0
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

## The shader's light on the CPU (hub_light_spread.gd, hub_shade_check.gd): yard light l, Lambert lam (0..1 vs flat
## ground). flat: the old unshaded look (1 everywhere), the checks' planted fault.
static func rel(l: float, flat := false, lam := 0.0) -> float:
	if flat:
		return 1.0
	return lerpf(FILL, 1.0, lam * clampf((l - HubCast.SHADE_NEAR) / (1.0 - HubCast.SHADE_NEAR), 0.0, 1.0))
## Sun Lambert of a world normal against flat ground (the bake sun: shadows fall along HubCast.AWAY, REACH per metre).
static func lam(n: Vector3) -> float:
	var sun := Vector3(-HubCast.AWAY.x, 1.0 / HubCast.REACH, -HubCast.AWAY.y).normalized()
	return clampf(n.dot(sun) / sun.y, 0.0, 1.0)
## Face light plus lantern pool, capped at SUN_CAP like the shader (cap false: the check's planted fault).
static func lit(base: float, pool: float, cap := true) -> float:
	return minf(base + pool, SUN_CAP) if cap else base + pool
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
#define GRID 82.5806
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform float ahead = 0.3;
uniform float k = 0.85;
uniform float floor_l = 0.46;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
varying vec3 wpos;
varying vec3 wnrm;
""" + Pools.GLSL + """
void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec2 luv = clamp((vec2(wpos.x, wpos.z + ahead) - light_origin) / max(light_span, vec2(0.001)), vec2(0.0), vec2(1.0));
	vec3 l = texture(light_tex, luv).rgb;
	float lam = clamp(dot(wnrm, sun_dir) / max(sun_dir.y, 0.001), 0.0, 1.0);
	vec3 rel = mix(vec3(FILL), vec3(1.0), lam * clamp((l - floor_l) / (1.0 - floor_l), vec3(0.0), vec3(1.0)));
	float band = mix(HEM, 1.0, smoothstep(0.0, HEM_SPAN, UV.y)) * mix(1.0, BASE, smoothstep(BASE_FROM, 1.0, UV.y));
	float edge = mix(EDGE, 1.0, smoothstep(0.0, EDGE_SPAN, min(UV.x, 1.0 - UV.x)));
	vec3 cell = (floor(wpos * GRID) + 0.5) / GRID;
	ALBEDO = c.rgb * min(mix(vec3(1.0), rel * band * edge, k) + pool_light(cell + wnrm * 0.02, wnrm, POOL_WRAP), vec3(SUN_CAP));
}
""").replace("POOL_WRAP", str(POOL_WRAP)).replace("EDGE_SPAN", str(EDGE_SPAN)).replace("EDGE", str(EDGE)).replace("SUN_CAP", str(SUN_CAP)).replace("SHADE", str(SHADE)).replace("FILL", str(FILL)).replace("HEM_SPAN", str(HEM_SPAN)).replace("HEM", str(HEM)).replace("BASE_FROM", str(BASE_FROM)).replace("BASE", str(BASE))
	var m := ShaderMaterial.new()
	m.shader = _sh
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("ahead", AHEAD)
	m.set_shader_parameter("k", K)
	m.set_shader_parameter("floor_l", HubCast.SHADE_NEAR)
	m.set_shader_parameter("sun_dir", Vector3(-HubCast.AWAY.x, 1.0 / HubCast.REACH, -HubCast.AWAY.y).normalized())
	LightRt.bind(m)
	return m
