extends Object

## Split from outline.gd: _seal_gaps publishes solid/void edges no span covers (edge keys: edge_mark.gd).

const Edge := preload("res://scripts/dungeon/gen/edge_mark.gd")

static func _seal_open(solid: PackedByteArray, sw: int, sh: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= sw or y >= sh:
		return true
	return solid[y * sw + x] == 0

static func _seal_mark_spans(marked: Dictionary, spans: Array) -> void:
	for part: Array in Edge.parts(spans):
		var d: Vector2 = part[1]
		if d.length() >= 0.5:
			Edge.mark_axis(marked, part[0], d)

# Solid/void edges the rect pass skipped. Not added to floor loops.
static func _seal_gaps(solid: PackedByteArray, sw: int, sh: int, spans: Array) -> void:
	var marked: Dictionary = {}
	_seal_mark_spans(marked, spans)
	var y: int = 0
	while y < sh:
		var row: int = y * sw
		var x: int = 0
		while x < sw:
			if solid[row + x] != 0 and _seal_open(solid, sw, sh, x, y - 1) and not marked.has(Vector3i(0, y, x)):
				var x_hi: int = x + 1
				while x_hi < sw and solid[row + x_hi] != 0 and _seal_open(solid, sw, sh, x_hi, y - 1) and not marked.has(Vector3i(0, y, x_hi)):
					x_hi += 1
				_emit_frag_run(spans, Vector2(float(x), float(y)), Vector2(1.0, 0.0), 0.0, float(x_hi - x), Vector2(0.0, 1.0))
				x = x_hi
			else:
				x += 1
		y += 1
	y = 0
	while y < sh:
		var row_s: int = y * sw
		var x_s: int = 0
		while x_s < sw:
			if solid[row_s + x_s] != 0 and _seal_open(solid, sw, sh, x_s, y + 1) and not marked.has(Vector3i(0, y + 1, x_s)):
				var x_s_hi: int = x_s + 1
				while x_s_hi < sw and solid[row_s + x_s_hi] != 0 and _seal_open(solid, sw, sh, x_s_hi, y + 1) and not marked.has(Vector3i(0, y + 1, x_s_hi)):
					x_s_hi += 1
				_emit_frag_run(spans, Vector2(float(x_s_hi), float(y + 1)), Vector2(-1.0, 0.0), 0.0, float(x_s_hi - x_s), Vector2(0.0, -1.0))
				x_s = x_s_hi
			else:
				x_s += 1
		y += 1
	var x_w: int = 0
	while x_w < sw:
		var y_w: int = 0
		while y_w < sh:
			if solid[y_w * sw + x_w] != 0 and _seal_open(solid, sw, sh, x_w - 1, y_w) and not marked.has(Vector3i(1, x_w, y_w)):
				var y_w_hi: int = y_w + 1
				while y_w_hi < sh and solid[y_w_hi * sw + x_w] != 0 and _seal_open(solid, sw, sh, x_w - 1, y_w_hi) and not marked.has(Vector3i(1, x_w, y_w_hi)):
					y_w_hi += 1
				_emit_frag_run(spans, Vector2(float(x_w), float(y_w_hi)), Vector2(0.0, -1.0), 0.0, float(y_w_hi - y_w), Vector2(1.0, 0.0))
				y_w = y_w_hi
			else:
				y_w += 1
		x_w += 1
	var x_e: int = 0
	while x_e < sw:
		var y_e: int = 0
		while y_e < sh:
			if solid[y_e * sw + x_e] != 0 and _seal_open(solid, sw, sh, x_e + 1, y_e) and not marked.has(Vector3i(1, x_e + 1, y_e)):
				var y_e_hi: int = y_e + 1
				while y_e_hi < sh and solid[y_e_hi * sw + x_e] != 0 and _seal_open(solid, sw, sh, x_e + 1, y_e_hi) and not marked.has(Vector3i(1, x_e + 1, y_e_hi)):
					y_e_hi += 1
				_emit_frag_run(spans, Vector2(float(x_e + 1), float(y_e)), Vector2(0.0, 1.0), 0.0, float(y_e_hi - y_e), Vector2(-1.0, 0.0))
				y_e = y_e_hi
			else:
				y_e += 1
		x_e += 1

static func _emit_frag_run(spans: Array, a: Vector2, dir: Vector2, t0: float, t1: float, nrm: Vector2) -> void:
	if t1 - t0 < 0.04:
		return
	spans.append({"origin": a + dir * t0, "delta": dir * (t1 - t0), "normal": nrm, "thick": 0.25})
