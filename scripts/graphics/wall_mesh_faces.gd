extends Object

## Ortho wall faces, tops, ends, and void fill.

const T := preload("res://scripts/data/tunables.gd")
const Quad := preload("res://scripts/graphics/wall_mesh_quad.gd")

static func _push_void(cells: Dictionary, faced: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for key in cells.keys():
		var cell: Vector2i = key
		for n2 in dirs:
			var next: Vector2i = cell + n2
			if cells.has(next):
				continue
			var ni: int = Quad._ni(n2)
			if faced.has(Vector3i(cell.x, cell.y, ni)):
				continue
			faced[Vector3i(cell.x, cell.y, ni)] = true
			var x0: float = float(cell.x)
			var z0: float = float(cell.y)
			var x1: float = x0 + 1.0
			var z1: float = z0 + 1.0
			Quad._quad(Quad._corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), Vector3(float(n2.x), 0.0, float(n2.y)), verts, norms, uvs, indices)
			Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, T.WALL_H), Vector2(0.0, T.WALL_H))
static func _push_face(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
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
	Quad._quad(Quad._corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), n, verts, norms, uvs, indices)
	var along: float = float(maxi(span_cells.x, span_cells.y))
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(along, 0.0), Vector2(along, T.WALL_H), Vector2(0.0, T.WALL_H))
static func _push_top(run: Dictionary, topped: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
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
			Quad._quad(top, Vector3.UP, verts, norms, uvs, indices)
			Quad._uv4(uvs, Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1))
static func _push_ends(run: Dictionary, faced: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	if span_cells.x < 1 or span_cells.y < 1:
		return
	var y0: float = 0.0
	var y1: float = T.WALL_H
	if absi(n2.x) > 0:
		_end_row(origin.x, origin.x + span_cells.x, origin.y, Vector2i(0, -1), faced, y0, y1, verts, norms, uvs, indices)
		_end_row(origin.x, origin.x + span_cells.x, origin.y + span_cells.y - 1, Vector2i(0, 1), faced, y0, y1, verts, norms, uvs, indices)
	else:
		_end_col(origin.y, origin.y + span_cells.y, origin.x, Vector2i(-1, 0), faced, y0, y1, verts, norms, uvs, indices)
		_end_col(origin.y, origin.y + span_cells.y, origin.x + span_cells.x - 1, Vector2i(1, 0), faced, y0, y1, verts, norms, uvs, indices)
static func _end_row(x0i: int, x1i: int, z: int, n2: Vector2i, faced: Dictionary, y0: float, y1: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var ni: int = Quad._ni(n2)
	for x in range(x0i, x1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		Quad._quad(Quad._corners(n2, x0, x1, y0, y1, z0, z1), Vector3(0.0, 0.0, float(n2.y)), verts, norms, uvs, indices)
		Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, y1), Vector2(0.0, y1))
static func _end_col(z0i: int, z1i: int, x: int, n2: Vector2i, faced: Dictionary, y0: float, y1: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var ni: int = Quad._ni(n2)
	for z in range(z0i, z1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		Quad._quad(Quad._corners(n2, x0, x1, y0, y1, z0, z1), Vector3(float(n2.x), 0.0, 0.0), verts, norms, uvs, indices)
		Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, y1), Vector2(0.0, y1))
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
	var ni: int = Quad._ni(n2)
	for z in range(origin.y, origin.y + span_cells.y):
		for x in range(origin.x, origin.x + span_cells.x):
			faced[Vector3i(x, z, ni)] = true
