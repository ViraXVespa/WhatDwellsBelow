extends Object

## Extraction Gate wall slots. A gate hangs on a TOP (north, camera-facing) wall:
## 3 wall cells in a row with 3 walkable floor cells directly south of them.
## Side (east/west) walls and free-standing floor spots are never slots.
## Returns the middle wall cell, or (-1, -1).

const WALL := 0
const FLOOR := 1

static func _at(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return WALL
	return grid[y * w + x]

## True when wall cell (x, y) can hold a gate: walls x-1..x+1 on row y, floor below.
static func is_slot(grid: PackedByteArray, w: int, h: int, c: Vector2i) -> bool:
	if c.y < 0 or c.y + 1 >= h:
		return false
	for dx: int in range(-1, 2):
		if _at(grid, w, h, c.x + dx, c.y) != WALL:
			return false
		if _at(grid, w, h, c.x + dx, c.y + 1) != FLOOR:
			return false
	return true

## Lower is better: distance from the wanted column, plus a penalty when the
## gate would sit flush in a corner (no floor one cell past either end).
static func _score(grid: PackedByteArray, w: int, h: int, c: Vector2i, want_x: int) -> int:
	var s: int = absi(c.x - want_x)
	if _at(grid, w, h, c.x - 2, c.y + 1) != FLOOR or _at(grid, w, h, c.x + 2, c.y + 1) != FLOOR:
		s += 100
	return s

## Best slot on room r's top wall (the row just above the room), or (-1, -1).
static func room_slot(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> Vector2i:
	var rx: int = int(r.x)
	var ry: int = int(r.y)
	var rw: int = int(r.w)
	var cx: int = rx + int(rw / 2.0)
	var best := Vector2i(-1, -1)
	var best_s: int = 1 << 30
	for x: int in range(rx + 1, rx + rw - 1):
		var c := Vector2i(x, ry - 1)
		if not is_slot(grid, w, h, c):
			continue
		var s: int = _score(grid, w, h, c, cx)
		if s < best_s:
			best_s = s
			best = c
	return best

## Every slot inside a square window around center, nearest first (fallback search).
static func near_slots(grid: PackedByteArray, w: int, h: int, center: Vector2i, rad: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(maxi(0, center.y - rad), mini(h - 1, center.y + rad + 1)):
		for x: int in range(maxi(1, center.x - rad), mini(w - 1, center.x + rad + 1)):
			var c := Vector2i(x, y)
			if is_slot(grid, w, h, c):
				out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return absi(a.x - center.x) + absi(a.y - center.y) < absi(b.x - center.x) + absi(b.y - center.y))
	return out
