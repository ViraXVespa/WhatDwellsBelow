extends Object

## A solid cell with a void or out-of-bounds 4-neighbor fails when no span that survives the wall prepare lies on that edge.

const WallMesh: GDScript = preload("res://scripts/graphics/wall_mesh.gd")

static func rim_report(data: Dictionary) -> Dictionary:
	var empty: Dictionary = {"holes": 0, "cells": [], "sample": "-"}
	var spans: Array = data.get("outline_spans", []) as Array
	var raw_solid: Variant = data.get("solid", PackedByteArray())
	if not (raw_solid is PackedByteArray):
		return empty
	var solid: PackedByteArray = raw_solid
	var sw: int = int(data.get("solid_w", 0))
	var sh: int = int(data.get("solid_h", 0))
	var per: int = int(data.get("solid_n", 0))
	if per < 1 or sw < 2 or sh < 2 or solid.size() != sw * sh:
		return empty
	var marked: Dictionary = {}
	var drawn: Array = WallMesh.prepare(spans)
	for raw_span: Variant in drawn:
		if not (raw_span is Dictionary):
			continue
		var sp: Dictionary = raw_span
		var o: Vector2 = Vector2(sp.get("origin", Vector2.ZERO))
		var d: Vector2 = Vector2(sp.get("delta", Vector2.ZERO))
		var nrm: Vector2 = Vector2(sp.get("normal", Vector2.ZERO))
		_mark_span(marked, o, d, nrm)
	var hole_n: int = 0
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var sample: PackedStringArray = PackedStringArray()
	for y: int in sh:
		var row: int = y * sw
		for x: int in sw:
			if solid[row + x] == 0:
				continue
			var open_n: int = 0
			if _void_side(solid, sw, sh, x, y - 1) and not marked.has(Vector3i(0, y, x)):
				open_n += 1
				_note_hole(sample, seen, cells, data, x, y, per, "n", x, y - 1)
			if _void_side(solid, sw, sh, x, y + 1) and not marked.has(Vector3i(0, y + 1, x)):
				open_n += 1
				_note_hole(sample, seen, cells, data, x, y, per, "s", x, y + 1)
			if _void_side(solid, sw, sh, x - 1, y) and not marked.has(Vector3i(1, x, y)):
				open_n += 1
				_note_hole(sample, seen, cells, data, x, y, per, "w", x - 1, y)
			if _void_side(solid, sw, sh, x + 1, y) and not marked.has(Vector3i(1, x + 1, y)):
				open_n += 1
				_note_hole(sample, seen, cells, data, x, y, per, "e", x + 1, y)
			if open_n == 0:
				continue
			hole_n += open_n
	var shown: String = "-"
	if sample.size() > 0:
		shown = ",".join(sample)
	return {"holes": hole_n, "cells": cells, "sample": shown}

static func _note_hole(sample: PackedStringArray, seen: Dictionary, cells: Array[Vector2i], data: Dictionary, x: int, y: int, per: int, side: String, nx: int, ny: int) -> void:
	var cell: Vector2i = Vector2i(int(float(x) / float(per)), int(float(y) / float(per)))
	if not seen.has(cell):
		seen[cell] = true
		cells.append(cell)
	if sample.size() >= 8:
		return
	sample.append("%d,%d%s:%s" % [cell.x, cell.y, side, _side_kind(data, nx, ny, per)])

static func _side_kind(data: Dictionary, x: int, y: int, per: int) -> String:
	var grid_v: Variant = data.get("grid", null)
	if not (grid_v is PackedByteArray):
		return "na"
	var grid: PackedByteArray = grid_v
	var gw: int = int(data.get("w", 0))
	var gh: int = int(data.get("h", 0))
	if gw < 1 or gh < 1 or grid.size() != gw * gh:
		return "na"
	var gx: int = int(float(x) / float(per))
	var gy: int = int(float(y) / float(per))
	if gx < 0 or gy < 0 or gx >= gw or gy >= gh:
		return "oob"
	if grid[gy * gw + gx] == 1:
		return "floor"
	return "void"

static func _void_side(solid: PackedByteArray, sw: int, sh: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= sw or y >= sh:
		return true
	return solid[y * sw + x] == 0

static func _mark_span(marked: Dictionary, o: Vector2, d: Vector2, nrm: Vector2) -> void:
	var slen: float = d.length()
	if slen < 0.5:
		return
	if nrm.length_squared() > 0.0001:
		nrm = nrm.normalized()
	if absf(d.y) <= 0.2 and absf(d.x) >= 0.5 and absf(o.y - float(roundi(o.y))) <= 0.35:
		_mark_horiz(marked, roundi(o.y), o.x, o.x + d.x)
		return
	if absf(d.x) <= 0.2 and absf(d.y) >= 0.5 and absf(o.x - float(roundi(o.x))) <= 0.35:
		_mark_vert(marked, roundi(o.x), o.y, o.y + d.y)
		return
	var steps: int = maxi(1, int(ceil(slen * 2.0)))
	var si: int = 0
	while si <= steps:
		var p: Vector2 = o + d * (float(si) / float(steps))
		_mark_near(marked, p, nrm)
		si += 1

static func _mark_horiz(marked: Dictionary, y_edge: int, x0: float, x1: float) -> void:
	var lo: float = minf(x0, x1)
	var hi: float = maxf(x0, x1)
	var x: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while x < last:
		if float(x + 1) > lo + 0.001 and float(x) < hi - 0.001:
			marked[Vector3i(0, y_edge, x)] = true
		x += 1

static func _mark_vert(marked: Dictionary, x_edge: int, y0: float, y1: float) -> void:
	var lo: float = minf(y0, y1)
	var hi: float = maxf(y0, y1)
	var y: int = int(floor(lo))
	var last: int = int(ceil(hi))
	while y < last:
		if float(y + 1) > lo + 0.001 and float(y) < hi - 0.001:
			marked[Vector3i(1, x_edge, y)] = true
		y += 1

static func _mark_near(marked: Dictionary, p: Vector2, nrm: Vector2) -> void:
	var y_edge: int = roundi(p.y)
	var xi: int = int(floor(p.x)) - 1
	var x_last: int = int(floor(p.x)) + 1
	while xi <= x_last:
		var mid: Vector2 = Vector2(float(xi) + 0.5, float(y_edge))
		if mid.distance_squared_to(p) <= 0.2025 and absf(nrm.y) > 0.2:
			marked[Vector3i(0, y_edge, xi)] = true
		xi += 1
	var x_edge: int = roundi(p.x)
	var yi: int = int(floor(p.y)) - 1
	var y_last: int = int(floor(p.y)) + 1
	while yi <= y_last:
		var mid_v: Vector2 = Vector2(float(x_edge), float(yi) + 0.5)
		if mid_v.distance_squared_to(p) <= 0.2025 and absf(nrm.x) > 0.2:
			marked[Vector3i(1, x_edge, yi)] = true
		yi += 1

static func mark_holes(overlays: Dictionary, data: Dictionary) -> int:
	var rim: Dictionary = rim_report(data)
	var cells: Array = rim.get("cells", []) as Array
	for raw: Variant in cells:
		if raw is Vector2i and not overlays.has(raw):
			overlays[raw] = "rim_hole"
	return int(rim.get("holes", 0))
