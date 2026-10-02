extends Object

## Shared WorldEnvironment + DirectionalLight3D block. Callers pass their own literals.

static func apply(
	host: Node,
	bg: Color,
	ambient: Color,
	ambient_energy: float,
	sun_rot: Vector3,
	sun_energy: float,
	sun_color: Color = Color.WHITE
) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = ambient_energy
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = sun_energy
	sun.light_color = sun_color
	sun.shadow_enabled = false
	host.add_child(sun)
