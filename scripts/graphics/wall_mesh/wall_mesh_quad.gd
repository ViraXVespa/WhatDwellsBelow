extends Object

## Wall mesh quad emit and corner math. Owns the UV2 buffer.

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
static func _uv4(uvs: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	var base: int = uvs.size() - 4
	uvs[base] = a
	uvs[base + 1] = b
	uvs[base + 2] = c
	uvs[base + 3] = d
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
static func _ni(n2: Vector2i) -> int:
	if n2.x > 0:
		return 0
	if n2.x < 0:
		return 1
	if n2.y > 0:
		return 2
	return 3
