extends Object

const T := preload("res://scripts/data/tunables.gd")

const GroundShader := preload("res://scripts/graphics/ground_shader.gd")
const Mat := preload("res://scripts/world/camp_build/mesh_mat.gd")
const Tent := preload("res://scripts/world/camp_build/mesh_tent.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")

static func roof_mat(
	dim: Vector2,
	world_min: Vector3,
	tile: float = Mat.TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> Material:
	return Mat.roof_mat(dim, world_min, tile, uv_off)

static func tarp_mat(dim: Vector2, world_min: Vector3) -> Material:
	return Mat.tarp_mat(dim, world_min)

static func attach_awning(
	body: Node3D,
	box_size: Vector3,
	depth: float = Tent.AWNING_DEPTH,
	_slope: float = Tent.AWNING_SLOPE,
	valance: float = Tent.AWNING_VALANCE,
	_eave: float = 0.0,
	inset_l: float = 0.0,
	inset_r: float = 0.0
) -> void:
	Tent.attach_awning(body, box_size, depth, _slope, valance, _eave, inset_l, inset_r)

static func gable_on(body: Node3D, box_size: Vector3, eave: float, rise: float, tile: float, uv_off: Vector2) -> void:
	Tent.gable_on(body, box_size, eave, rise, tile, uv_off)

static func pitched_tarp(body: Node3D, box_size: Vector3, eave: float, _world_min: Vector3) -> void:
	Tent.pitched_tarp(body, box_size, eave, _world_min)

static func ground(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	var gw: int = int(lay.ground_w)
	var gd: int = int(lay.ground_d)
	var ox: int = int(lay.ground_ox)
	var oz: int = int(lay.ground_oz)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(gw), 0.4, float(gd))
	cs.shape = sh
	cs.position = Vector3(float(ox) + float(gw) * 0.5, -0.2, float(oz) + float(gd) * 0.5)
	body.add_child(cs)
	var y: float = T.FLOOR_Y
	# grass frame
	_band(host, ox, oz, ox + gw - 1, 3, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, ox, 25, ox + gw - 1, oz + gd - 1, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, ox, 4, 1, 24, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, 31, 4, ox + gw - 1, 24, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	# yard dirt + path plus
	_band(host, 2, 4, 30, 24, y, "res://assets/tiles/packed_dirt.png", Color(0.46, 0.42, 0.30))
	_band(host, 6, 13, 26, 16, y + 0.02, "res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28))
	_band(host, 15, 8, 17, 22, y + 0.02, "res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28))
	load("res://scripts/world/camp_build.gd").outer_grass(host)

static func _band(host: Node3D, x0: int, z0: int, x1: int, z1: int, y: float, tex_path: String, fallback: Color) -> void:
	if x1 < x0 or z1 < z0:
		return
	var sx: float = float(x1 - x0 + 1) * T.TILE
	var sz: float = float(z1 - z0 + 1) * T.TILE
	var c := Vector3(float(x0) + sx * 0.5, y, float(z0) + sz * 0.5)
	grass_pad(host, c, Vector2(sx, sz), tex_path, fallback)

static func grass_pad(

	host: Node3D, center: Vector3, dim: Vector2, tex_path: String, fallback: Color

) -> void:

	if dim.x <= 0.05 or dim.y <= 0.05:

		return

	var mesh := PlaneMesh.new()

	mesh.size = dim

	var inst := MeshInstance3D.new()

	inst.mesh = mesh

	inst.position = center

	inst.material_override = GroundShader.material(tex_path, fallback)

	host.add_child(inst)

static func wall_box(body: Node3D, box_size: Vector3, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = box_size.x * 0.5
	var hy: float = box_size.y * 0.5
	var hz: float = box_size.z * 0.5
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "Walls"
	inst.mesh = built
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	inst.material_override = mat
	body.add_child(inst)
	var hit := CollisionShape3D.new()
	hit.name = "WallHit"
	hit.shape = built.create_trimesh_shape()
	body.add_child(hit)
