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
const CampMesh := preload("res://scripts/world/camp_build_mesh.gd")

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
