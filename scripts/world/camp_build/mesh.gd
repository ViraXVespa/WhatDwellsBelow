extends Object

const T := preload("res://scripts/data/tunables.gd")

const GroundShader := preload("res://scripts/graphics/ground_shader.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")
const Spec := preload("res://scripts/world/camp/layout_spec.gd")

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
	var g: Array = Spec.SURFACE["grass"]
	var d: Array = Spec.SURFACE["dirt"]
	var p: Array = Spec.SURFACE["path"]
	var yd: Rect2i = Spec.YARD
	var yx1: int = yd.end.x - 1
	var yz1: int = yd.end.y - 1
	# grass frame around the yard
	_band(host, ox, oz, ox + gw - 1, yd.position.y - 1, y, g[0], g[1])
	_band(host, ox, yz1 + 1, ox + gw - 1, oz + gd - 1, y, g[0], g[1])
	_band(host, ox, yd.position.y, yd.position.x - 1, yz1, y, g[0], g[1])
	_band(host, yx1 + 1, yd.position.y, ox + gw - 1, yz1, y, g[0], g[1])
	# yard dirt + path plus; each fades into the surface below it (grass under dirt, dirt under the paths)
	_band(host, yd.position.x, yd.position.y, yx1, yz1, y - 0.01, g[0], g[1])
	_band(host, yd.position.x, yd.position.y, yx1, yz1, y, d[0], d[1], d[2], g[0])
	# The path arms share one union fade so the crossing stays path.
	var arms: Array[Rect2i] = Spec.PATHS
	for i in arms.size():
		var r: Rect2i = arms[i]
		var other: Rect2i = arms[1 - i]
		var o4: Vector4 = _tiles(other.position.x, other.position.y, other.end.x - 1, other.end.y - 1)
		_band(host, r.position.x, r.position.y, r.end.x - 1, r.end.y - 1, y + 0.02, p[0], p[1], p[2], d[0], o4)
	load("res://scripts/world/camp_build.gd").outer_grass(host)

static func _tiles(x0: int, z0: int, x1: int, z1: int) -> Vector4:
	return Vector4(float(x0), float(z0), float(x0) + float(x1 - x0 + 1) * T.TILE, float(z0) + float(z1 - z0 + 1) * T.TILE)

static func _band(
	host: Node3D, x0: int, z0: int, x1: int, z1: int, y: float, tex_path: String, fallback: Color, feather: float = 0.0,
	under: String = "", rect2: Vector4 = Vector4.ZERO
) -> void:
	if x1 < x0 or z1 < z0:
		return
	var sx: float = float(x1 - x0 + 1) * T.TILE
	var sz: float = float(z1 - z0 + 1) * T.TILE
	var c := Vector3(float(x0) + sx * 0.5, y, float(z0) + sz * 0.5)
	grass_pad(host, c, Vector2(sx, sz), tex_path, fallback, feather, under, rect2)

static func grass_pad(

	host: Node3D, center: Vector3, dim: Vector2, tex_path: String, fallback: Color, feather: float = 0.0,
	under: String = "", rect2: Vector4 = Vector4.ZERO
) -> void:

	if dim.x <= 0.05 or dim.y <= 0.05:

		return

	var mesh := PlaneMesh.new()

	mesh.size = dim

	var inst := MeshInstance3D.new()

	inst.mesh = mesh

	inst.position = center

	if feather > 0.0:
		var r := Vector4(center.x - dim.x * 0.5, center.z - dim.y * 0.5, center.x + dim.x * 0.5, center.z + dim.y * 0.5)
		inst.material_override = GroundShader.feathered(tex_path, fallback, r, feather, under, rect2)
	else:
		inst.material_override = GroundShader.material(tex_path, fallback)

	inst.add_to_group("hub_ground")

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
