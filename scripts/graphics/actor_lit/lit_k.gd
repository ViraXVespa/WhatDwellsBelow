extends Object

## Actor shade-mark tuning and shader source. Pure data; no state.

const SUN_AWAY := Vector2(0.406138, 0.913811)
const SUN_ELEV := 0.45
const HUB_STRETCH := 0.72
const HUB_ALPHA := 0.55
const D_NEAR := 0.12
const D_FAR := 0.72
const A_NEAR := 0.50
const A_FAR := 0.0
const MIN_DOWN := 0.28
const TURN_RATE := 20.0
const EASE_RATE := 12.0
const HIDE_A := 0.03
const MARK_N := 3
## Hub point lights (crystal, face lanterns) cast a player mark within this reach (m).
const HUB_POINT_REACH := 2.2
## The baked full shade reads a little above the floor (soft edge, fill): the sun mark is gone by floor + SUN_SOFT.
const SUN_SOFT := 0.1
## Hub mark edge softness (texels of the sticker): matches the baked building shadow's soft edge.
const HUB_SOFT := 1.5
const SOFT_GROW := 5.0
const SOLID_GROW := 1.6
## Quad pad (texels) past the caster's top and sides so the blur fades out instead of hitting the quad edge.
const SOFT_PAD := 8.0

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.55);
// Sun mark in the hub (sun_cancel 1): fades where the baked ground is already in shade (floor_l = full shade), so a
// mark inside a building's shadow does not double it. Point-light marks keep sun_cancel 0.
uniform float sun_cancel = 0.0;
uniform float soft = 0.0;
// Penumbra growth toward the far end; solid yard props use SOLID_GROW so one silhouette keeps one softness.
uniform float grow = 5.0;
varying float sole_v;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform float floor_l = 0.46;
varying vec3 wpos;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.z += 0.003 * clip.w;
	POSITION = clip;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sole_v = UV2.y > 0.0 ? UV2.y : 1.0;
}

void fragment() {
	// Soft edge (soft > 0, hub): a penumbra that grows away from the contact (UV.y 1 = sole row, 0 = sprite top), like
	// the baked building shadows': soft texels at the sole up to grow x soft at the far end, 5x5 coverage taps.
	float cov = texture(albedo_tex, UV).a;
	if (soft > 0.0) {
		vec2 d = soft * mix(grow, 1.0, clamp(UV.y, 0.0, 1.0)) / vec2(textureSize(albedo_tex, 0));
		cov = 0.0;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				vec2 tap = UV + vec2(float(i), float(j)) * d * 0.5;
				tap.y = min(tap.y, sole_v);
				cov += texture(albedo_tex, tap).a;
			}
		}
		cov /= 25.0;
	}
	if (cov < 0.1) {
		discard;
	}
	ALBEDO = shade.rgb;
	float lit = 1.0;
	if (sun_cancel > 0.5) {
		vec2 luv = clamp((wpos.xz - light_origin) / max(light_span, vec2(0.001)), vec2(0.0), vec2(1.0));
		vec3 l = texture(light_tex, luv).rgb;
		lit = clamp(((l.r + l.g + l.b) / 3.0 - floor_l - 0.1) / (0.9 - floor_l), 0.0, 1.0); // 0.1 = SUN_SOFT
	}
	ALPHA = shade.a * lit * (soft > 0.0 ? cov : 1.0);
}
"""

## CPU twin of the shader's sun_cancel: the sun mark's share left at ground light l (0 in full shade).
static func sun_left(l: float, floor_l: float) -> float:
	return clampf((l - floor_l - SUN_SOFT) / (1.0 - floor_l - SUN_SOFT), 0.0, 1.0)
