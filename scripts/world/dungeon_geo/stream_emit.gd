extends Object

## Dungeon stream mesh emit: one shell per chunk, plus no-outline interior floors.

const T := preload("res://scripts/data/tunables.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")
const Commit := preload("res://scripts/graphics/mesh_commit.gd")

static var _floor_mesh: PlaneMesh

static func ensure_meshes() -> void:
	if _floor_mesh == null:
		_floor_mesh = PlaneMesh.new()
		_floor_mesh.size = Vector2(T.TILE, T.TILE)

static func _emit_shell(host: Node, runs: Array, pieces: Array, fine_m: float) -> MeshInstance3D:
	var typed: Array[Dictionary] = []
	for item in runs:
		if item is Dictionary:
			typed.append(item)
	var mesh: ArrayMesh = ArrayMesh.new()
	var has_wall: bool = false
	if not typed.is_empty():
		mesh = WallMesh.from_faces(typed)
		has_wall = mesh.get_surface_count() > 0
	if not pieces.is_empty():
		_add_lip_surface(mesh, pieces, fine_m)
	if mesh.get_surface_count() == 0:
		return null
	var wall_inst: MeshInstance3D = MeshInstance3D.new()
	wall_inst.name = "WallRibbons"
	wall_inst.mesh = mesh
	var scale_m: float = fine_m
	if scale_m < 0.2:
		scale_m = 1.0
	wall_inst.scale = Vector3(scale_m, 1.0, scale_m)
	wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if has_wall:
		wall_inst.set_surface_override_material(0, host.wall_mat)
		if mesh.get_surface_count() > 1:
			wall_inst.set_surface_override_material(1, host.floor_mat)
		_add_wall_body(wall_inst, mesh)
	else:
		wall_inst.set_surface_override_material(0, host.floor_mat)
	return wall_inst

static func _add_lip_surface(mesh: ArrayMesh, pieces: Array, fine_m: float) -> void:
	var built: ArrayMesh = _loop_mesh(pieces, fine_m)
	if built.get_surface_count() < 1:
		return
	var arrays: Array = built.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func _add_wall_body(inst: MeshInstance3D, mesh: ArrayMesh) -> void:
	var tris: PackedVector3Array = _surface_tris(mesh)
	if tris.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.data = tris
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	inst.add_child(body)

static func _surface_tris(mesh: ArrayMesh) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if mesh.get_surface_count() < 1:
		return out
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var i: int = 0
	while i + 2 < indices.size():
		out.append(verts[indices[i]])
		out.append(verts[indices[i + 1]])
		out.append(verts[indices[i + 2]])
		i += 3
	return out
static func _mask(host: Node) -> Dictionary:
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	if host.data.has("solid") and host.data["solid"] is PackedByteArray:
		var fine: float = float(host.data.get("outline_fine_m", 1.0))
		if fine < 0.2:
			fine = 0.25
		return {
			"solid": host.data["solid"],
			"sw": int(host.data["solid_w"]),
			"sh": int(host.data["solid_h"]),
			"n": maxi(1, int(host.data["solid_n"])),
			"fine": fine,
		}
	return {"solid": host.data.grid, "sw": w, "sh": h, "n": 1, "fine": 1.0}

static func _emit_floors(rects: Array[Rect2i], fine_m: float, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _floor_mesh
	mm.instance_count = rects.size()
	for i in rects.size():
		var r: Rect2i = rects[i]
		var sx: float = float(r.size.x) * fine_m
		var sz: float = float(r.size.y) * fine_m
		var basis := Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, sz))
		var at := Vector3((float(r.position.x) + float(r.size.x) * 0.5) * fine_m, T.FLOOR_Y, (float(r.position.y) + float(r.size.y) * 0.5) * fine_m)
		mm.set_instance_transform(i, Transform3D(basis, at))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	return inst

static func _lip_pieces(spans: Array, x0: int, y0: int, x1: int, y1: int) -> Array:
	var loops: Array = spans
	var box: PackedVector2Array = PackedVector2Array()
	var grow: float = 1.0
	box.append(Vector2(float(x0) - grow, float(y0) - grow))
	box.append(Vector2(float(x1) + grow, float(y0) - grow))
	box.append(Vector2(float(x1) + grow, float(y1) + grow))
	box.append(Vector2(float(x0) - grow, float(y1) + grow))
	var pieces: Array = []
	for loop_v in loops:
		var loop: PackedVector2Array = loop_v
		if loop.size() < 3:
			continue
		var clipped: Array = Geometry2D.intersect_polygons(loop, box)
		for poly_v in clipped:
			var poly: PackedVector2Array = poly_v
			if poly.size() >= 3:
				pieces.append(poly)
	return pieces

static func _loop_mesh(pieces: Array, fine_m: float) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for piece in pieces:
		var poly: PackedVector2Array = piece as PackedVector2Array
		if poly.size() < 3:
			continue
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			poly.reverse()
			tris = Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			continue
		var base: int = verts.size()
		for i in poly.size():
			var p: Vector2 = poly[i]
			verts.append(Vector3(p.x, T.FLOOR_Y, p.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(p.x * fine_m, p.y * fine_m))
		for k in tris.size():
			indices.append(base + int(tris[k]))
	return Commit.commit(verts, norms, uvs, indices)
