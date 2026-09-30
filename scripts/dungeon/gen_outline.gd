extends Object

const LoadTiming := preload("res://scripts/debug/load_timing.gd")

const FLOOR := 1


static func _on_rim(grid: PackedByteArray, gw: int, gh: int, per: int, mid: Vector2, nrm: Vector2) -> bool:
	var inn: Vector2 = mid + nrm * 0.6
	var outp: Vector2 = mid - nrm * 0.6
	var ix: int = int(floor(inn.x / float(per)))
	var iy: int = int(floor(inn.y / float(per)))
	var ox: int = int(floor(outp.x / float(per)))
	var oy: int = int(floor(outp.y / float(per)))
	if ix < 0 or iy < 0 or ix >= gw or iy >= gh:
		return false
	if grid[iy * gw + ix] != FLOOR:
		return false
	if ox < 0 or oy < 0 or ox >= gw or oy >= gh:
		return true
	return grid[oy * gw + ox] != FLOOR


static func _emit_frag_run(spans: Array, a: Vector2, dir: Vector2, t0: float, t1: float, nrm: Vector2) -> void:
	if t1 - t0 < 0.04:
		return
	spans.append({"origin": a + dir * t0, "delta": dir * (t1 - t0), "normal": nrm, "thick": 1.0})


static func _emit_edge(spans: Array, grid: PackedByteArray, gw: int, gh: int, per: int, a: Vector2, b: Vector2, nrm: Vector2) -> void:
	var d: Vector2 = b - a
	var span_l: float = d.length()
	if span_l < 0.04:
		return
	var dir: Vector2 = d / span_l
	var step: float = float(maxi(1, per))
	var t: float = 0.0
	var run0: float = -1.0
	while t < span_l - 0.001:
		var t1: float = minf(span_l, t + step)
		var mid: Vector2 = a + dir * ((t + t1) * 0.5)
		if _on_rim(grid, gw, gh, per, mid, nrm):
			if run0 < 0.0:
				run0 = t
		elif run0 >= 0.0:
			_emit_frag_run(spans, a, dir, run0, t, nrm)
			run0 = -1.0
		t = t1
	if run0 >= 0.0:
		_emit_frag_run(spans, a, dir, run0, span_l, nrm)


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(Vector2(x0, y0))
	poly.append(Vector2(x1, y0))
	poly.append(Vector2(x1, y1))
	poly.append(Vector2(x0, y1))
	return poly


static func _fill_axis_rect(solid: PackedByteArray, sw: int, sh: int, poly: PackedVector2Array, value: int) -> bool:
	if poly.size() != 4:
		return false
	var minx: float = minf(minf(poly[0].x, poly[1].x), minf(poly[2].x, poly[3].x))
	var maxx: float = maxf(maxf(poly[0].x, poly[1].x), maxf(poly[2].x, poly[3].x))
	var miny: float = minf(minf(poly[0].y, poly[1].y), minf(poly[2].y, poly[3].y))
	var maxy: float = maxf(maxf(poly[0].y, poly[1].y), maxf(poly[2].y, poly[3].y))
	var y0: int = maxi(0, int(ceil(miny - 0.5)))
	var y1: int = mini(sh - 1, int(ceil(maxy - 0.5)) - 1)
	var x0: int = maxi(0, int(ceil(minx - 0.5)))
	var x1: int = mini(sw - 1, int(floor(maxx - 0.5)))
	if y1 < y0 or x1 < x0:
		return true
	var y: int = y0
	while y <= y1:
		var row: int = y * sw
		var x: int = x0
		while x <= x1:
			solid[row + x] = value
			x += 1
		y += 1
	return true


static func _stamp_rect(solid: PackedByteArray, sw: int, sh: int, spans: Array, grid: PackedByteArray, gw: int, gh: int, per: int, x0: float, y0: float, x1: float, y1: float) -> void:
	if x1 <= x0 or y1 <= y0:
		return
	_fill_axis_rect(solid, sw, sh, _rect(x0, y0, x1, y1), 1)
	_emit_edge(spans, grid, gw, gh, per, Vector2(x0, y0), Vector2(x1, y0), Vector2(0.0, 1.0))
	_emit_edge(spans, grid, gw, gh, per, Vector2(x1, y0), Vector2(x1, y1), Vector2(-1.0, 0.0))
	_emit_edge(spans, grid, gw, gh, per, Vector2(x1, y1), Vector2(x0, y1), Vector2(0.0, -1.0))
	_emit_edge(spans, grid, gw, gh, per, Vector2(x0, y1), Vector2(x0, y0), Vector2(1.0, 0.0))


static func _fine_m(bal: Object) -> float:
	var m: float = 1.0
	if bal != null:
		m = float(bal.get("outline_fine_m"))
	if m >= 0.87:
		return 1.0
	return 1.0


static func _per_m(fine_m: float) -> int:
	return clampi(int(round(1.0 / maxf(fine_m, 0.25))), 1, 4)


static func stamp(data: Dictionary, rng: RandomNumberGenerator, bal: Object) -> void:
	var fine_m: float = _fine_m(bal)
	var per: int = _per_m(fine_m)
	var grid: PackedByteArray = data["grid"]
	var w: int = int(data["w"])
	var h: int = int(data["h"])
	var rooms: Array = data["rooms"]
	var halls: Array = []
	var raw_halls: Variant = data.get("halls", [])
	if raw_halls is Array:
		halls = raw_halls
	LoadTiming.dmark("gen_outline_up")
	LoadTiming.dmark("gen_outline_jag")
	var sw: int = w * per
	var sh: int = h * per
	var solid: PackedByteArray = PackedByteArray()
	solid.resize(sw * sh)
	solid.fill(0)
	var spans: Array = []
	var scale: float = float(per)
	var loops: Array = []
	for room_v in rooms:
		var room: Dictionary = room_v
		var x0: float = float(int(room["x"])) * scale
		var y0: float = float(int(room["y"])) * scale
		var x1: float = float(int(room["x"]) + int(room["w"])) * scale
		var y1: float = float(int(room["y"]) + int(room["h"])) * scale
		_stamp_rect(solid, sw, sh, spans, grid, w, h, per, x0, y0, x1, y1)
		loops.append(_rect(x0, y0, x1, y1))
	for hall_v in halls:
		var hall: Dictionary = hall_v
		if str(hall.get("k", "")) == "band":
			continue
		var hx0: float = float(int(hall["x0"])) * scale
		var hy0: float = float(int(hall["y0"])) * scale
		var hx1: float = float(int(hall["x1"]) + 1) * scale
		var hy1: float = float(int(hall["y1"]) + 1) * scale
		_stamp_rect(solid, sw, sh, spans, grid, w, h, per, hx0, hy0, hx1, hy1)
		loops.append(_rect(hx0, hy0, hx1, hy1))
	LoadTiming.dnote("outline_loops", str(loops.size()))
	LoadTiming.dnote("outline_spans_n", str(spans.size()))
	data["outline_fine_m"] = fine_m
	data["solid"] = solid
	data["solid_w"] = sw
	data["solid_h"] = sh
	data["solid_n"] = per
	data["outline_spans"] = spans
	data["outline_loops"] = loops
	LoadTiming.dmark("gen_outline_spans")
