extends Object

## Cached wrap ShaderMaterial shader for hub roof / awning / tarp.

static var _wrap_sh: Shader


static func wrap_shader() -> Shader:
	if _wrap_sh != null:
		return _wrap_sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform float russet = 0.0;
void fragment() {
	vec2 uv = fract(UV * uv_scale + uv_off);
	vec3 c = texture(albedo_tex, uv).rgb;
	if (russet > 0.5) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 dark = vec3(0.18, 0.07, 0.05);
		vec3 mid = vec3(0.50, 0.16, 0.10);
		vec3 hi = vec3(0.74, 0.32, 0.18);
		c = mix(dark, mid, smoothstep(0.12, 0.46, l));
		c = mix(c, hi, smoothstep(0.46, 0.80, l));
	} else {
		c *= tint;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	ALPHA = 1.0;
}
"""
	_wrap_sh = sh
	return sh
