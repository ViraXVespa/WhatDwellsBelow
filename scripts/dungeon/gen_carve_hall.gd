extends Object

## Gen carve hall bookkeeping: width rolls, span dig, axis carve, hall rect notes. Owns the hall list.

const WALL := 0
const FLOOR := 1

static var _halls: Array = []

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
