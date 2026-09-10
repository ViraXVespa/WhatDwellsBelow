extends Object

const T := preload("res://scripts/data/tunables.gd")

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
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(GROUND_W), 0.4, float(GROUND_D))
	cs.shape = sh
	cs.position = Vector3(16.0, -0.2, 14.0)
	body.add_child(cs)
	var grass: Array = []
	var packed: Array = []
	var path: Array = []
	for z in GROUND_D:
		for x in GROUND_W:
			var gx := GROUND_OX + x
			var gz := GROUND_OZ + z
			var pos := Vector3(float(gx) + 0.5, T.FLOOR_Y, float(gz) + 0.5)
			var in_yard := gx >= 2 and gx <= 30 and gz >= 4 and gz <= 24
			var on_path := (gz >= 13 and gz <= 16 and gx >= 6 and gx <= 26) or (gx >= 15 and gx <= 17 and gz >= 8 and gz <= 22)
			if not in_yard:
				grass.append(pos)
			elif on_path:
				path.append(pos)
			else:
				packed.append(pos)
	tile_layer(host, "res://assets/tiles/plaza_grass.png", grass, Color(0.34, 0.46, 0.24))
	tile_layer(host, "res://assets/tiles/plaza_ground.png", packed, Color(0.46, 0.42, 0.30))
	tile_layer(host, "res://assets/tiles/plaza_path.png", path, Color(0.44, 0.38, 0.28))
	outer_grass(host)


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
	if points.is_empty():
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var xf := Transform3D.IDENTITY
		xf.origin = points[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color.WHITE
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = fallback
	inst.material_override = mat
	host.add_child(inst)


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
	var y: float = HALL_POS.y + HALL_SIZE.y * 0.5 + 0.03
	var hx0: float = HALL_POS.x - HALL_SIZE.x * 0.5
	var hz0: float = HALL_POS.z - HALL_SIZE.z * 0.5
	var hall_node := Node3D.new()
	hall_node.position = Vector3(HALL_POS.x, y, hz0 + (HALL_SIZE.z + ROOF_EAVE) * 0.5)
	host.add_child(hall_node)
	roof_plane(hall_node, Vector3.ZERO, Vector2(HALL_SIZE.x, HALL_SIZE.z + ROOF_EAVE), Vector3(hx0, 0.0, hz0))
	var wp: Vector3 = wing_pos()
	var wx0: float = HALL_POS.x + HALL_SIZE.x * 0.5
	var wz0: float = wp.z - WING_SIZE.z * 0.5
	var wing_node := Node3D.new()
	wing_node.position = Vector3(wx0 + WING_SIZE.x * 0.5, y + 0.01, wz0 + (WING_SIZE.z + ROOF_EAVE) * 0.5)
	host.add_child(wing_node)
	roof_plane(wing_node, Vector3.ZERO, Vector2(WING_SIZE.x, WING_SIZE.z + ROOF_EAVE), Vector3(wx0, 0.0, wz0))


static func box(host: Node3D, pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var vis := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	vis.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = col
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/tiles/plaza_wall.png"):
		mat.albedo_texture = load("res://assets/tiles/plaza_wall.png")
		mat.albedo_color = Color.WHITE
	vis.material_override = mat
	body.add_child(vis)
	return body


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
	var path := "res://assets/tiles/plaza_roof.png"
	if not ResourceLoader.exists(path):
		var fb := StandardMaterial3D.new()
		fb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fb.albedo_color = Color(0.42, 0.28, 0.22)
		return fb
	var src: Texture2D = load(path)
	var h: float = float(maxi(1, src.get_height()))
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform float v0 = 0.0;
uniform float v1 = 1.0;
void fragment() {
	vec2 uv = UV * uv_scale + uv_off;
	float v = mix(v0, v1, fract(uv.y));
	ALBEDO = texture(albedo_tex, vec2(fract(uv.x), v)).rgb;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", src)
	mat.set_shader_parameter("uv_scale", Vector2(dim.x / TILE_W, dim.y / TILE_W))
	mat.set_shader_parameter("uv_off", Vector2(world_min.x / TILE_W, world_min.z / TILE_W))
	mat.set_shader_parameter("v0", 10.0 / h)
	mat.set_shader_parameter("v1", (h - 5.0) / h)
	return mat


static func roof_plane(host: Node3D, local: Vector3, dim: Vector2, world_min: Vector3) -> void:
	var roof := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dim
	roof.mesh = plane
	roof.position = local
	roof.material_override = roof_mat(dim, world_min)
	host.add_child(roof)
