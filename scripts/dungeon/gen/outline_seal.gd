extends Object

## Split from outline.gd: _seal_open, _seal_mark_horiz, _seal_mark_vert....

static func _seal_open(solid: PackedByteArray, sw: int, sh: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= sw or y >= sh:
		return true
	return solid[y * sw + x] == 0

static func _seal_mark_horiz(marked: Dictionary, y_edge: int, x0: float, x1: float) -> void:
	var lo: float = minf(x0, x1)
	var hi: float = maxf(x0, x1)
	var x: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while x < last:
		if float(x + 1) > lo + 0.001 and float(x) < hi - 0.001:
			marked[Vector3i(0, y_edge, x)] = true
		x += 1

static func _seal_mark_vert(marked: Dictionary, x_edge: int, y0: float, y1: float) -> void:
	var lo: float = minf(y0, y1)
	var hi: float = maxf(y0, y1)
	var y: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while y < last:
		if float(y + 1) > lo + 0.001 and float(y) < hi - 0.001:
			marked[Vector3i(1, x_edge, y)] = true
		y += 1

static func _seal_mark_spans(marked: Dictionary, spans: Array) -> void:
	for raw_span: Variant in spans:
		if not (raw_span is Dictionary):
			continue
		var sp: Dictionary = raw_span
		var o: Vector2 = Vector2(sp.get("origin", Vector2.ZERO))
		var d: Vector2 = Vector2(sp.get("delta", Vector2.ZERO))
		if d.length() < 0.5:
			continue
		if absf(d.y) <= 0.2 and absf(d.x) >= 0.5 and absf(o.y - float(roundi(o.y))) <= 0.35:
			_seal_mark_horiz(marked, roundi(o.y), o.x, o.x + d.x)
		elif absf(d.x) <= 0.2 and absf(d.y) >= 0.5 and absf(o.x - float(roundi(o.x))) <= 0.35:
			_seal_mark_vert(marked, roundi(o.x), o.y, o.y + d.y)

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
