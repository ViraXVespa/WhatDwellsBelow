extends Object

const T := preload("res://scripts/data/tunables.gd")
const MeshS := preload("res://scripts/world/camp_build_mesh.gd")
const Roof := preload("res://scripts/world/camp_build_roof.gd")

const GROUND_W := 36
const GROUND_D := 32
const GROUND_OX := -2
const GROUND_OZ := -2
const GRASS_PAD := 16
const ROOF_EAVE := 0.42
const TILE_W := 3.2
const HALL_SIZE := Vector3(5.6, 3.4, 4.2)
const WING_SIZE := Vector3(3.8, 2.7, 3.2)
const HALL_POS := Vector3(8.2, 1.7, 6.0)
const PATH_X := 16.5
const PATH_Z := 15.0


static func world(host: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.58, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.86, 0.7)
	e.ambient_light_energy = 1.15
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.9
	host.add_child(sun)


static func ground(host: Node3D) -> void:
	MeshS.ground(host)


static func outer_grass(host: Node3D) -> void:
	var points: Array = []
	var x0: int = GROUND_OX - GRASS_PAD
	var z0: int = GROUND_OZ - GRASS_PAD
	var x1: int = GROUND_OX + GROUND_W + GRASS_PAD
	var z1: int = GROUND_OZ + GROUND_D + GRASS_PAD
	for z in range(z0, z1):
		for x in range(x0, x1):
			var inside: bool = x >= GROUND_OX and x < GROUND_OX + GROUND_W and z >= GROUND_OZ and z < GROUND_OZ + GROUND_D
			if inside:
				continue
			points.append(Vector3(float(x) + 0.5, T.FLOOR_Y, float(z) + 0.5))
	tile_layer(host, "res://assets/tiles/plaza_grass.png", points, Color(0.34, 0.46, 0.24))


static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	MeshS.tile_layer(host, tex_path, points, fallback)


static func buildings(host: Node3D) -> void:
	guild(host)
	solid(host, Vector3(25.0, 1.2, 8.0), Vector3(4.6, 2.4, 3.4), Color(0.55, 0.35, 0.2), "res://assets/sprites/buildings/stall.png")


static func wing_pos() -> Vector3:
	var back: float = HALL_POS.z - HALL_SIZE.z * 0.5
	return Vector3(HALL_POS.x + HALL_SIZE.x * 0.5 + WING_SIZE.x * 0.5 - 0.12, WING_SIZE.y * 0.5, back + WING_SIZE.z * 0.5)


static func guild(host: Node3D) -> void:
	var hall_body: StaticBody3D = box(host, HALL_POS, HALL_SIZE, Color(0.45, 0.32, 0.22))
	var wing_body: StaticBody3D = box(host, wing_pos(), WING_SIZE, Color(0.5, 0.38, 0.28))
	face(hall_body, HALL_SIZE, "res://assets/sprites/buildings/guild.png", 0.0, HALL_SIZE.x)
	face(wing_body, WING_SIZE, "res://assets/sprites/buildings/guild_reception.png", 0.0, WING_SIZE.x)
	guild_roofs(host)


static func guild_roofs(host: Node3D) -> void:
	MeshS.guild_roofs(host)


static func box(host: Node3D, pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	return Roof.box(host, pos, size, col)


static func solid(host: Node3D, pos: Vector3, size: Vector3, col: Color, tex: String) -> void:
	var body: StaticBody3D = box(host, pos, size, col)
	var x0: float = pos.x - size.x * 0.5
	var z0: float = pos.z - size.z * 0.5
	roof_plane(body, Vector3(0.0, size.y * 0.5 + 0.03, ROOF_EAVE * 0.5), Vector2(size.x + 0.06, size.z + ROOF_EAVE), Vector3(x0, 0.0, z0))
	face(body, size, tex, 0.0, size.x)


static func face(body: Node3D, size: Vector3, tex: String, x_off: float, face_w: float) -> void:
	if not ResourceLoader.exists(tex):
		return
	var spr := Sprite3D.new()
	spr.texture = load(tex)
	spr.centered = true
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tw := float(maxi(1, spr.texture.get_width()))
	var th := float(maxi(1, spr.texture.get_height()))
	spr.pixel_size = minf(face_w / tw, size.y / th)
	spr.position = Vector3(x_off, 0.0, size.z * 0.5 + 0.05)
	body.add_child(spr)


static func roof_mat(dim: Vector2, world_min: Vector3) -> Material:
	return MeshS.roof_mat(dim, world_min)


static func roof_plane(host: Node3D, local: Vector3, dim: Vector2, world_min: Vector3) -> void:
	var roof := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dim
	roof.mesh = plane
	roof.position = local
	roof.material_override = roof_mat(dim, world_min)
	host.add_child(roof)
