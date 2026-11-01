extends Object

## Cached wrap ShaderMaterial shader for hub roof / awning / tarp.

static var _wrap_sh: Shader

static func wrap_shader() -> Shader:
	if _wrap_sh != null:
		return _wrap_sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, unshaded, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D light_tex : source_color, filter_linear;
uniform vec2 light_origin = vec2(0.0);
uniform vec2 light_span = vec2(1.0);
uniform vec2 light_shift = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform float russet = 0.0;
uniform float shade_use = 0.0;
uniform float shade_lo = 1.0;
uniform float shade_hi = 1.0;
uniform float ignore_actor_shadow = 0.0;
// Awnings and tarps (face_light 1): lit like the building faces (face_lit.gd) by the slope's Lambert against flat ground (sun_dir); unlit parts sit at shade_to (FaceLit.SHADE).
uniform vec2 shade_n = vec2(1.0); // far-slope shade ramp, ridge to eave (shade_use)
uniform float face_light = 0.0;
uniform float face_z = -1000.0; // world z of the building front (hub checks; the cloth light no longer reads the yard)
uniform float ahead = 0.3;
uniform float k = 0.85;
uniform vec2 face_x = vec2(0.0); // cloth x extent: falls off toward the ends like the faces (edge, edge_span)
uniform vec2 edge = vec2(1.0, 0.3);
uniform vec2 eave = vec2(1.0, 0.7); // FaceLit.eave: darker under the eave at the wall (UV.y 0)
uniform float floor_l = 0.46; // FaceLit: yard light relative to the bake's own-shade floor
uniform float shade_to = 0.92;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = UV * uv_scale + uv_off;
	vec3 c = texture(albedo_tex, uv).rgb;
	if (russet > 0.5) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 dark = vec3(0.22, 0.05, 0.03);
		vec3 mid = vec3(0.62, 0.12, 0.06);
		vec3 hi = vec3(0.86, 0.28, 0.12);
		c = mix(dark, mid, smoothstep(0.12, 0.46, l));
		c = mix(c, hi, smoothstep(0.46, 0.80, l));
	} else {
		c *= tint;
	}
	if (shade_use > 0.5) {
		// Gable: v < 0 is the far (north) slope; it takes its own shade_n ramp so the two planes read as one lit roof.
		c *= UV.y < 0.0 ? mix(shade_n.x, shade_n.y, clamp(-UV.y, 0.0, 1.0)) : mix(shade_lo, shade_hi, clamp(UV.y, 0.0, 1.0));
	}
	vec3 lit = vec3(1.0);
	if (face_light > 0.5) {
		// geometric slope (the cloth mesh's vertex normals point straight up)
		vec3 n = normalize(cross(dFdx(wpos), dFdy(wpos)));
		n = n.y < 0.0 ? -n : n;
		float fx = clamp((wpos.x - face_x.x) / max(face_x.y - face_x.x, 0.001), 0.0, 1.0);
		float lam = clamp(dot(n, sun_dir) / max(sun_dir.y, 0.001), 0.0, 1.0);
		// FaceLit model: sun by the slope's Lambert, the rest at the shaded-ground level shade_to. The cloth hangs above
		// the yard, so the building shade on the yard in front is not its light (only the faces read it).
		vec3 sun = vec3(lam);
		lit = mix(vec3(1.0), mix(vec3(shade_to), vec3(1.0), sun) * mix(edge.x, 1.0, smoothstep(0.0, edge.y, min(fx, 1.0 - fx))) * mix(eave.x, 1.0, smoothstep(0.0, eave.y, UV.y)), k);
	} else if (ignore_actor_shadow < 0.5) {
		vec2 span = max(light_span, vec2(0.001));
		vec2 luv = clamp((wpos.xz + light_shift - light_origin) / span, vec2(0.0), vec2(1.0));
		lit = texture(light_tex, luv).rgb;
	}
	ALBEDO = c * lit;
	ROUGHNESS = 1.0;
	ALPHA = 1.0;
}
"""
	_wrap_sh = sh
	return sh
