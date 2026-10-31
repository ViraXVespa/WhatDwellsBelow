extends Object

## Camp mesh materials: wrapped, roof, tarp, awning.

const FaceLit := preload("res://scripts/world/camp_build/face_lit.gd")
const HubCast := preload("res://scripts/graphics/light_rt/hub_cast.gd")
const WrapShader := preload("res://scripts/graphics/wrap_shader.gd")
const T := preload("res://scripts/data/tunables.gd")
const Chunky := preload("res://scripts/graphics/chunky.gd")
## plaza_roof.png: sheet v of the mortar-band middle at the sheet edge (2 px of 1024 above the wrap).
const RIDGE_V := -2.0 / 1024.0
const TILE_W: float = preload("res://scripts/world/camp/layout_spec.gd").TILE_W

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
	var use_tile: float = tile if tile > 0.05 else TILE_W
	# Roofs, tarps, walls at the hub ground pixel size (metres per texel from how the sheet wraps).
	if not App.in_dungeon and src != null:
		src = Chunky.tex(src, (dim.x if single_sheet else use_tile) / float(maxi(1, src.get_width())))
	var mat := ShaderMaterial.new()
	mat.shader = WrapShader.wrap_shader()
	mat.set_shader_parameter("albedo_tex", src)
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
		# The hub sun comes from the north-west (HubCast.AWAY): the far slope faces it (bright, a little brighter at
		# the ridge), the near slope turns away and darkens toward its eave. Two planes, not one ramp mirrored at the ridge.
		mat.set_shader_parameter("shade_n", Vector2(1.06, 1.0))
		mat.set_shader_parameter("shade_lo", 1.0)
		mat.set_shader_parameter("shade_hi", 0.66)
		# Default repeat keeps the ground's texel density (T.GROUND_PX_PER_M) so shingles read as pixel art.
		var sheet: Texture2D = mat.get_shader_parameter("albedo_tex")
		var tile_m: float = tile if tile > 0.05 and tile != TILE_W else float(sheet.get_width()) / T.GROUND_PX_PER_M
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / tile_m, dim.y / tile_m))
		# The ridge (v = 0 on both slopes) sits RIDGE_V into the sheet: the middle of the mortar band that wraps the
		# sheet edge (rows 1022-1023 + course 0), so each slope shows half the band and the ridge is one mortar line.
		mat.set_shader_parameter("uv_off", Vector2(fposmod(world_min.x / tile_m + uv_off.x, 1.0), RIDGE_V))
	return mat

static func tarp_mat(dim: Vector2, world_min: Vector3) -> Material:
	return _cloth("res://assets/tiles/plaza_tarp.png", dim, world_min, Color(0.40, 0.46, 0.28))

## Stripes run along v, so v spans dim.y / dim.x of the sheet: square texels, no mip collapse to a pink band.
static func awning_mat(dim: Vector2, world_min: Vector3) -> Material:
	var mat: Material = _cloth("res://assets/tiles/plaza_awning.png", dim, world_min, Color(0.62, 0.22, 0.16))
	if mat is ShaderMaterial:
		mat.set_shader_parameter("uv_scale", Vector2(1.0, dim.y / maxf(dim.x, 0.01)))
	return mat

## Awning / tarp cloth lit the way the building faces are (face_lit.gd): the yard light in front of it (building and
## neighbour shadows, lantern pools), the faces' side fall-off over world x range x_ends (FaceLit.EDGE), and its
## slope against the hub sun (SLOPE_K).
const SLOPE_K := 0.2
static func face_light(mat: Material, face_z: float, x_ends := Vector2.ZERO) -> void:
	if not mat is ShaderMaterial:
		return
	var sun := Vector3(-HubCast.AWAY.x, 1.0 / HubCast.REACH, -HubCast.AWAY.y).normalized()
	mat.set_shader_parameter("face_light", 1.0)
	mat.set_shader_parameter("face_z", face_z)
	mat.set_shader_parameter("ahead", FaceLit.AHEAD)
	mat.set_shader_parameter("k", FaceLit.K)
	mat.set_shader_parameter("floor_l", HubCast.SHADE_NEAR)
	mat.set_shader_parameter("lift", FaceLit.LIFT)
	mat.set_shader_parameter("shade_to", FaceLit.SHADE_TO)
	mat.set_shader_parameter("sun_dir", sun)
	mat.set_shader_parameter("slope_k", SLOPE_K)
	if x_ends != Vector2.ZERO:
		mat.set_shader_parameter("face_x", x_ends)
		mat.set_shader_parameter("edge", Vector2(FaceLit.EDGE, FaceLit.EDGE_SPAN))
		mat.set_shader_parameter("eave", Vector2(FaceLit.EAVE, FaceLit.EAVE_SPAN))

## Cloth (tarp, awning): wrap_mat with a white second tint, flags true, false.
static func _cloth(png: String, dim: Vector2, world_min: Vector3, tint: Color) -> Material:
	return wrap_mat(png, dim, world_min, tint, Color.WHITE, true, false)
