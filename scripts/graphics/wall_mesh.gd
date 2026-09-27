extends Object

## Quads for WallRects.faces runs. One meter per cell. Visible side looks at the floor.
## One top per wall cell. End caps only when that plane is not already a face.

const T := preload("res://scripts/data/tunables.gd")


static func from_faces(runs: Array[Dictionary]) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var faced: Dictionary = {}
	var topped: Dictionary = {}
	var cells: Dictionary = {}
	for run in runs:
		if run.has("delta"):
			continue
		_mark_faces(run, faced)
		_mark_cells(run, cells)
	for run in runs:
		if run.has("delta"):
			_push_span(run, verts, norms, indices)
			continue
		_push_face(run, verts, norms, indices)
		_push_top(run, topped, verts, norms, indices)
		_push_ends(run, faced, verts, norms, indices)
	_push_void(cells, faced, verts, norms, indices)
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


static func _push_span(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
    var o: Vector2 = run["origin"] as Vector2
    var d: Vector2 = run["delta"] as Vector2
    if d.length_squared() < 0.25:
        return
    var n2: Vector2 = run["normal"] as Vector2
    if n2.length_squared() < 0.0001:
        n2 = Vector2(-d.y, d.x)
    n2 = n2.normalized()
    var thick: float = float(run.get("thick", 4.0))
    if thick < 1.0:
        thick = 1.0
    var v: Vector2 = n2 * -thick
    var a: Vector2 = o
    var b: Vector2 = o + d
    var a2: Vector2 = a + v
    var b2: Vector2 = b + v
    var h: float = T.WALL_H
    var nf: Vector3 = Vector3(n2.x, 0.0, n2.y)
    var front: PackedVector3Array = PackedVector3Array()
    front.append(Vector3(a.x, 0.0, a.y))
    front.append(Vector3(b.x, 0.0, b.y))
    front.append(Vector3(b.x, h, b.y))
    front.append(Vector3(a.x, h, a.y))
    _quad(front, nf, verts, norms, indices)
    var back: PackedVector3Array = PackedVector3Array()
    back.append(Vector3(b2.x, 0.0, b2.y))
    back.append(Vector3(a2.x, 0.0, a2.y))
    back.append(Vector3(a2.x, h, a2.y))
    back.append(Vector3(b2.x, h, b2.y))
    _quad(back, -nf, verts, norms, indices)
    var top: PackedVector3Array = PackedVector3Array()
    top.append(Vector3(a.x, h, a.y))
    top.append(Vector3(b.x, h, b.y))
    top.append(Vector3(b2.x, h, b2.y))
    top.append(Vector3(a2.x, h, a2.y))
    _quad(top, Vector3.UP, verts, norms, indices)
    var e0: PackedVector3Array = PackedVector3Array()
    e0.append(Vector3(a.x, 0.0, a.y))
    e0.append(Vector3(a.x, h, a.y))
    e0.append(Vector3(a2.x, h, a2.y))
    e0.append(Vector3(a2.x, 0.0, a2.y))
    _quad(e0, Vector3(-d.y, 0.0, d.x).normalized(), verts, norms, indices)
    var e1: PackedVector3Array = PackedVector3Array()
    e1.append(Vector3(b.x, 0.0, b.y))
    e1.append(Vector3(b2.x, 0.0, b2.y))
    e1.append(Vector3(b2.x, h, b2.y))
    e1.append(Vector3(b.x, h, b.y))
    _quad(e1, Vector3(d.y, 0.0, -d.x).normalized(), verts, norms, indices)


static func _push_void(cells: Dictionary, faced: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for key in cells.keys():
		var cell: Vector2i = key
		for n2 in dirs:
			var next: Vector2i = cell + n2
			if cells.has(next):
				continue
			var ni: int = _ni(n2)
			if faced.has(Vector3i(cell.x, cell.y, ni)):
				continue
			faced[Vector3i(cell.x, cell.y, ni)] = true
			var x0: float = float(cell.x)
			var z0: float = float(cell.y)
			var x1: float = x0 + 1.0
			var z1: float = z0 + 1.0
			_quad(_corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), Vector3(float(n2.x), 0.0, float(n2.y)), verts, norms, indices)


static func _ni(n2: Vector2i) -> int:
	if n2.x > 0:
		return 0
	if n2.x < 0:
		return 1
	if n2.y > 0:
		return 2
	return 3


static func _mark_cells(run: Dictionary, cells: Dictionary) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	for z in range(origin.y, origin.y + span_cells.y):
		for x in range(origin.x, origin.x + span_cells.x):
			cells[Vector2i(x, z)] = true


static func _mark_faces(run: Dictionary, faced: Dictionary) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	var ni: int = _ni(n2)
	for z in range(origin.y, origin.y + span_cells.y):
		for x in range(origin.x, origin.x + span_cells.x):
			faced[Vector3i(x, z, ni)] = true


static func _push_face(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	if span_cells.x < 1 or span_cells.y < 1:
		return
	var x0: float = float(origin.x)
	var z0: float = float(origin.y)
	var x1: float = x0 + float(span_cells.x)
	var z1: float = z0 + float(span_cells.y)
	var n: Vector3 = Vector3(float(n2.x), 0.0, float(n2.y))
	_quad(_corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), n, verts, norms, indices)


static func _push_top(run: Dictionary, topped: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	for z in range(origin.y, origin.y + span_cells.y):
		for x in range(origin.x, origin.x + span_cells.x):
			var key: Vector2i = Vector2i(x, z)
			if topped.has(key):
				continue
			topped[key] = true
			var x0: float = float(x)
			var z0: float = float(z)
			var x1: float = x0 + 1.0
			var z1: float = z0 + 1.0
			var y1: float = T.WALL_H
			var top: PackedVector3Array = PackedVector3Array()
			top.append(Vector3(x0, y1, z0))
			top.append(Vector3(x1, y1, z0))
			top.append(Vector3(x1, y1, z1))
			top.append(Vector3(x0, y1, z1))
			_quad(top, Vector3.UP, verts, norms, indices)


static func _push_ends(run: Dictionary, faced: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	if span_cells.x < 1 or span_cells.y < 1:
		return
	var y0: float = 0.0
	var y1: float = T.WALL_H
	if absi(n2.x) > 0:
		_end_row(origin.x, origin.x + span_cells.x, origin.y, Vector2i(0, -1), faced, y0, y1, verts, norms, indices)
		_end_row(origin.x, origin.x + span_cells.x, origin.y + span_cells.y - 1, Vector2i(0, 1), faced, y0, y1, verts, norms, indices)
	else:
		_end_col(origin.y, origin.y + span_cells.y, origin.x, Vector2i(-1, 0), faced, y0, y1, verts, norms, indices)
		_end_col(origin.y, origin.y + span_cells.y, origin.x + span_cells.x - 1, Vector2i(1, 0), faced, y0, y1, verts, norms, indices)


static func _end_row(x0i: int, x1i: int, z: int, n2: Vector2i, faced: Dictionary, y0: float, y1: float, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var ni: int = _ni(n2)
	for x in range(x0i, x1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		_quad(_corners(n2, x0, x1, y0, y1, z0, z1), Vector3(0.0, 0.0, float(n2.y)), verts, norms, indices)


static func _end_col(z0i: int, z1i: int, x: int, n2: Vector2i, faced: Dictionary, y0: float, y1: float, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var ni: int = _ni(n2)
	for z in range(z0i, z1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		_quad(_corners(n2, x0, x1, y0, y1, z0, z1), Vector3(float(n2.x), 0.0, 0.0), verts, norms, indices)


static func _quad(corners: PackedVector3Array, n: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array) -> void:
	var base: int = verts.size()
	for i in range(corners.size()):
		verts.append(corners[i])
		norms.append(n)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 1)
	indices.append(base)
	indices.append(base + 3)
	indices.append(base + 2)


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
