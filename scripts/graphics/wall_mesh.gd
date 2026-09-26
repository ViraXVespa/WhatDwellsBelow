extends Object

## Quads for WallRects.faces runs. One meter per cell. Visible side looks at the floor.

const T := preload("res://scripts/data/tunables.gd")


static func from_faces(runs: Array[Dictionary]) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for run in runs:
		_push(run, verts, norms, indices)
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _push(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	if span_cells.x < 1 or span_cells.y < 1:
		return
	var x0: float = float(origin.x)
	var z0: float = float(origin.y)
	var x1: float = x0 + float(span_cells.x)
	var z1: float = z0 + float(span_cells.y)
	var y0: float = 0.0
	var y1: float = T.WALL_H
	var n: Vector3 = Vector3(float(n2.x), 0.0, float(n2.y))
	var corners: PackedVector3Array = _corners(n2, x0, x1, y0, y1, z0, z1)
	var base: int = verts.size()
	for i in range(corners.size()):
		verts.append(corners[i])
		norms.append(n)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)


static func _corners(n2: Vector2i, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> PackedVector3Array:
	var quad: PackedVector3Array = PackedVector3Array()
	if n2.x > 0:
		quad.append(Vector3(x1, y0, z1))
		quad.append(Vector3(x1, y0, z0))
		quad.append(Vector3(x1, y1, z0))
		quad.append(Vector3(x1, y1, z1))
	elif n2.x < 0:
		quad.append(Vector3(x0, y0, z0))
		quad.append(Vector3(x0, y0, z1))
		quad.append(Vector3(x0, y1, z1))
		quad.append(Vector3(x0, y1, z0))
	elif n2.y > 0:
		quad.append(Vector3(x0, y0, z1))
		quad.append(Vector3(x1, y0, z1))
		quad.append(Vector3(x1, y1, z1))
		quad.append(Vector3(x0, y1, z1))
	else:
		quad.append(Vector3(x1, y0, z0))
		quad.append(Vector3(x0, y0, z0))
		quad.append(Vector3(x0, y1, z0))
		quad.append(Vector3(x1, y1, z0))
	return quad
