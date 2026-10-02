extends Object

## Split from dungeon_map_spec.gd: rim_report, mark_holes.

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
	var cover: PackedByteArray = PackedByteArray()
	cover.resize(sw * sh)
	cover.fill(0)
	for raw_span: Variant in spans:
		if not (raw_span is Dictionary):
			continue
		var sp: Dictionary = raw_span
		var o: Vector2 = Vector2(sp.get("origin", Vector2.ZERO))
		var d: Vector2 = Vector2(sp.get("delta", Vector2.ZERO))
		var slen: float = d.length()
		if slen < 0.5:
			continue
		var steps: int = maxi(1, int(ceil(slen * 2.0)))
		for si: int in range(steps + 1):
			var t: float = float(si) / float(steps)
			var p: Vector2 = o + d * t
			var cx: int = int(floor(p.x))
			var cy: int = int(floor(p.y))
			for oy: int in range(cy - 2, cy + 3):
				if oy < 0 or oy >= sh:
					continue
				for ox: int in range(cx - 2, cx + 3):
					if ox < 0 or ox >= sw:
						continue
					cover[oy * sw + ox] = 1
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var hole_n: int = 0
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var sample: PackedStringArray = PackedStringArray()
	for y: int in sh:
		var row: int = y * sw
		for x: int in sw:
			if solid[row + x] == 0:
				continue
			var edge: bool = false
			for d2: Vector2i in dirs:
				var nx: int = x + d2.x
				var ny: int = y + d2.y
				if nx < 0 or ny < 0 or nx >= sw or ny >= sh or solid[ny * sw + nx] == 0:
					edge = true
					break
			if not edge:
				continue
			if cover[row + x] != 0:
				continue
			hole_n += 1
			var cell: Vector2i = Vector2i(int(float(x) / float(per)), int(float(y) / float(per)))
			if not seen.has(cell):
				seen[cell] = true
				cells.append(cell)
				if sample.size() < 8:
					sample.append("%d,%d" % [cell.x, cell.y])
	var shown: String = "-"
	if sample.size() > 0:
		shown = ",".join(sample)
	return {"holes": hole_n, "cells": cells, "sample": shown}

static func mark_holes(overlays: Dictionary, data: Dictionary) -> int:
	var rim: Dictionary = rim_report(data)
	var cells: Array = rim.get("cells", []) as Array
	for raw: Variant in cells:
		if raw is Vector2i and not overlays.has(raw):
			overlays[raw] = "rim_hole"
	return int(rim.get("holes", 0))
