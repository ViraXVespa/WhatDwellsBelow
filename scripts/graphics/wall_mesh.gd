extends Object

## Span ribbons, one per wall. Ortho faces only when a chunk has no outline spans.
## UV runs along the span and up the wall. Visible side looks at the floor.

const T := preload("res://scripts/data/tunables.gd")
const Quad := preload("res://scripts/graphics/wall_mesh/mesh_quad.gd")
const Span := preload("res://scripts/graphics/wall_mesh/mesh_span.gd")
const Faces := preload("res://scripts/graphics/wall_mesh/faces.gd")
const Fold := preload("res://scripts/graphics/wall_mesh/mesh_fold.gd")

static func from_faces(runs: Array[Dictionary]) -> ArrayMesh:
	var ortho: Array[Dictionary] = []
	var delta: Array[Dictionary] = []
	for run in runs:
		if run.has("delta"):
			delta.append(run)
		else:
			ortho.append(run)
	var ribbons: Array[Dictionary] = Fold.prepare(delta)
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var _uv2s: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	Quad._uv2_buf = PackedVector2Array()
	Quad._uv2_in = Vector2.ZERO
	var faced: Dictionary = {}
	var topped: Dictionary = {}
	var cells: Dictionary = {}
	for run in ortho:
		Faces._mark_faces(run, faced)
		Faces._mark_cells(run, cells)
	Span._close_ribbon_corners(ribbons, verts, norms, uvs, indices)
	for run in ribbons:
		Span._push_span(run, verts, norms, uvs, indices)
	if ribbons.is_empty():
		for run in ortho:
			Faces._push_face(run, verts, norms, uvs, indices)
			Faces._push_top(run, topped, verts, norms, uvs, indices)
			Faces._push_ends(run, faced, verts, norms, uvs, indices)
		if not ortho.is_empty():
			Faces._push_void(cells, faced, verts, norms, uvs, indices)
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = Quad._uv2_buf
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
## Fold stair teeth and duplicate opposite spans before the chunk is skinned.
static func prepare(raw: Array) -> Array[Dictionary]:
	return Fold.prepare(raw)
