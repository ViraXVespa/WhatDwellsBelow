extends Object

## Hall ambush / dead-end marks. Host module is scripts/dungeon/gen/gen_rooms.gd.

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen/gen_carve.gd")

static func idx(x: int, y: int, w: int) -> int:
	return y * w + x

static func floor_nbs(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var n: int = 0
	var i: int = y * w + x
	if x + 1 < w - 1 and grid[i + 1] == FLOOR:
		n += 1
	if x - 1 >= 1 and grid[i - 1] == FLOOR:
		n += 1
	if y + 1 < h - 1 and grid[i + w] == FLOOR:
		n += 1
	if y - 1 >= 1 and grid[i - w] == FLOOR:
		n += 1
	return n

static func in_room(r: Dictionary, c: Vector2i) -> bool:
	return c.x >= int(r.x) and c.y >= int(r.y) and c.x < int(r.x) + int(r.w) and c.y < int(r.y) + int(r.h)

static func room_exits(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> int:
	var seen := {}
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for yy in range(int(r.y), int(r.y) + int(r.h)):
		for xx in range(int(r.x), int(r.x) + int(r.w)):
			for d in nbs:
				var nx: int = xx + d.x
				var ny: int = yy + d.y
				if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
					continue
				if grid[idx(nx, ny, w)] != FLOOR:
					continue
				var c := Vector2i(nx, ny)
				if in_room(r, c) or seen.has(c):
					continue
				seen[c] = true
	return seen.size()

static func mark_ambushes(grid: PackedByteArray, w: int, h: int, rooms: Array, bal: Object = null) -> Array:
	var roomish: PackedByteArray = PackedByteArray()
	roomish.resize(w * h)
	roomish.fill(0)
	for r in rooms:
		var x0: int = int(r.x) - 1
		var y0: int = int(r.y) - 1
		var x1: int = int(r.x) + int(r.w)
		var y1: int = int(r.y) + int(r.h)
		var yy: int = y0
		while yy <= y1:
			if yy >= 0 and yy < h:
				var row: int = yy * w
				var xx: int = x0
				while xx <= x1:
					if xx >= 0 and xx < w:
						roomish[row + xx] = 1
					xx += 1
			yy += 1
	var halls: Array[Vector2i] = []
	for y in range(1, h - 1):
		var row2: int = y * w
		for x in range(1, w - 1):
			var i: int = row2 + x
			if grid[i] != FLOOR:
				continue
			if roomish[i] != 0:
				continue
			if floor_nbs(grid, w, h, x, y) >= 2:
				halls.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 73856093 + h * 19349663 + halls.size()
	var Rooms = load("res://scripts/dungeon/gen/gen_rooms.gd")
	Rooms.shuffle_i(rng, halls)
	var spacing := 10
	var cap := 40
	if bal:
		spacing = maxi(4, int(bal.get("ambush_spacing")))
		cap = maxi(4, int(bal.get("ambush_cap")))
	var out: Array = []
	for c in halls:
		if out.size() >= cap:
			break
		var ok := true
		for p in out:
			var q: Vector2i = p
			if absi(q.x - c.x) + absi(q.y - c.y) < spacing:
				ok = false
				break
		if ok:
			out.append(c)
	return out

static func mark_deadends(grid: PackedByteArray, w: int, h: int, rooms: Array) -> Array:
	var out: Array = []
	var inside: PackedByteArray = PackedByteArray()
	inside.resize(w * h)
	inside.fill(0)
	for r in rooms:
		var kind: String = str(r.get("kind", "normal"))
		var ry: int = int(r.y)
		var rx: int = int(r.x)
		var rh: int = int(r.h)
		var rw: int = int(r.w)
		var y0: int = ry
		while y0 < ry + rh:
			if y0 >= 0 and y0 < h:
				var row: int = y0 * w
				var x0: int = rx
				while x0 < rx + rw:
					if x0 >= 0 and x0 < w:
						inside[row + x0] = 1
					x0 += 1
			y0 += 1
		if kind != "spawn" and kind != "boss":
			if room_exits(grid, w, h, r) <= 1:
				out.append(Carve.center(r))
	for y in range(1, h - 1):
		var row2: int = y * w
		for x in range(1, w - 1):
			var i: int = row2 + x
			if grid[i] != FLOOR:
				continue
			if floor_nbs(grid, w, h, x, y) != 1:
				continue
			if inside[i] != 0:
				continue
			out.append(Vector2i(x, y))
	var cleaned: Array = []
	for c in out:
		var ok := true
		for p in cleaned:
			var q: Vector2i = p
			if absi(q.x - c.x) + absi(q.y - c.y) < 8:
				ok = false
				break
		if ok:
			cleaned.append(c)
	return cleaned
