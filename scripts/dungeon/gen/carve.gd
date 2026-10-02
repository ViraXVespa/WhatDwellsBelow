extends Object

const Hall := preload("res://scripts/dungeon/gen/carve_hall.gd")
const Near := preload("res://scripts/dungeon/gen/carve_near.gd")

const WALL := Hall.WALL
const FLOOR := Hall.FLOOR

static var _disk_ox: PackedInt32Array = PackedInt32Array()
static var _disk_oy: PackedInt32Array = PackedInt32Array()
static var _disk_rad: int = -1

static func begin_halls() -> void:
	Hall.begin_halls()

static func take_halls() -> Array:
	return Hall.take_halls()

static func idx(x: int, y: int, w: int) -> int:
	return y * w + x

static func center(r: Dictionary) -> Vector2i:
	return Vector2i(r.x + int(r.w / 2.0), r.y + int(r.h / 2.0))

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

static func carve_room(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> void:
	for yy in range(r.y, r.y + r.h):
		for xx in range(r.x, r.x + r.w):
			if xx <= 0 or yy <= 0 or xx >= w - 1 or yy >= h - 1:
				continue
			grid[idx(xx, yy, w)] = FLOOR

static func place_spread_rooms(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, want: int, rmin: int, rmax: int) -> void:
	var cols: int = maxi(3, int(ceil(sqrt(float(want)))))
	var rows: int = cols
	var slots: int = rows * cols
	var i: int = 0
	while i < slots and rooms.size() < want:
		var remain_slots: int = slots - i
		var remain_rooms: int = want - rooms.size()
		if remain_slots > remain_rooms and rng.randf() > float(remain_rooms) / float(remain_slots):
			i += 1
			continue
		var gx: int = i % cols
		var gy: int = int(float(i) / float(cols))
		var x_lo: int = 3 + int(gx * (w - 6) / float(cols))
		var x_hi: int = 3 + int((gx + 1) * (w - 6) / float(cols))
		var y_lo: int = 3 + int(gy * (h - 6) / float(rows))
		var y_hi: int = 3 + int((gy + 1) * (h - 6) / float(rows))
		var rw: int = rng.randi_range(rmin, rmax)
		var rh: int = rng.randi_range(rmin, rmax)
		var slack_x: int = maxi(0, (x_hi - x_lo) - rw - 1)
		var slack_y: int = maxi(0, (y_hi - y_lo) - rh - 1)
		var x: int = clampi(x_lo + rng.randi_range(0, slack_x), 2, w - rw - 3)
		var y: int = clampi(y_lo + rng.randi_range(0, slack_y), 2, h - rh - 3)
		i += 1
		if not can_place(rooms, x, y, rw, rh):
			continue
		var room: Dictionary = {"x": x, "y": y, "w": rw, "h": rh, "kind": "normal"}
		rooms.append(room)
		carve_room(grid, w, h, room)
	var _j: int = 0
	while _j < want * 24 and rooms.size() < want:
		_j += 1
		var rw2: int = rng.randi_range(rmin, rmax)
		var rh2: int = rng.randi_range(rmin, rmax)
		var x2: int = rng.randi_range(2, maxi(2, w - rw2 - 3))
		var y2: int = rng.randi_range(2, maxi(2, h - rh2 - 3))
		if not can_place(rooms, x2, y2, rw2, rh2):
			continue
		var extra: Dictionary = {"x": x2, "y": y2, "w": rw2, "h": rh2, "kind": "normal"}
		rooms.append(extra)
		carve_room(grid, w, h, extra)

static func connect_winding_tree(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array) -> void:
	var n := rooms.size()
	if n < 2:
		return
	Near._near_build(grid, w, h, Near._hug_gap(), rooms)
	var cx: PackedInt32Array = PackedInt32Array()
	var cy: PackedInt32Array = PackedInt32Array()
	cx.resize(n)
	cy.resize(n)
	var ri: int = 0
	while ri < n:
		var c: Vector2i = center(rooms[ri])
		cx[ri] = c.x
		cy[ri] = c.y
		ri += 1
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
				var d := absi(cx[i] - cx[j]) + absi(cy[i] - cy[j]) + rng.randi_range(0, 8)
				if d < best_d:
					best_d = d
					best_a = i
					best_b = j
		if best_a < 0:
			break
		used[best_b] = 1
		carve_winding(rng, grid, w, h, Vector2i(cx[best_a], cy[best_a]), Vector2i(cx[best_b], cy[best_b]))
static func _attempt_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, ra: Dictionary, rb: Dictionary) -> bool:
	var gap: int = Near._hug_gap()
	var ca: Vector2i = center(ra)
	var cb: Vector2i = center(rb)
	var mid: Vector2i = Near._dogleg_mid(grid, w, h, ca, cb, gap, ra, rb)
	if mid.x < -9000:
		return false
	var width: int = Hall.roll_hall_width(rng)
	Hall._carve_axis(grid, w, h, ca, mid, width)
	Hall._carve_axis(grid, w, h, mid, cb, width)
	Near._near_paint_axis(w, h, ca, mid, gap)
	Near._near_paint_axis(w, h, mid, cb, gap)
	return true
static func extra_winding_loops(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, extra: int) -> void:
	if extra <= 0 or rooms.size() < 3:
		return
	var n: int = rooms.size()
	var want: int = extra
	var landed: int = 0
	var tries: int = 0
	var cap: int = want * 6
	if Near._near.size() != w * h:
		Near._near_build(grid, w, h, Near._hug_gap(), rooms)
	while landed < want and tries < cap:
		tries += 1
		var ia: int = rng.randi() % n
		var ib: int = rng.randi() % n
		if ia == ib:
			continue
		var ra: Dictionary = rooms[ia]
		var rb: Dictionary = rooms[ib]
		if dist(ra, rb) < 18:
			continue
		if _attempt_winding(rng, grid, w, h, ra, rb):
			landed += 1
static func carve_deadend_spurs(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, count: int) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var added := 0
	var guard := 0
	var interval := Hall._hall_interval()
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
		var width := Hall.roll_hall_width(rng)
		var steps := 0
		var run_on := false
		var run_x := x
		var run_y := y
		var run_h := heading
		var run_w := width
		for _s in length:
			if rng.randf() < 0.18:
				heading = dirs[rng.randi() % dirs.size()]
			var nx: int = clampi(x + heading.x, 2, w - 3)
			var ny: int = clampi(y + heading.y, 2, h - 3)
			if nx == x and ny == y:
				continue
			var prev_x: int = x
			var prev_y: int = y
			x = nx
			y = ny
			steps += 1
			if steps % interval == 0:
				width = Hall.roll_hall_width(rng)
			if Near._cell_hugs(grid, w, h, x, y, Near._hug_gap(), src, src):
				break
			Hall.dig_span(grid, w, h, x, y, heading, width)
			last = Vector2i(x, y)
			if not run_on:
				run_x = x
				run_y = y
				run_h = heading
				run_w = width
				run_on = true
			elif heading != run_h or width != run_w:
				Hall._note_rect(w, h, run_x, run_y, prev_x, prev_y, run_h, run_w)
				run_x = x
				run_y = y
				run_h = heading
				run_w = width
		if run_on:
			Hall._note_rect(w, h, run_x, run_y, x, y, run_h, run_w)
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
	var width: int = Hall.roll_hall_width(rng)
	var mid: Vector2i = Vector2i(b.x, a.y)
	if rng.randf() < 0.5:
		mid = Vector2i(a.x, b.y)
	Hall._carve_axis(grid, w, h, a, mid, width)
	Hall._carve_axis(grid, w, h, mid, b, width)
	if Near._near.size() == w * h:
		Near._near_paint_axis(w, h, a, mid, Near._hug_gap())
		Near._near_paint_axis(w, h, mid, b, Near._hug_gap())
