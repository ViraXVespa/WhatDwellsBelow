extends Object

## Camp mesh primitives: quad, triangle, hit box, timber.

static func _quad(

	st: SurfaceTool,

	p0: Vector3,

	p1: Vector3,

	p2: Vector3,

	p3: Vector3,

	t0: Vector2,

	t1: Vector2,

	t2: Vector2,

	t3: Vector2

) -> void:

	_tri(st, p0, p1, p2, t0, t1, t2)

	_tri(st, p0, p2, p3, t0, t2, t3)

static func _tri(

	st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, t0: Vector2, t1: Vector2, t2: Vector2

) -> void:

	st.set_uv(t0)

	st.add_vertex(p0)

	st.set_uv(t1)

	st.add_vertex(p1)

	st.set_uv(t2)

	st.add_vertex(p2)

static func _hit(body: Node3D, built: ArrayMesh, label: String) -> void:
	var hit := CollisionShape3D.new()
	hit.name = label
	hit.shape = built.create_trimesh_shape()
	body.add_child(hit)

static func _timber(col: Color) -> Material:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
