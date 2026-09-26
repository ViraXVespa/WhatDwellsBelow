extends Object

## Greedy wall-cell merge into tile rects (x, y, w, h) for collision boxes.


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
