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
## Hub marks are per-cell coverage on the ground grid (cells per metre; Chunky.GRID_M): no blur, no quad pad.
const HUB_GRID := 32.0
const GRID_M := 1.0 / HUB_GRID
## A foot whose lowest pixel sits this many ground cells above the other is raised: no tuck, it shows its gap.
const RAISED_CELLS := 1.5
## Airborne (fly / hop): sole above the floor by more than AIR_MIN m drops straight down and shifts along the light by
## its altitude; size and darkness fall off with altitude (floors AIR_S_MIN / AIR_A_MIN at AIR_S_M / AIR_A_M m).
const AIR_MIN := 0.06
const AIR_S_M := 2.4
const AIR_S_MIN := 0.5
const AIR_A_M := 1.6
const AIR_A_MIN := 0.25

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.55);
// Sun mark in the hub (sun_cancel 1): fades where the baked ground is already in shade (floor_l = full shade), so a
// mark inside a building's shadow does not double it. Point-light marks keep sun_cancel 0.
uniform float sun_cancel = 0.0;
uniform float grid = 0.0;
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
	// Hub (grid > 0): one value per ground cell: the mark's coverage box-averaged over the cell (4x4 taps mapped
	// through the screen Jacobian), continuous, so edges are blocky cells with smooth per-cell darkness.
	vec2 xz = wpos.xz;
	float cov = texture(albedo_tex, UV).a;
	if (grid > 0.0) {
		vec2 c0 = floor(xz * grid) / grid;
		mat2 jw = mat2(dFdx(xz), dFdy(xz));
		mat2 m = abs(determinant(jw)) > 1e-12 ? mat2(dFdx(UV), dFdy(UV)) * inverse(jw) : mat2(0.0);
		cov = 0.0;
		float contact = 0.0;
		for (int i = 0; i < 16; i++) {
			vec2 w = c0 + (vec2(float(i % 4), float(i / 4)) + 0.5) / (4.0 * grid);
			vec2 uv = UV + m * (w - xz);
			float a = texture(albedo_tex, vec2(uv.x, min(uv.y, sole_v))).a;
			cov += a;
			contact = max(contact, uv.y >= sole_v ? a : 0.0);
		}
		// A cell the sole line crosses under a boot is full contact: the mark meets both feet.
		cov = max(cov / 16.0, contact);
		xz = c0 + 0.5 / grid;
	}
	if (cov < 0.02) {
		discard;
	}
	ALBEDO = shade.rgb;
	float lit = 1.0;
	if (sun_cancel > 0.5) {
		vec2 luv = clamp((xz - light_origin) / max(light_span, vec2(0.001)), vec2(0.0), vec2(1.0));
		vec3 l = texture(light_tex, luv).rgb;
		lit = clamp(((l.r + l.g + l.b) / 3.0 - floor_l - 0.1) / (0.9 - floor_l), 0.0, 1.0); // 0.1 = SUN_SOFT
	}
	ALPHA = shade.a * lit * cov;
}
"""

## CPU twin of the shader's sun_cancel: the sun mark's share left at ground light l (0 in full shade).
static func sun_left(l: float, floor_l: float) -> float:
	return clampf((l - floor_l - SUN_SOFT) / (1.0 - floor_l - SUN_SOFT), 0.0, 1.0)
