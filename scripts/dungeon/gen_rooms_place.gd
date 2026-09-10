extends Object

## Hall ambush / dead-end marks. Host module is scripts/dungeon/gen_rooms.gd.

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen_carve.gd")


static func idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func floor_nbs(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var n := 0
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in nbs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
			continue
		if grid[idx(nx, ny, w)] == FLOOR:
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
	var roomish := {}
	for r in rooms:
		var x0 := int(r.x) - 1
		var y0 := int(r.y) - 1
		var x1 := int(r.x) + int(r.w)
		var y1 := int(r.y) + int(r.h)
		for yy in range(y0, y1 + 1):
			for xx in range(x0, x1 + 1):
				roomish[Vector2i(xx, yy)] = true
	var halls: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var c := Vector2i(x, y)
			if roomish.has(c):
				continue
			if floor_nbs(grid, w, h, x, y) >= 2:
				halls.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 73856093 + h * 19349663 + halls.size()
	var Rooms = load("res://scripts/dungeon/gen_rooms.gd")
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
	for r in rooms:
		var kind := str(r.get("kind", "normal"))
		if kind == "spawn" or kind == "boss":
			continue
		if room_exits(grid, w, h, r) <= 1:
			out.append(Carve.center(r))
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			if floor_nbs(grid, w, h, x, y) != 1:
				continue
			var c := Vector2i(x, y)
			var inside := false
			for r in rooms:
				if in_room(r, c):
					inside = true
					break
			if inside:
				continue
			out.append(c)
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
