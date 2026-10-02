extends Object

## Gen carve near-mask and hug checks for winding halls. Owns the near mask.

const Hall := preload("res://scripts/dungeon/gen/carve_hall.gd")

static var _near: PackedByteArray = PackedByteArray()
static var _near_w: int = 0

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

static func _near_build(grid: PackedByteArray, w: int, h: int, gap: int, rooms: Array = []) -> void:
	var n: int = w * h
	_near.resize(n)
	_near.fill(0)
	_near_w = w
	var r: int = maxi(1, gap)
	if rooms.size() > 0:
		var ri: int = 0
		while ri < rooms.size():
			var rr: Dictionary = rooms[ri]
			ri += 1
			var x0: int = maxi(0, int(rr["x"]) - r)
			var y0: int = maxi(0, int(rr["y"]) - r)
			var x1: int = mini(w - 1, int(rr["x"]) + int(rr["w"]) - 1 + r)
			var y1: int = mini(h - 1, int(rr["y"]) + int(rr["h"]) - 1 + r)
			var yy: int = y0
			while yy <= y1:
				var row: int = yy * w
				var xx: int = x0
				while xx <= x1:
					_near[row + xx] = 1
					xx += 1
				yy += 1
		return
	var y: int = 1
	while y < h - 1:
		var row: int = y * w
		var x: int = 1
		while x < w - 1:
			if grid[row + x] == Hall.FLOOR:
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
				if grid[row + xx] == Hall.FLOOR:
					var in_a: bool = xx >= ax0 and xx < ax1 and yy >= ay0 and yy < ay1
					var in_b: bool = xx >= bx0 and xx < bx1 and yy >= by0 and yy < by1
					if not in_a and not in_b:
						return true
			xx += 1
		yy += 1
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
		if grid[i] != Hall.FLOOR and (not use_near or _near[i] != 0):
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
						if grid[row + xx] == Hall.FLOOR:
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
