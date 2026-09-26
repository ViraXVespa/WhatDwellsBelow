extends Object

## Greedy wall-cell merge into tile rects (x, y, w, h) for collision boxes.

const Gen := preload("res://scripts/dungeon/gen.gd")


static func merge(walls: Array[Vector2i]) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if walls.is_empty():
		return rects
	var used: Dictionary = {}
	for c in walls:
		used[c] = false
	for c in walls:
		if used[c]:
			continue
		var x: int = c.x
		var y: int = c.y
		var xa: int = x
		while used.has(Vector2i(xa + 1, y)) and not used[Vector2i(xa + 1, y)]:
			xa += 1
		var ya: int = y
		var row_ok := true
		while row_ok:
			for xx in range(x, xa + 1):
				var below := Vector2i(xx, ya + 1)
				if not used.has(below) or used[below]:
					row_ok = false
					break
			if row_ok:
				ya += 1
		for yy in range(y, ya + 1):
			for xx in range(x, xa + 1):
				used[Vector2i(xx, yy)] = true
		rects.append(Rect2i(x, y, xa - x + 1, ya - y + 1))
	return rects


## Greedy-merged wall faces toward FLOOR: { "origin", "size", "normal" } in tile cells.
static func faces(grid: PackedByteArray, w: int, h: int, cells: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cells.is_empty():
		return out
	var normals: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var used: Dictionary = {}
	for c in cells:
		for i in range(normals.size()):
			var nx: int = c.x + normals[i].x
			var ny: int = c.y + normals[i].y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
				used[Vector3i(c.x, c.y, i)] = false
	for c in cells:
		for i in range(normals.size()):
			var key := Vector3i(c.x, c.y, i)
			if not used.has(key) or used[key]:
				continue
			var n: Vector2i = normals[i]
			var t := Vector2i(absi(n.y), absi(n.x))
			var span: int = 1
			while used.has(Vector3i(c.x + t.x * span, c.y + t.y * span, i)) and not used[Vector3i(c.x + t.x * span, c.y + t.y * span, i)]:
				span += 1
			for k in range(span):
				used[Vector3i(c.x + t.x * k, c.y + t.y * k, i)] = true
			out.append({"origin": c, "size": Vector2i(1 + t.x * (span - 1), 1 + t.y * (span - 1)), "normal": n})
	return out


## Fine-mask floor cells inside one coarse chunk. 1 = walkable.
static func solid_cells(solid: PackedByteArray, sw: int, sh: int, n: int, ox: int, oy: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var fx0: int = ox * n
	var fy0: int = oy * n
	var fx1: int = sw if sw < x1 * n else x1 * n
	var fy1: int = sh if sh < y1 * n else y1 * n
	var fx_from: int = 0 if fx0 < 0 else fx0
	var fy_from: int = 0 if fy0 < 0 else fy0
	for fy in range(fy_from, fy1):
		var row: int = fy * sw
		for fx in range(fx_from, fx1):
			if solid[row + fx] != 0:
				out.append(Vector2i(fx, fy))
	return out


## Void rim and the coarse wall mass that touches this chunk's floor.
## Faces and merge consume the returned cells. Collision includes the rim.
static func volume_cells(solid: PackedByteArray, sw: int, sh: int, n: int, grid: PackedByteArray, gw: int, gh: int, ox: int, oy: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var fx_lo: int = ox * n - n
	var fy_lo: int = oy * n - n
	var fx0: int = 0 if fx_lo < 0 else fx_lo
	var fy0: int = 0 if fy_lo < 0 else fy_lo
	var fx_hi: int = x1 * n + n
	var fy_hi: int = y1 * n + n
	var fx1: int = sw if sw < fx_hi else fx_hi
	var fy1: int = sh if sh < fy_hi else fy_hi
	for fy in range(fy0, fy1):
		var row: int = fy * sw
		var cy: int = int(float(fy) / float(n))
		for fx in range(fx0, fx1):
			if solid[row + fx] != 0:
				continue
			var cx: int = int(float(fx) / float(n))
			if not _blocks(solid, sw, sh, grid, gw, gh, fx, fy, cx, cy):
				continue
			if not _owned(solid, sw, sh, n, grid, gw, gh, fx, fy, cx, cy, ox, oy, x1, y1):
				continue
			out.append(Vector2i(fx, fy))
	return out


static func _blocks(solid: PackedByteArray, sw: int, sh: int, grid: PackedByteArray, gw: int, gh: int, fx: int, fy: int, cx: int, cy: int) -> bool:
	if _touches_solid(solid, sw, sh, fx, fy):
		return true
	return _coarse_wall(grid, gw, gh, cx, cy)


static func _touches_solid(solid: PackedByteArray, sw: int, sh: int, fx: int, fy: int) -> bool:
	if fx > 0 and solid[fy * sw + fx - 1] != 0:
		return true
	if fx + 1 < sw and solid[fy * sw + fx + 1] != 0:
		return true
	if fy > 0 and solid[(fy - 1) * sw + fx] != 0:
		return true
	if fy + 1 < sh and solid[(fy + 1) * sw + fx] != 0:
		return true
	return false


static func _coarse_wall(grid: PackedByteArray, gw: int, gh: int, cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
		return false
	if grid[Gen.idx(cx, cy, gw)] == Gen.FLOOR:
		return false
	return _floor_near(grid, gw, gh, cx, cy)


static func _floor_near(grid: PackedByteArray, gw: int, gh: int, cx: int, cy: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
			continue
		if grid[Gen.idx(nx, ny, gw)] == Gen.FLOOR:
			return true
	return false


static func _owned(solid: PackedByteArray, sw: int, sh: int, n: int, grid: PackedByteArray, gw: int, gh: int, fx: int, fy: int, cx: int, cy: int, ox: int, oy: int, x1: int, y1: int) -> bool:
	if _solid_neighbor_in_chunk(solid, sw, sh, n, fx, fy, ox, oy, x1, y1):
		return true
	if not _coarse_wall(grid, gw, gh, cx, cy):
		return false
	return _floor_neighbor_in_chunk(grid, gw, gh, cx, cy, ox, oy, x1, y1)


static func _solid_neighbor_in_chunk(solid: PackedByteArray, sw: int, sh: int, n: int, fx: int, fy: int, ox: int, oy: int, x1: int, y1: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = fx + d.x
		var ny: int = fy + d.y
		if nx < 0 or ny < 0 or nx >= sw or ny >= sh:
			continue
		if solid[ny * sw + nx] == 0:
			continue
		var ccx: int = int(float(nx) / float(n))
		var ccy: int = int(float(ny) / float(n))
		if ccx >= ox and ccy >= oy and ccx < x1 and ccy < y1:
			return true
	return false


static func _floor_neighbor_in_chunk(grid: PackedByteArray, gw: int, gh: int, cx: int, cy: int, ox: int, oy: int, x1: int, y1: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = cx + d.x
		var ny: int = cy + d.y
		if nx < ox or ny < oy or nx >= x1 or ny >= y1 or nx < 0 or ny < 0 or nx >= gw or ny >= gh:
			continue
		if grid[Gen.idx(nx, ny, gw)] == Gen.FLOOR:
			return true
	return false
