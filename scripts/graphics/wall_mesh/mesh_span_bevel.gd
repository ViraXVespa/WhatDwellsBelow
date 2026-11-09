extends Object

## Split from mesh_span.gd: _bevel_if_gap, _wedge_clear, _emit_bevel....

const Quad := preload("res://scripts/graphics/wall_mesh/mesh_quad.gd")

static func _bevel_if_gap(raw_a: Dictionary, raw_b: Dictionary, floor_angs: Array[float], h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> bool:
	var b0: Vector2 = raw_a["back"] as Vector2
	var b1: Vector2 = raw_b["back"] as Vector2
	if b0.distance_squared_to(b1) < 0.0004:
		return false
	var sweep: float = fposmod(float(raw_b["ang"]) - float(raw_a["ang"]), TAU)
	var start: float = float(raw_a["ang"])
	if sweep > PI:
		sweep = TAU - sweep
		start = float(raw_b["ang"])
	if sweep < 0.02 or sweep > PI:
		return false
	if not _wedge_clear(start, sweep, floor_angs):
		return false
	_emit_bevel(raw_a["p"] as Vector2, b0, b1, h, verts, norms, uvs, indices)
	return true

static func _wedge_clear(start: float, sweep: float, floor_angs: Array[float]) -> bool:
	var i: int = 0
	while i < floor_angs.size():
		var rel: float = fposmod(floor_angs[i] - start, TAU)
		if rel > 0.05 and rel < sweep - 0.05:
			return false
		i += 1
	return true

static func _emit_bevel(p: Vector2, b0: Vector2, b1: Vector2, h: float, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	if absf((b0 - p).cross(b1 - p)) < 0.0001:
		return
	var edge: Vector2 = b1 - b0
	var right: Vector2 = Vector2(edge.y, -edge.x)
	var out_dir: Vector2 = (b0 + b1) * 0.5 - p
	if right.dot(out_dir) < 0.0:
		var swap_b: Vector2 = b0
		b0 = b1
		b1 = swap_b
		edge = b1 - b0
		right = Vector2(edge.y, -edge.x)
	var face_n: Vector2 = right.normalized()
	if face_n.length_squared() < 0.0001:
		return
	var span_w: float = edge.length()
	Quad._uv2_in = face_n
	var side: PackedVector3Array = PackedVector3Array()
	side.append(Vector3(b0.x, 0.0, b0.y))
	side.append(Vector3(b1.x, 0.0, b1.y))
	side.append(Vector3(b1.x, h, b1.y))
	side.append(Vector3(b0.x, h, b0.y))
	Quad._quad(side, Vector3(face_n.x, 0.0, face_n.y), verts, norms, uvs, indices)
	Quad._uv4(uvs, Vector2(0.0, 0.0), Vector2(span_w, 0.0), Vector2(span_w, h), Vector2(0.0, h))
	var t0: Vector2 = b0
	var t1: Vector2 = b1
	if (t0 - p).cross(t1 - p) < 0.0:
		t0 = b1
		t1 = b0
	var top: PackedVector3Array = PackedVector3Array()
	top.append(Vector3(p.x, h, p.y))
	top.append(Vector3(t0.x, h, t0.y))
	top.append(Vector3(t1.x, h, t1.y))
	_tri(top, Vector3.UP, verts, norms, uvs, indices)
	_uv3(uvs, Vector2(0.0, 0.0), Vector2(span_w, 0.0), Vector2(0.0, span_w))

static func _tri(corners: PackedVector3Array, n: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var base: int = verts.size()
	var i: int = 0
	while i < corners.size():
		verts.append(corners[i])
		norms.append(n)
		uvs.append(Vector2.ZERO)
		Quad._uv2_buf.append(Quad._uv2_in)
		i += 1
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)

static func _uv3(uvs: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2) -> void:
	var base: int = uvs.size() - 3
	uvs[base] = a
	uvs[base + 1] = b
	uvs[base + 2] = c
