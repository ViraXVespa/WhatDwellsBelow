extends Object

## Dungeon stream wall runs, outline spans, and span/face clipping to a chunk.

const WallRects := preload("res://scripts/world/wall_rects.gd")
const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh/wall_mesh.gd")

static func _wall_runs(host: Node, solid: PackedByteArray, sw: int, sh: int, wall_cells: Array[Vector2i], ox: int, oy: int, x1: int, y1: int, n: int) -> Array[Dictionary]:
	var raw: Array = _outline_spans(host)
	if raw.is_empty():
		return _faces_on_chunk(solid, sw, sh, wall_cells, ox * n, oy * n, x1 * n, y1 * n)
	var fx0: int = ox * n
	var fy0: int = oy * n
	var fx1: int = x1 * n
	var fy1: int = y1 * n
	var hit: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		if _clip_span(o, d, float(fx0) - 2.0, float(fy0) - 2.0, float(fx1) + 2.0, float(fy1) + 2.0).is_empty():
			continue
		hit.append(run)
	return _spans_on_chunk(WallMesh.prepare(hit), fx0, fy0, fx1, fy1)

static func _outline_spans(host: Node) -> Array:
	if host.data == null or not host.data.has("outline_spans"):
		return []
	var raw: Variant = host.data["outline_spans"]
	if raw is Array:
		return raw
	return []

static func _outline_loops(host: Node) -> Array:
	if host.data == null or not host.data.has("outline_loops"):
		return []
	var raw: Variant = host.data["outline_loops"]
	if raw is Array:
		return raw
	return []

static func _spans_on_chunk(spans: Array, fx0: int, fy0: int, fx1: int, fy1: int) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	var pad := 2.0
	var ix0: float = float(fx0) - pad
	var iy0: float = float(fy0) - pad
	var ix1: float = float(fx1) + pad
	var iy1: float = float(fy1) + pad
	var x0: float = float(fx0) - 1.0
	var y0: float = float(fy0) - 1.0
	var x1: float = float(fx1) + 1.0
	var y1: float = float(fy1) + 1.0
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		if _clip_span(o, d, ix0, iy0, ix1, iy1).is_empty():
			continue
		var piece: Dictionary = _clip_span(o, d, x0, y0, x1, y1)
		if piece.is_empty():
			continue
		var t0: float = float(piece["t0"])
		var t1: float = float(piece["t1"])
		kept.append({
			"origin": piece["origin"],
			"delta": piece["delta"],
			"normal": run["normal"],
			"thick": float(run.get("thick", 1.0)),
			"cap_a": t0 <= 0.001,
			"cap_b": t1 >= 0.999,
		})
	return kept

static func _clip_span(o: Vector2, d: Vector2, x0: float, y0: float, x1: float, y1: float) -> Dictionary:
	var ts: Array = [0.0, 1.0]
	if not _clip_axis(o.x, d.x, x0, x1, ts):
		return {}
	if not _clip_axis(o.y, d.y, y0, y1, ts):
		return {}
	var t0: float = float(ts[0])
	var t1: float = float(ts[1])
	if t1 - t0 < 0.0001:
		return {}
	return {
		"origin": o + d * t0,
		"delta": d * (t1 - t0),
		"t0": t0,
		"t1": t1,
	}

static func _clip_axis(p: float, dp: float, min_v: float, max_v: float, ts: Array) -> bool:
	var t0: float = float(ts[0])
	var t1: float = float(ts[1])
	if absf(dp) < 0.0000001:
		if p < min_v or p >= max_v:
			return false
		return true
	var a: float = (min_v - p) / dp
	var b: float = (max_v - p) / dp
	if a > b:
		var swap: float = a
		a = b
		b = swap
	if a > t0:
		t0 = a
	if b < t1:
		t1 = b
	if t0 > t1:
		return false
	ts[0] = t0
	ts[1] = t1
	return true

static func _faces_on_chunk(
	grid: PackedByteArray,
	w: int,
	h: int,
	wall_cells: Array[Vector2i],
	ox: int,
	oy: int,
	x1: int,
	y1: int
) -> Array[Dictionary]:
	var runs: Array[Dictionary] = WallRects.faces(grid, w, h, wall_cells)
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if _run_looks_in(run, ox, oy, x1, y1):
			kept.append(run)
	return kept

static func _run_looks_in(run: Dictionary, ox: int, oy: int, x1: int, y1: int) -> bool:
	var origin: Vector2i = run["origin"] as Vector2i
	var span_cells: Vector2i = run["size"] as Vector2i
	var n2: Vector2i = run["normal"] as Vector2i
	var along: Vector2i = Vector2i(1, 0) if span_cells.x >= span_cells.y else Vector2i(0, 1)
	var length: int = maxi(span_cells.x, span_cells.y)
	for k in length:
		var wall: Vector2i = origin + Vector2i(along.x * k, along.y * k)
		var floor_cell: Vector2i = wall + n2
		if floor_cell.x >= ox and floor_cell.y >= oy and floor_cell.x < x1 and floor_cell.y < y1:
			return true
	return false
