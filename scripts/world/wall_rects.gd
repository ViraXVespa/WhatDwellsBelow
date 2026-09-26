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
