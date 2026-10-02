extends Object

## Actor shade-mark tuning and shader source. Pure data; no state.

const SUN_AWAY := Vector2(0.406138, 0.913811)
const SUN_ELEV := 0.45
const TORCH_H := 1.65
const MARK_MAX := 1.8
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

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.55);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.z += 0.003 * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.2) {
		discard;
	}
	ALBEDO = shade.rgb;
	ALPHA = shade.a;
}
"""
