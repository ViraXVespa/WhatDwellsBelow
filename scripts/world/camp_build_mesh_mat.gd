extends Object

## Camp mesh materials: wrapped, roof, tarp, awning.

const WrapShader := preload("res://scripts/graphics/wrap_shader.gd")
const TILE_W := 3.2

static func wrap_mat(
	path: String,
	dim: Vector2,
	world_min: Vector3,
	fallback: Color,
	tint: Color,
	single_sheet: bool = false,
	russet: bool = false,
	tile: float = TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> Material:
	if not ResourceLoader.exists(path):
		var fb := StandardMaterial3D.new()
		fb.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		fb.albedo_color = fallback
		return fb
	var src: Texture2D = load(path)
	var mat := ShaderMaterial.new()
	mat.shader = WrapShader.wrap_shader()
	mat.set_shader_parameter("albedo_tex", src)
	var use_tile: float = tile if tile > 0.05 else TILE_W
	if single_sheet:
		mat.set_shader_parameter("uv_scale", Vector2.ONE)
		mat.set_shader_parameter("uv_off", Vector2.ZERO)
	else:
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / use_tile, dim.y / use_tile))
		mat.set_shader_parameter(
			"uv_off",
			Vector2(world_min.x / use_tile, world_min.z / use_tile) + uv_off
		)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("russet", 1.0 if russet else 0.0)
	mat.set_shader_parameter("shade_use", 0.0)
	mat.set_shader_parameter("shade_lo", 1.0)
	mat.set_shader_parameter("shade_hi", 1.0)
	return mat
static func roof_mat(
	dim: Vector2,
	world_min: Vector3,
	tile: float = TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> Material:
	var mat := wrap_mat(
		"res://assets/tiles/plaza_roof.png",
		dim,
		world_min,
		Color(0.55, 0.14, 0.08),
		Color(1.0, 1.0, 1.0),
		false,
		true,
		tile,
		uv_off
	)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("shade_use", 1.0)
		mat.set_shader_parameter("shade_lo", 1.16)
		mat.set_shader_parameter("shade_hi", 0.58)
		var tile_px: float = tile if tile > 0.05 else 0.62
		if tile_px > 0.7:
			tile_px = 0.62
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / tile_px, dim.y / tile_px))
	return mat
static func tarp_mat(dim: Vector2, world_min: Vector3) -> Material:

	return wrap_mat(

		"res://assets/tiles/plaza_tarp.png",

		dim,

		world_min,

		Color(0.40, 0.46, 0.28),

		Color.WHITE,

		true,

		false

	)

static func awning_mat(dim: Vector2, world_min: Vector3) -> Material:

	return wrap_mat(

		"res://assets/tiles/plaza_awning.png",

		dim,

		world_min,

		Color(0.62, 0.22, 0.16),

		Color.WHITE,

		true,

		false

	)
