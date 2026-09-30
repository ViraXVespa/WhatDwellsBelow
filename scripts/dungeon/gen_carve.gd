extends Object

const WALL := 0
const FLOOR := 1

static var _halls: Array = []
static var _disk_ox: PackedInt32Array = PackedInt32Array()
static var _disk_oy: PackedInt32Array = PackedInt32Array()
static var _disk_rad: int = -1
static var _near: PackedByteArray = PackedByteArray()
static var _near_w: int = 0


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
	_near_build(grid, w, h, _hug_gap())
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
static func _near_stamp(w: int, h: int, x: int, y: int, r: int) -> void:
	var y0: int = maxi(0, y - r)
	var y1: int = mini(h - 1, y + r)
	var x0: int = maxi(0, x - r)
	var x1: int = mini(w - 1, x + r)
	var yy: int = y0
	while yy <= y1:
		var row: int = yy * w
		var xx: int = x0
		while xx <= x1:
			_near[row + xx] = 1
			xx += 1
		yy += 1


static func _near_build(grid: PackedByteArray, w: int, h: int, gap: int) -> void:
	var n: int = w * h
	_near.resize(n)
	_near.fill(0)
	_near_w = w
	var r: int = maxi(1, gap)
	var y: int = 1
	while y < h - 1:
		var row: int = y * w
		var x: int = 1
		while x < w - 1:
			if grid[row + x] == FLOOR:
				_near_stamp(w, h, x, y, r)
			x += 1
		y += 1


static func _near_paint_axis(w: int, h: int, a: Vector2i, b: Vector2i, gap: int) -> void:
	var r: int = maxi(1, gap)
	var heading: Vector2i = Vector2i(0, 0)
	if b.x != a.x:
		heading = Vector2i(1 if b.x > a.x else -1, 0)
	elif b.y != a.y:
		heading = Vector2i(0, 1 if b.y > a.y else -1)
	else:
		_near_stamp(w, h, a.x, a.y, r)
		return
	var x: int = a.x
	var y: int = a.y
	var guard: int = 0
	var limit: int = absi(a.x - b.x) + absi(a.y - b.y) + 4
	while guard < limit:
		guard += 1
		_near_stamp(w, h, x, y, r)
		if x == b.x and y == b.y:
			return
		x += heading.x
		y += heading.y
static func _hug_gap() -> int:
	var floor_min: int = 3
	var gap: int = 4
	if App.bal:
		floor_min = maxi(1, int(App.bal.get("hall_hug_gap_min")))
		gap = int(App.bal.get("hall_hug_gap"))
	return maxi(floor_min, gap)


static func _in_room(r: Dictionary, x: int, y: int) -> bool:
	return x >= int(r.x) and y >= int(r.y) and x < int(r.x) + int(r.w) and y < int(r.y) + int(r.h)


static func _cell_hugs(grid: PackedByteArray, w: int, h: int, x: int, y: int, gap: int, a: Dictionary, b: Dictionary) -> bool:
	var r: int = maxi(1, gap)
	var ax0: int = int(a["x"])
	var ay0: int = int(a["y"])
	var ax1: int = ax0 + int(a["w"])
	var ay1: int = ay0 + int(a["h"])
	var bx0: int = int(b["x"])
	var by0: int = int(b["y"])
	var bx1: int = bx0 + int(b["w"])
	var by1: int = by0 + int(b["h"])
	var y0: int = maxi(1, y - r)
	var y1: int = mini(h - 2, y + r)
	var x0: int = maxi(1, x - r)
	var x1: int = mini(w - 2, x + r)
	var yy: int = y0
	while yy <= y1:
		var row: int = yy * w
		var xx: int = x0
		while xx <= x1:
			if xx != x or yy != y:
				if grid[row + xx] == FLOOR:
					var in_a: bool = xx >= ax0 and xx < ax1 and yy >= ay0 and yy < ay1
					var in_b: bool = xx >= bx0 and xx < bx1 and yy >= by0 and yy < by1
					if not in_a and not in_b:
						return true
			xx += 1
		yy += 1
	return false
static func _loop_hugs(old_g: PackedByteArray, new_g: PackedByteArray, w: int, h: int, a: Dictionary, b: Dictionary, gap: int) -> bool:
	var pad: int = maxi(2, gap + 2)
	var x0: int = mini(int(a.x), int(b.x)) - pad
	var y0: int = mini(int(a.y), int(b.y)) - pad
	var x1: int = maxi(int(a.x) + int(a.w), int(b.x) + int(b.w)) + pad
	var y1: int = maxi(int(a.y) + int(a.h), int(b.y) + int(b.h)) + pad
	x0 = clampi(x0, 1, w - 2)
	y0 = clampi(y0, 1, h - 2)
	x1 = clampi(x1, 1, w - 2)
	y1 = clampi(y1, 1, h - 2)
	var y: int = y0
	while y <= y1:
		var x: int = x0
		while x <= x1:
			var i: int = y * w + x
			if new_g[i] == FLOOR and old_g[i] != FLOOR:
				if _cell_hugs(old_g, w, h, x, y, gap, a, b):
					return true
			x += 1
		y += 1
	return false


static func _restore(grid: PackedByteArray, saved: PackedByteArray) -> void:
	var i: int = 0
	var n: int = mini(grid.size(), saved.size())
	while i < n:
		grid[i] = saved[i]
		i += 1


static func _axis_hugs(grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i, gap: int, ra: Dictionary, rb: Dictionary) -> bool:
	var heading: Vector2i = Vector2i(0, 0)
	if b.x != a.x:
		heading = Vector2i(1 if b.x > a.x else -1, 0)
	elif b.y != a.y:
		heading = Vector2i(0, 1 if b.y > a.y else -1)
	else:
		return false
	var ax0: int = int(ra["x"])
	var ay0: int = int(ra["y"])
	var ax1: int = ax0 + int(ra["w"])
	var ay1: int = ay0 + int(ra["h"])
	var bx0: int = int(rb["x"])
	var by0: int = int(rb["y"])
	var bx1: int = bx0 + int(rb["w"])
	var by1: int = by0 + int(rb["h"])
	var r: int = maxi(1, gap)
	var use_near: bool = _near.size() == w * h
	var x: int = a.x
	var y: int = a.y
	var guard: int = 0
	var limit: int = absi(a.x - b.x) + absi(a.y - b.y) + 4
	while guard < limit:
		guard += 1
		if x < 1 or y < 1 or x > w - 3 or y > h - 3:
			return true
		var i: int = y * w + x
		if grid[i] != FLOOR and (not use_near or _near[i] != 0):
			var y0: int = maxi(1, y - r)
			var y1: int = mini(h - 2, y + r)
			var x0: int = maxi(1, x - r)
			var x1: int = mini(w - 2, x + r)
			var yy: int = y0
			var hit: bool = false
			while yy <= y1 and not hit:
				var row: int = yy * w
				var xx: int = x0
				while xx <= x1:
					if xx != x or yy != y:
						if grid[row + xx] == FLOOR:
							var in_a: bool = xx >= ax0 and xx < ax1 and yy >= ay0 and yy < ay1
							var in_b: bool = xx >= bx0 and xx < bx1 and yy >= by0 and yy < by1
							if not in_a and not in_b:
								hit = true
								break
					xx += 1
				yy += 1
			if hit:
				return true
		if x == b.x and y == b.y:
			return false
		x += heading.x
		y += heading.y
	return true
static func _dogleg_mid(grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i, gap: int, ra: Dictionary, rb: Dictionary) -> Vector2i:
	var mids: Array[Vector2i] = [Vector2i(b.x, a.y), Vector2i(a.x, b.y)]
	for mid in mids:
		if _axis_hugs(grid, w, h, a, mid, gap, ra, rb):
			continue
		if _axis_hugs(grid, w, h, mid, b, gap, ra, rb):
			continue
		return mid
	return Vector2i(-9999, -9999)


static func _attempt_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, ra: Dictionary, rb: Dictionary) -> bool:
	var gap: int = _hug_gap()
	var ca: Vector2i = center(ra)
	var cb: Vector2i = center(rb)
	var mid: Vector2i = _dogleg_mid(grid, w, h, ca, cb, gap, ra, rb)
	if mid.x < -9000:
		return false
	var width: int = roll_hall_width(rng)
	_carve_axis(grid, w, h, ca, mid, width)
	_carve_axis(grid, w, h, mid, cb, width)
	_near_paint_axis(w, h, ca, mid, gap)
	_near_paint_axis(w, h, mid, cb, gap)
	return true
static func extra_winding_loops(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, extra: int) -> void:
	if extra <= 0 or rooms.size() < 3:
		return
	var n: int = rooms.size()
	var want: int = extra
	var landed: int = 0
	var tries: int = 0
	var cap: int = want * 6
	if _near.size() != w * h:
		_near_build(grid, w, h, _hug_gap())
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
			if _cell_hugs(grid, w, h, x, y, _hug_gap(), src, src):
				break
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


static func _carve_axis(grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i, width: int) -> void:
	if a == b:
		dig_span(grid, w, h, a.x, a.y, Vector2i(1, 0), width)
		_note_rect(w, h, a.x, a.y, a.x, a.y, Vector2i(1, 0), width)
		return
	var heading: Vector2i = Vector2i(0, 0)
	if b.x != a.x:
		heading = Vector2i(1 if b.x > a.x else -1, 0)
	else:
		heading = Vector2i(0, 1 if b.y > a.y else -1)
	var x: int = a.x
	var y: int = a.y
	var guard: int = 0
	var limit: int = absi(a.x - b.x) + absi(a.y - b.y) + 4
	while (x != b.x or y != b.y) and guard < limit:
		guard += 1
		dig_span(grid, w, h, x, y, heading, width)
		x = clampi(x + heading.x, 1, w - 3)
		y = clampi(y + heading.y, 1, h - 3)
	dig_span(grid, w, h, b.x, b.y, heading, width)
	_note_rect(w, h, a.x, a.y, b.x, b.y, heading, width)


static func carve_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var width: int = roll_hall_width(rng)
	var mid: Vector2i = Vector2i(b.x, a.y)
	if rng.randf() < 0.5:
		mid = Vector2i(a.x, b.y)
	_carve_axis(grid, w, h, a, mid, width)
	_carve_axis(grid, w, h, mid, b, width)
	if _near.size() == w * h:
		_near_paint_axis(w, h, a, mid, _hug_gap())
		_near_paint_axis(w, h, mid, b, _hug_gap())
