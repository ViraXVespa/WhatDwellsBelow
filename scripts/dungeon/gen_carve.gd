extends Object

const WALL := 0
const FLOOR := 1

static var _halls: Array = []
static var _disk_ox: PackedInt32Array = PackedInt32Array()
static var _disk_oy: PackedInt32Array = PackedInt32Array()
static var _disk_rad: int = -1


static func begin_halls() -> void:
	_halls = []


static func take_halls() -> Array:
	var out: Array = _halls
	_halls = []
	return out


static func _note_rect(map_w: int, map_h: int, x0: int, y0: int, x1: int, y1: int, heading: Vector2i, width: int) -> void:
	var span_n: int = maxi(1, width)
	var xa: int = mini(x0, x1)
	var xb: int = maxi(x0, x1)
	var ya: int = mini(y0, y1)
	var yb: int = maxi(y0, y1)
	var rx0: int = xa
	var ry0: int = ya
	var rx1: int = xb
	var ry1: int = yb
	if heading.y == 0:
		ry1 = ya + span_n - 1
	else:
		rx1 = xa + span_n - 1
	if xb < 1 or xa > map_w - 2 or yb < 1 or ya > map_h - 2:
		return
	rx0 = clampi(rx0, 1, map_w - 2)
	ry0 = clampi(ry0, 1, map_h - 2)
	rx1 = clampi(rx1, 1, map_w - 2)
	ry1 = clampi(ry1, 1, map_h - 2)
	if rx1 < rx0 or ry1 < ry0:
		return
	_halls.append({"k": "rect", "x0": rx0, "y0": ry0, "x1": rx1, "y1": ry1})


static func _note_band(a: Vector2i, b: Vector2i, width: int) -> void:
	_halls.append({"k": "band", "ax": a.x, "ay": a.y, "bx": b.x, "by": b.y, "w": maxi(1, width)})


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


static func _hall_w_min() -> int:
	if App.bal:
		return clampi(int(App.bal.get("hall_w_min")), 1, 4)
	return 2


static func _hall_w_mode() -> int:
	if App.bal:
		return clampi(int(App.bal.get("hall_w_mode")), 2, 4)
	return 3


static func _hall_w_max() -> int:
	if App.bal:
		return clampi(int(App.bal.get("hall_w_max")), 2, 6)
	return 4


static func _hall_interval() -> int:
	if App.bal:
		return maxi(4, int(App.bal.get("hall_w_interval")))
	return 10


static func roll_hall_width(rng: RandomNumberGenerator) -> int:
	var lo := _hall_w_min()
	var mid := clampi(_hall_w_mode(), lo, _hall_w_max())
	var hi := maxi(mid, _hall_w_max())
	var min_pct := 0.15
	var mode_pct := 0.60
	if App.bal:
		min_pct = clampf(float(App.bal.get("hall_w_min_pct")), 0.0, 1.0)
		mode_pct = clampf(float(App.bal.get("hall_w_mode_pct")), 0.0, 1.0)
	var roll := rng.randf()
	if roll < min_pct:
		return lo
	if roll < min_pct + mode_pct:
		return mid
	return hi


static func dig_span(grid: PackedByteArray, w: int, h: int, x: int, y: int, heading: Vector2i, width: int) -> void:
	var n: int = maxi(1, width)
	if heading.y == 0:
		if x <= 0 or x >= w - 1:
			return
		var i: int = 0
		while i < n:
			var yy: int = y + i
			if yy > 0 and yy < h - 1:
				grid[yy * w + x] = FLOOR
			i += 1
	else:
		if y <= 0 or y >= h - 1:
			return
		var j: int = 0
		while j < n:
			var xx: int = x + j
			if xx > 0 and xx < w - 1:
				grid[y * w + xx] = FLOOR
			j += 1


static func dig_wide(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	dig_span(grid, w, h, x, y, Vector2i(1, 0), _hall_w_mode())


static func carve_room(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> void:
	for yy in range(r.y, r.y + r.h):
		for xx in range(r.x, r.x + r.w):
			if xx <= 0 or yy <= 0 or xx >= w - 1 or yy >= h - 1:
				continue
			grid[idx(xx, yy, w)] = FLOOR


static func place_spread_rooms(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, want: int, rmin: int, rmax: int) -> void:
	var cols := maxi(3, int(ceil(sqrt(float(want)))))
	var rows := cols
	var cell_w := maxi(6, int((w - 6) / float(cols)))
	var cell_h := maxi(6, int((h - 6) / float(rows)))
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
	var interval := _hall_interval()
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
		var width := roll_hall_width(rng)
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
				width = roll_hall_width(rng)
			dig_span(grid, w, h, x, y, heading, width)
			last = Vector2i(x, y)
			if not run_on:
				run_x = x
				run_y = y
				run_h = heading
				run_w = width
				run_on = true
			elif heading != run_h or width != run_w:
				_note_rect(w, h, run_x, run_y, prev_x, prev_y, run_h, run_w)
				run_x = x
				run_y = y
				run_h = heading
				run_w = width
		if run_on:
			_note_rect(w, h, run_x, run_y, x, y, run_h, run_w)
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


static func _seg_dist2(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var vx: float = bx - ax
	var vy: float = by - ay
	var len2: float = vx * vx + vy * vy
	if len2 < 0.0001:
		var dx0: float = px - ax
		var dy0: float = py - ay
		return dx0 * dx0 + dy0 * dy0
	var t: float = clampf(((px - ax) * vx + (py - ay) * vy) / len2, 0.0, 1.0)
	var qx: float = ax + t * vx
	var qy: float = ay + t * vy
	var dx1: float = px - qx
	var dy1: float = py - qy
	return dx1 * dx1 + dy1 * dy1


static func _prime_disk(rad: int) -> void:
	if rad == _disk_rad:
		return
	_disk_rad = rad
	_disk_ox = PackedInt32Array()
	_disk_oy = PackedInt32Array()
	var r2: int = rad * rad + 1
	var oy: int = -rad
	while oy <= rad:
		var ox: int = -rad
		while ox <= rad:
			if ox * ox + oy * oy <= r2:
				_disk_ox.append(ox)
				_disk_oy.append(oy)
			ox += 1
		oy += 1


static func _stamp_band(
	grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i, width: int
) -> void:
	var rad: int = maxi(1, int(ceil(float(maxi(1, width)) * 0.5)))
	_prime_disk(rad)
	_note_band(a, b, width)
	var steps: int = maxi(1, absi(b.x - a.x) + absi(b.y - a.y))
	var off_n: int = _disk_ox.size()
	var s: int = 0
	while s <= steps:
		var t: float = float(s) / float(steps)
		var cx: int = int(round(lerpf(float(a.x), float(b.x), t)))
		var cy: int = int(round(lerpf(float(a.y), float(b.y), t)))
		var k: int = 0
		while k < off_n:
			var xx: int = cx + _disk_ox[k]
			var yy: int = cy + _disk_oy[k]
			k += 1
			if xx <= 0 or yy <= 0 or xx >= w - 1 or yy >= h - 1:
				continue
			var i: int = yy * w + xx
			if grid[i] == FLOOR:
				continue
			grid[i] = FLOOR
		s += 1


static func _carve_band(
	rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i
) -> void:
	var width: int = roll_hall_width(rng)
	if rng.randf() < 0.22:
		var px: int = 0
		var py: int = 0
		var bump: int = (2 + rng.randi() % 3) * (1 if rng.randf() < 0.5 else -1)
		if absi(b.x - a.x) >= absi(b.y - a.y):
			py = bump
		else:
			px = bump
		var mid := Vector2i(
			clampi(int(float(a.x + b.x) * 0.5) + px, 1, w - 3),
			clampi(int(float(a.y + b.y) * 0.5) + py, 1, h - 3)
		)
		_stamp_band(grid, w, h, a, mid, width)
		width = roll_hall_width(rng)
		_stamp_band(grid, w, h, mid, b, width)
	else:
		_stamp_band(grid, w, h, a, b, width)
	dig_span(grid, w, h, a.x, a.y, Vector2i(1, 0), width)
	dig_span(grid, w, h, b.x, b.y, Vector2i(1, 0), width)
	_note_rect(w, h, a.x, a.y, a.x, a.y, Vector2i(1, 0), width)
	_note_rect(w, h, b.x, b.y, b.x, b.y, Vector2i(1, 0), width)


static func carve_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	if absi(b.x - a.x) >= 2 and absi(b.y - a.y) >= 2:
		_carve_band(rng, grid, w, h, a, b)
		return
	var x := a.x
	var y := a.y
	var guard := 0
	var limit := absi(a.x - b.x) + absi(a.y - b.y) + 36
	var heading := Vector2i(1, 0)
	if absi(b.x - a.x) < absi(b.y - a.y):
		heading = Vector2i(0, 1 if b.y > a.y else -1)
	elif b.x != a.x:
		heading = Vector2i(1 if b.x > a.x else -1, 0)
	var width := roll_hall_width(rng)
	var interval := _hall_interval()
	var steps := 0
	dig_span(grid, w, h, x, y, heading, width)
	var run_x: int = x
	var run_y: int = y
	var run_h: Vector2i = heading
	var run_w: int = width
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
		var prev_x: int = x
		var prev_y: int = y
		heading = d
		x = clampi(x + d.x, 1, w - 3)
		y = clampi(y + d.y, 1, h - 3)
		steps += 1
		if steps % interval == 0:
			width = roll_hall_width(rng)
		dig_span(grid, w, h, x, y, heading, width)
		if heading != run_h or width != run_w:
			_note_rect(w, h, run_x, run_y, prev_x, prev_y, run_h, run_w)
			run_x = x
			run_y = y
			run_h = heading
			run_w = width
	_note_rect(w, h, run_x, run_y, x, y, run_h, run_w)
	dig_span(grid, w, h, b.x, b.y, heading, width)
	if b.x != x or b.y != y:
		_note_rect(w, h, b.x, b.y, b.x, b.y, heading, width)
