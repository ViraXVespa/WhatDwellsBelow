extends Object

## Span ribbons, one per wall. Ortho faces only when a chunk has no outline spans.
## UV runs along the span and up the wall. Visible side looks at the floor.

const T := preload("res://scripts/data/tunables.gd")


static func from_faces(runs: Array[Dictionary]) -> ArrayMesh:
	var ortho: Array[Dictionary] = []
	var delta: Array[Dictionary] = []
	for run in runs:
		if run.has("delta"):
			delta.append(run)
		else:
			ortho.append(run)
	var ribbons: Array[Dictionary] = prepare(delta)
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var _uv2s: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	_uv2_buf = PackedVector2Array()
	_uv2_in = Vector2.ZERO
	var faced: Dictionary = {}
	var topped: Dictionary = {}
	var cells: Dictionary = {}
	for run in ortho:
		_mark_faces(run, faced)
		_mark_cells(run, cells)
	_close_ribbon_corners(ribbons, verts, norms, uvs, indices)
	for run in ribbons:
		_push_span(run, verts, norms, uvs, indices)
	if ribbons.is_empty():
		for run in ortho:
			_push_face(run, verts, norms, uvs, indices)
			_push_top(run, topped, verts, norms, uvs, indices)
			_push_ends(run, faced, verts, norms, uvs, indices)
		if not ortho.is_empty():
			_push_void(cells, faced, verts, norms, uvs, indices)
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2_buf
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _push_span(run: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var o: Vector2 = run["origin"] as Vector2
	var d: Vector2 = run["delta"] as Vector2
	if d.length_squared() < 0.04:
		return
	var n2: Vector2 = run["normal"] as Vector2
	if n2.length_squared() < 0.0001:
		n2 = Vector2(-d.y, d.x)
	n2 = n2.normalized()
	var thick: float = float(run.get("thick", 1.0))
	if thick <= 0.0 or thick > 1.5:
		thick = 1.0
	var v: Vector2 = n2 * -thick
	var a: Vector2 = o
	var b: Vector2 = o + d
	var a2: Vector2 = a + v
	var b2: Vector2 = b + v
	var h: float = T.WALL_H
	var run_len: float = d.length()
	var nf: Vector3 = Vector3(n2.x, 0.0, n2.y)
	_uv2_in = n2
	var cap_a: bool = true
	var cap_b: bool = true
	if run.has("cap_a"):
		cap_a = run["cap_a"] == true
	if run.has("cap_b"):
		cap_b = run["cap_b"] == true
	var front: PackedVector3Array = PackedVector3Array()
	front.append(Vector3(a.x, 0.0, a.y))
	front.append(Vector3(b.x, 0.0, b.y))
	front.append(Vector3(b.x, h, b.y))
	front.append(Vector3(a.x, h, a.y))
	_quad(front, nf, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(run_len, 0.0), Vector2(run_len, h), Vector2(0.0, h))
	var back: PackedVector3Array = PackedVector3Array()
	back.append(Vector3(b2.x, 0.0, b2.y))
	back.append(Vector3(a2.x, 0.0, a2.y))
	back.append(Vector3(a2.x, h, a2.y))
	back.append(Vector3(b2.x, h, b2.y))
	_quad(back, -nf, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(run_len, 0.0), Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(run_len, h))
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(a.x, h, a.y))
	top.append(Vector3(b.x, h, b.y))
	top.append(Vector3(b2.x, h, b2.y))
	top.append(Vector3(a2.x, h, a2.y))
	_quad(top, Vector3.UP, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(run_len, 0.0), Vector2(run_len, thick), Vector2(0.0, thick))
	if cap_a:
		var e0: PackedVector3Array = PackedVector3Array()
		e0.append(Vector3(a.x, 0.0, a.y))
		e0.append(Vector3(a.x, h, a.y))
		e0.append(Vector3(a2.x, h, a2.y))
		e0.append(Vector3(a2.x, 0.0, a2.y))
		var n_start: Vector3 = Vector3(-d.x, 0.0, -d.y).normalized()
		_quad(e0, n_start, verts, norms, uvs, indices)
		_uv4(uvs, Vector2(0.0, 0.0), Vector2(0.0, h), Vector2(thick, h), Vector2(thick, 0.0))
	_uv2_in = n2
	if cap_b:
		var e1: PackedVector3Array = PackedVector3Array()
		e1.append(Vector3(b.x, 0.0, b.y))
		e1.append(Vector3(b2.x, 0.0, b2.y))
		e1.append(Vector3(b2.x, h, b2.y))
		e1.append(Vector3(b.x, h, b.y))
		var n_end: Vector3 = Vector3(d.x, 0.0, d.y).normalized()
		_quad(e1, n_end, verts, norms, uvs, indices)
		_uv4(uvs, Vector2(0.0, 0.0), Vector2(thick, 0.0), Vector2(thick, h), Vector2(0.0, h))



static func _close_ribbon_corners(runs: Array[Dictionary], verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var pts: Dictionary = {}
	var i: int = 0
	while i < runs.size():
		var run: Dictionary = runs[i]
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var b: Vector2 = o + d
		var ka: Vector2i = _pt_key(o)
		var kb: Vector2i = _pt_key(b)
		if not pts.has(ka):
			pts[ka] = []
		if not pts.has(kb):
			pts[kb] = []
		(pts[ka] as Array).append({"i": i, "end": "a", "n": run.get("normal", Vector2.ZERO), "thick": float(run.get("thick", 1.0)), "p": o})
		(pts[kb] as Array).append({"i": i, "end": "b", "n": run.get("normal", Vector2.ZERO), "thick": float(run.get("thick", 1.0)), "p": b})
		i += 1
	for key in pts.keys():
		var hits: Array = pts[key]
		if hits.size() < 2:
			continue
		var nsum: Vector2 = Vector2.ZERO
		var thick: float = 1.0
		var p: Vector2 = (hits[0] as Dictionary)["p"]
		for raw in hits:
			var hit: Dictionary = raw
			var ri: int = int(hit["i"])
			var run2: Dictionary = runs[ri]
			if str(hit["end"]) == "a":
				run2["cap_a"] = false
			else:
				run2["cap_b"] = false
			nsum += hit["n"] as Vector2
			thick = maxf(thick, float(hit["thick"]))
			p = hit["p"] as Vector2
		if nsum.length_squared() < 0.0001:
			nsum = Vector2.DOWN
		_corner_post(p, nsum.normalized(), thick, T.WALL_H, verts, norms, uvs, indices)


static func _corner_post(p: Vector2, n2: Vector2, thick: float, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var t: float = maxf(0.25, thick)
	var nx: float = 0.0
	var nz: float = 0.0
	if absf(n2.x) >= 0.01:
		nx = -t if n2.x > 0.0 else t
	if absf(n2.y) >= 0.01:
		nz = -t if n2.y > 0.0 else t
	if absf(nx) < 0.01 and absf(nz) < 0.01:
		nx = -t
		nz = -t
	var x0: float = p.x if nx >= 0.0 else p.x + nx
	var x1: float = p.x + nx if nx >= 0.0 else p.x
	var z0: float = p.y if nz >= 0.0 else p.y + nz
	var z1: float = p.y + nz if nz >= 0.0 else p.y
	if x1 < x0:
		var sx: float = x0
		x0 = x1
		x1 = sx
	if z1 < z0:
		var sz: float = z0
		z0 = z1
		z1 = sz
	var y0: float = 0.0
	var y1: float = h
	var west: PackedVector3Array = PackedVector3Array()
	west.append(Vector3(x0, y0, z0))
	west.append(Vector3(x0, y0, z1))
	west.append(Vector3(x0, y1, z1))
	west.append(Vector3(x0, y1, z0))
	_quad(west, Vector3.LEFT, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var east: PackedVector3Array = PackedVector3Array()
	east.append(Vector3(x1, y0, z1))
	east.append(Vector3(x1, y0, z0))
	east.append(Vector3(x1, y1, z0))
	east.append(Vector3(x1, y1, z1))
	_quad(east, Vector3.RIGHT, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var north: PackedVector3Array = PackedVector3Array()
	north.append(Vector3(x0, y0, z1))
	north.append(Vector3(x1, y0, z1))
	north.append(Vector3(x1, y1, z1))
	north.append(Vector3(x0, y1, z1))
	_quad(north, Vector3.FORWARD, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var south: PackedVector3Array = PackedVector3Array()
	south.append(Vector3(x1, y0, z0))
	south.append(Vector3(x0, y0, z0))
	south.append(Vector3(x0, y1, z0))
	south.append(Vector3(x1, y1, z0))
	_quad(south, Vector3.BACK, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, h), Vector2(0.0, h))
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(x0, y1, z0))
	top.append(Vector3(x0, y1, z1))
	top.append(Vector3(x1, y1, z1))
	top.append(Vector3(x1, y1, z0))
	_quad(top, Vector3.UP, verts, norms, uvs, indices)
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(t, 0.0), Vector2(t, t), Vector2(0.0, t))

static func _uv4(uvs: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	var base: int = uvs.size() - 4
	uvs[base] = a
	uvs[base + 1] = b
	uvs[base + 2] = c
	uvs[base + 3] = d


static func _push_void(cells: Dictionary, faced: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
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
			_quad(_corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), Vector3(float(n2.x), 0.0, float(n2.y)), verts, norms, uvs, indices)
			_uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, T.WALL_H), Vector2(0.0, T.WALL_H))


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
	_quad(_corners(n2, x0, x1, 0.0, T.WALL_H, z0, z1), n, verts, norms, uvs, indices)
	var along: float = float(maxi(span_cells.x, span_cells.y))
	_uv4(uvs, Vector2(0.0, 0.0), Vector2(along, 0.0), Vector2(along, T.WALL_H), Vector2(0.0, T.WALL_H))


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
			_quad(top, Vector3.UP, verts, norms, uvs, indices)
			_uv4(uvs, Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1))


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
	var ni: int = _ni(n2)
	for x in range(x0i, x1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		_quad(_corners(n2, x0, x1, y0, y1, z0, z1), Vector3(0.0, 0.0, float(n2.y)), verts, norms, uvs, indices)
		_uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, y1), Vector2(0.0, y1))


static func _end_col(z0i: int, z1i: int, x: int, n2: Vector2i, faced: Dictionary, y0: float, y1: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var ni: int = _ni(n2)
	for z in range(z0i, z1i):
		if faced.has(Vector3i(x, z, ni)):
			continue
		var x0: float = float(x)
		var x1: float = x0 + 1.0
		var z0: float = float(z)
		var z1: float = z0 + 1.0
		_quad(_corners(n2, x0, x1, y0, y1, z0, z1), Vector3(float(n2.x), 0.0, 0.0), verts, norms, uvs, indices)
		_uv4(uvs, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, y1), Vector2(0.0, y1))


static var _uv2_buf: PackedVector2Array = PackedVector2Array()
static var _uv2_in: Vector2 = Vector2.ZERO


static func _quad(corners: PackedVector3Array, n: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var base: int = verts.size()
	for i in range(corners.size()):
		verts.append(corners[i])
		norms.append(n)
		uvs.append(Vector2.ZERO)
		_uv2_buf.append(_uv2_in)
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


## Fold stair teeth and duplicate opposite spans before the chunk is skinned.
static func prepare(raw: Array) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary and (item as Dictionary).has("delta"):
			runs.append(item as Dictionary)
	if runs.is_empty():
		return runs
	return _merge_opposite(_fold_teeth(runs))


static func _pt_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 5.0), roundi(p.y * 5.0))


static func _unit2(v: Vector2) -> Vector2:
	if v.length_squared() < 0.0001:
		return Vector2.ZERO
	return v.normalized()


static func _axis_run(d: Vector2) -> bool:
	return absf(d.x) <= 0.2 or absf(d.y) <= 0.2


static func _link_ok(a: Vector2, b: Vector2) -> bool:
	var al: float = a.length()
	var bl: float = b.length()
	if al < 0.001 or bl < 0.001:
		return false
	var cross: float = absf(a.x * b.y - a.y * b.x) / (al * bl)
	if cross <= 0.2:
		return true
	if al <= 6.0 and bl <= 6.0 and _axis_run(a) and _axis_run(b):
		return true
	return false


static func _lat(rel: Vector2, chord: Vector2) -> float:
	var cl: float = chord.length()
	if cl < 0.001:
		return rel.length()
	return absf(rel.x * chord.y - rel.y * chord.x) / cl


static func _can_fold(runs: Array[Dictionary], chain: Array[int], a: int, b: int) -> bool:
	if b <= a:
		return false
	var origin: Vector2 = runs[chain[a]]["origin"]
	var last: Dictionary = runs[chain[b]]
	var endp: Vector2 = (last["origin"] as Vector2) + (last["delta"] as Vector2)
	var chord: Vector2 = endp - origin
	var cl: float = chord.length()
	if cl < 0.5:
		return false
	var dev: float = 0.0
	for k in range(a, b + 1):
		var run: Dictionary = runs[chain[k]]
		var o: Vector2 = run["origin"]
		var far: Vector2 = o + (run["delta"] as Vector2)
		dev = maxf(dev, _lat(o - origin, chord))
		dev = maxf(dev, _lat(far - origin, chord))
	if dev > 1.25:
		return false
	var dir: Vector2 = chord / cl
	var teeth: bool = true
	var colinear: bool = true
	for k2 in range(a, b + 1):
		var step: Vector2 = runs[chain[k2]]["delta"]
		var sl: float = step.length()
		if sl > 6.0 or not _axis_run(step):
			teeth = false
		if sl > 0.001 and absf(step.x * dir.y - step.y * dir.x) / sl > 0.2:
			colinear = false
	if colinear:
		return true
	if not teeth:
		return false
	return absf(chord.x) > 0.75 and absf(chord.y) > 0.75


static func _chord(runs: Array[Dictionary], chain: Array[int], a: int, b: int) -> Dictionary:
	var first: Dictionary = runs[chain[a]]
	var last: Dictionary = runs[chain[b]]
	var origin: Vector2 = first["origin"]
	var endp: Vector2 = (last["origin"] as Vector2) + (last["delta"] as Vector2)
	var delta: Vector2 = endp - origin
	var nrm: Vector2 = Vector2(-delta.y, delta.x)
	if nrm.length_squared() > 0.0001:
		nrm = nrm.normalized()
	var acc: Vector2 = Vector2.ZERO
	for k in range(a, b + 1):
		acc += runs[chain[k]]["normal"] as Vector2
	if nrm.dot(acc) < 0.0:
		nrm = -nrm
	var made: Dictionary = {
		"origin": origin,
		"delta": delta,
		"normal": nrm,
		"thick": float(first.get("thick", 1.0)),
	}
	if first.has("cap_a"):
		made["cap_a"] = first["cap_a"] == true
	if last.has("cap_b"):
		made["cap_b"] = last["cap_b"] == true
	return made


static func _emit_chain(runs: Array[Dictionary], chain: Array[int], out: Array[Dictionary]) -> void:
	var count: int = chain.size()
	if count < 1:
		return
	var i: int = 0
	while i < count:
		var best: int = i
		var j: int = i + 1
		while j < count and _can_fold(runs, chain, i, j):
			best = j
			j += 1
		if best == i:
			out.append(runs[chain[i]])
		else:
			out.append(_chord(runs, chain, i, best))
		i = best + 1


static func _bevel_corners(runs: Array[Dictionary]) -> Array[Dictionary]:
	var n: int = runs.size()
	var starts: Dictionary = {}
	for i in n:
		var key: Vector2i = _pt_key(runs[i]["origin"] as Vector2)
		if not starts.has(key):
			starts[key] = []
		(starts[key] as Array).append(i)
	var extra: Array[Dictionary] = []
	for i in n:
		var run: Dictionary = runs[i]
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var len0: float = d.length()
		if len0 < 1.4:
			continue
		var endp: Vector2 = o + d
		var key2: Vector2i = _pt_key(endp)
		if not starts.has(key2):
			continue
		var dir_a: Vector2 = d / len0
		for cand in starts[key2]:
			var j: int = int(cand)
			if j == i:
				continue
			var other: Dictionary = runs[j]
			var d2: Vector2 = other["delta"] as Vector2
			var len1: float = d2.length()
			if len1 < 1.4:
				continue
			var dir_b: Vector2 = d2 / len1
			if absf(dir_a.dot(dir_b)) > 0.35:
				continue
			var cut: float = minf(2.4, minf(len0, len1) * 0.4)
			var pad: float = 0.55
			var new_end: Vector2 = endp - dir_a * cut
			var new_start: Vector2 = endp + dir_b * cut
			run["delta"] = new_end - o
			other["origin"] = new_start
			other["delta"] = (o + d + d2) - new_start
			new_end = new_end - dir_a * pad
			new_start = new_start + dir_b * pad
			var nd: Vector2 = (run["normal"] as Vector2) + (other["normal"] as Vector2)
			if nd.length_squared() < 0.0001:
				nd = Vector2(-dir_a.y, dir_a.x) + Vector2(-dir_b.y, dir_b.x)
			extra.append({
				"origin": new_end,
				"delta": new_start - new_end,
				"normal": nd.normalized(),
				"thick": float(run.get("thick", 1.0)),
				"cap_a": false,
				"cap_b": false,
			})
			break
	for item in extra:
		runs.append(item)
	return runs


static func _fold_teeth(runs: Array[Dictionary]) -> Array[Dictionary]:
	var n: int = runs.size()
	var nexts: PackedInt32Array = PackedInt32Array()
	nexts.resize(n)
	nexts.fill(-1)
	var starts: Dictionary = {}
	for i in n:
		var key: Vector2i = _pt_key(runs[i]["origin"] as Vector2)
		if not starts.has(key):
			starts[key] = []
		var bucket: Array = starts[key]
		bucket.append(i)
	for i in n:
		var run: Dictionary = runs[i]
		var endp: Vector2 = (run["origin"] as Vector2) + (run["delta"] as Vector2)
		var key2: Vector2i = _pt_key(endp)
		if not starts.has(key2):
			continue
		var nrm: Vector2 = _unit2(run["normal"] as Vector2)
		var cands: Array = starts[key2]
		var pick: int = -1
		for cand in cands:
			var j: int = int(cand)
			if j == i:
				continue
			var other: Dictionary = runs[j]
			if nrm.dot(_unit2(other["normal"] as Vector2)) < 0.5:
				continue
			if not _link_ok(run["delta"] as Vector2, other["delta"] as Vector2):
				continue
			if pick >= 0:
				pick = -2
				break
			pick = j
		if pick >= 0:
			nexts[i] = pick
	var indeg: PackedInt32Array = PackedInt32Array()
	indeg.resize(n)
	indeg.fill(0)
	for i in n:
		var nx: int = nexts[i]
		if nx >= 0:
			indeg[nx] = indeg[nx] + 1
	for i in n:
		var nx2: int = nexts[i]
		if nx2 >= 0 and indeg[nx2] != 1:
			nexts[i] = -1
	var pointed: PackedByteArray = PackedByteArray()
	pointed.resize(n)
	for i in n:
		var nx3: int = nexts[i]
		if nx3 >= 0:
			pointed[nx3] = 1
	var used: PackedByteArray = PackedByteArray()
	used.resize(n)
	var out: Array[Dictionary] = []
	for wave in 2:
		for i in n:
			if used[i] != 0:
				continue
			if wave == 0 and pointed[i] != 0:
				continue
			var chain: Array[int] = []
			var cur: int = i
			var guard: int = 0
			while cur >= 0 and used[cur] == 0 and guard <= n:
				used[cur] = 1
				chain.append(cur)
				cur = nexts[cur]
				guard += 1
			_emit_chain(runs, chain, out)
	return out


static func _merge_opposite(runs: Array[Dictionary]) -> Array[Dictionary]:
	var n: int = runs.size()
	var drop: PackedByteArray = PackedByteArray()
	drop.resize(n)
	for i in n:
		if drop[i] != 0:
			continue
		var a: Dictionary = runs[i]
		var ao: Vector2 = a["origin"]
		var ad: Vector2 = a["delta"]
		var al: float = ad.length()
		if al < 0.2:
			continue
		var at: Vector2 = ad / al
		var an: Vector2 = _unit2(a["normal"] as Vector2)
		for j in range(i + 1, n):
			if drop[j] != 0:
				continue
			var b: Dictionary = runs[j]
			var bn: Vector2 = _unit2(b["normal"] as Vector2)
			if an.dot(bn) > -0.85:
				continue
			var bo: Vector2 = b["origin"]
			var bd: Vector2 = b["delta"]
			var bl: float = bd.length()
			if bl < 0.2:
				continue
			var b0: float = (bo - ao).dot(at)
			var b1: float = (bo + bd - ao).dot(at)
			var lo: float = b0 if b0 < b1 else b1
			var hi: float = b1 if b1 > b0 else b0
			var overlap: float = minf(al, hi) - maxf(0.0, lo)
			var shorter: float = al if al < bl else bl
			if overlap < shorter * 0.6:
				continue
			var rel: Vector2 = (bo + bd * 0.5) - ao
			var lateral: Vector2 = rel - at * rel.dot(at)
			if lateral.length() > 1.35:
				continue
			if bl > al:
				drop[i] = 1
				break
			drop[j] = 1
	var kept: Array[Dictionary] = []
	for i in n:
		if drop[i] == 0:
			kept.append(runs[i])
	return kept
