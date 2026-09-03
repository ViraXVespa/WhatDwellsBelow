extends Object

const WALL := 0
const FLOOR := 1


static func idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func center(r: Dictionary) -> Vector2i:
	return Vector2i(r.x + int(r.w / 2), r.y + int(r.h / 2))


static func dist(a: Dictionary, b: Dictionary) -> int:
	var ca := center(a)
	var cb := center(b)
	return absi(ca.x - cb.x) + absi(ca.y - cb.y)


static func overlap(x: int, y: int, bw: int, bh: int, r: Dictionary) -> bool:
	return not (x + bw <= r.x or r.x + r.w <= x or y + bh <= r.y or r.y + r.h <= y)


static func can_place(rooms: Array, x: int, y: int, rw: int, rh: int) -> bool:
	for r in rooms:
		if overlap(x - 1, y - 1, rw + 2, rh + 2, r):
			return false
	return true


static func dig(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= w - 1 or y >= h - 1:
		return
	grid[idx(x, y, w)] = FLOOR


static func dig_wide(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	dig(grid, w, h, x, y)
	dig(grid, w, h, x + 1, y)
	dig(grid, w, h, x, y + 1)


static func carve_room(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> void:
	for yy in range(r.y, r.y + r.h):
		for xx in range(r.x, r.x + r.w):
			if xx <= 0 or yy <= 0 or xx >= w - 1 or yy >= h - 1:
				continue
			grid[idx(xx, yy, w)] = FLOOR


static func place_spread_rooms(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, want: int, rmin: int, rmax: int) -> void:
	var cols := maxi(3, int(ceil(sqrt(float(want)))))
	var rows := cols
	var cell_w := maxi(6, int((w - 6) / cols))
	var cell_h := maxi(6, int((h - 6) / rows))
	for gy in rows:
		for gx in cols:
			if rooms.size() >= want:
				return
			var rw := rng.randi_range(rmin, rmax)
			var rh := rng.randi_range(rmin, rmax)
			var slack_x := maxi(0, cell_w - rw - 1)
			var slack_y := maxi(0, cell_h - rh - 1)
			var x := clampi(3 + gx * cell_w + rng.randi_range(0, slack_x), 2, w - rw - 3)
			var y := clampi(3 + gy * cell_h + rng.randi_range(0, slack_y), 2, h - rh - 3)
			if not can_place(rooms, x, y, rw, rh):
				continue
			var room := {"x": x, "y": y, "w": rw, "h": rh, "kind": "normal"}
			rooms.append(room)
			carve_room(grid, w, h, room)
	for _i in want * 24:
		if rooms.size() >= want:
			return
		var rw2 := rng.randi_range(rmin, rmax)
		var rh2 := rng.randi_range(rmin, rmax)
		var x2 := rng.randi_range(2, maxi(2, w - rw2 - 3))
		var y2 := rng.randi_range(2, maxi(2, h - rh2 - 3))
		if not can_place(rooms, x2, y2, rw2, rh2):
			continue
		var extra := {"x": x2, "y": y2, "w": rw2, "h": rh2, "kind": "normal"}
		rooms.append(extra)
		carve_room(grid, w, h, extra)


static func connect_winding_tree(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array) -> void:
	var n := rooms.size()
	var used := PackedByteArray()
	used.resize(n)
	used.fill(0)
	used[0] = 1
	for _k in n - 1:
		var best_a := -1
		var best_b := -1
		var best_d := 1 << 30
		for i in n:
			if used[i] == 0:
				continue
			for j in n:
				if used[j] != 0:
					continue
				var d := dist(rooms[i], rooms[j]) + rng.randi_range(0, 8)
				if d < best_d:
					best_d = d
					best_a = i
					best_b = j
		if best_a < 0:
			break
		used[best_b] = 1
		carve_winding(rng, grid, w, h, center(rooms[best_a]), center(rooms[best_b]))


static func extra_winding_loops(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, extra: int) -> void:
	if extra <= 0 or rooms.size() < 4:
		return
	var added := 0
	var guard := 0
	while added < extra and guard < extra * 10:
		guard += 1
		var a := rng.randi() % rooms.size()
		var b := rng.randi() % rooms.size()
		if a == b:
			continue
		if dist(rooms[a], rooms[b]) < 18:
			continue
		carve_winding(rng, grid, w, h, center(rooms[a]), center(rooms[b]))
		added += 1


static func carve_deadend_spurs(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, count: int) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var added := 0
	var guard := 0
	while added < count and guard < count * 8:
		guard += 1
		if rooms.is_empty():
			return
		var src: Dictionary = rooms[rng.randi() % rooms.size()]
		var start := center(src)
		var heading: Vector2i = dirs[rng.randi() % dirs.size()]
		var x := start.x
		var y := start.y
		var length := rng.randi_range(10, 16)
		var last := start
		for _s in length:
			if rng.randf() < 0.18:
				heading = dirs[rng.randi() % dirs.size()]
			var nx: int = clampi(x + heading.x, 2, w - 3)
			var ny: int = clampi(y + heading.y, 2, h - 3)
			if nx == x and ny == y:
				continue
			x = nx
			y = ny
			dig_wide(grid, w, h, x, y)
			last = Vector2i(x, y)
		if can_place(rooms, last.x, last.y, 3, 3):
			var kind := "normal"
			if rng.randf() < 0.3:
				kind = "stash"
			elif rng.randf() < 0.18:
				kind = "stash"
			var spur := {"x": last.x, "y": last.y, "w": 3, "h": 3, "kind": kind}
			rooms.append(spur)
			carve_room(grid, w, h, spur)
		added += 1


static func carve_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	var guard := 0
	var limit := absi(a.x - b.x) + absi(a.y - b.y) + 36
	dig_wide(grid, w, h, x, y)
	while (x != b.x or y != b.y) and guard < limit:
		guard += 1
		var choices: Array[Vector2i] = []
		if x != b.x:
			choices.append(Vector2i(1 if b.x > x else -1, 0))
		if y != b.y:
			choices.append(Vector2i(0, 1 if b.y > y else -1))
		if rng.randf() < 0.22:
			var perp: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			choices.append(perp[rng.randi() % perp.size()])
		var d: Vector2i = choices[rng.randi() % choices.size()]
		x = clampi(x + d.x, 1, w - 3)
		y = clampi(y + d.y, 1, h - 3)
		dig_wide(grid, w, h, x, y)
	dig_wide(grid, w, h, b.x, b.y)
