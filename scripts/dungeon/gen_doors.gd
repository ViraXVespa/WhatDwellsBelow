extends Object

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen_carve.gd")


static func idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func _ri(r: Dictionary, k: String) -> int:
	return int(r[k])


static func outside_floor(grid: PackedByteArray, w: int, h: int, boss: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var bx: int = _ri(boss, "x")
	var by: int = _ri(boss, "y")
	var bw: int = _ri(boss, "w")
	var bh: int = _ri(boss, "h")
	if x >= bx and y >= by and x < bx + bw and y < by + bh:
		return false
	return grid[idx(x, y, w)] == FLOOR


static func guess_side(boss: Dictionary, cell: Vector2i) -> String:
	var bx: int = _ri(boss, "x")
	var by: int = _ri(boss, "y")
	var bw: int = _ri(boss, "w")
	var bh: int = _ri(boss, "h")
	if cell.y == by:
		return "n"
	if cell.y == by + bh - 1:
		return "s"
	if cell.x == bx:
		return "w"
	if cell.x == bx + bw - 1:
		return "e"
	return "s"


static func make_opening(side: String, cells: Array) -> Dictionary:
	var packed: Array = []
	for raw: Variant in cells:
		packed.append(Vector2i(raw))
	if packed.is_empty():
		return {}
	var minx: int = packed[0].x
	var maxx: int = packed[0].x
	var miny: int = packed[0].y
	var maxy: int = packed[0].y
	for c: Variant in packed:
		var cell: Vector2i = c
		minx = mini(minx, cell.x)
		maxx = maxi(maxx, cell.x)
		miny = mini(miny, cell.y)
		maxy = maxi(maxy, cell.y)
	var thick: float = 1.05
	var pad: float = 0.2
	var sx: float
	var sz: float
	if side == "n" or side == "s":
		sx = float(maxx - minx + 1) + pad
		sz = thick
	else:
		sx = thick
		sz = float(maxy - miny + 1) + pad
	var cx: float = (float(minx) + float(maxx) + 1.0) * 0.5
	var cz: float = (float(miny) + float(maxy) + 1.0) * 0.5
	var span: float = maxf(sx, sz)
	return {
		"side": side,
		"cells": packed,
		"cx": cx,
		"cz": cz,
		"sx": sx,
		"sz": sz,
		"reach": maxf(1.85, span * 0.5 + 1.1),
	}


static func boss_openings(grid: PackedByteArray, w: int, h: int, boss: Dictionary) -> Array:
	var out: Array = []
	if boss.is_empty():
		return out
	var bx: int = _ri(boss, "x")
	var by: int = _ri(boss, "y")
	var bw: int = _ri(boss, "w")
	var bh: int = _ri(boss, "h")
	var north: Array = []
	var south: Array = []
	var east: Array = []
	var west: Array = []
	for y: int in range(by, by + bh):
		for x: int in range(bx, bx + bw):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var cell: Vector2i = Vector2i(x, y)
			if outside_floor(grid, w, h, boss, x, y - 1):
				north.append(cell)
			if outside_floor(grid, w, h, boss, x, y + 1):
				south.append(cell)
			if outside_floor(grid, w, h, boss, x - 1, y):
				west.append(cell)
			if outside_floor(grid, w, h, boss, x + 1, y):
				east.append(cell)
	out.append_array(_side_runs("n", north))
	out.append_array(_side_runs("s", south))
	out.append_array(_side_runs("e", east))
	out.append_array(_side_runs("w", west))
	return out


static func _side_runs(side: String, cells: Array) -> Array:
	var uniq: Dictionary = {}
	var list: Array = []
	for raw: Variant in cells:
		var c: Vector2i = Vector2i(raw)
		if uniq.has(c):
			continue
		uniq[c] = true
		list.append(c)
	if side == "n" or side == "s":
		list.sort_custom(func(a, b): return a.x < b.x)
	else:
		list.sort_custom(func(a, b): return a.y < b.y)
	var runs: Array = []
	var cur: Array = []
	for c: Variant in list:
		if cur.is_empty():
			cur.append(c)
			continue
		var prev: Vector2i = cur[cur.size() - 1]
		var gap: int = absi(c.x - prev.x) + absi(c.y - prev.y)
		if gap == 1:
			cur.append(c)
		else:
			runs.append(make_opening(side, cur))
			cur = [c]
	if not cur.is_empty():
		runs.append(make_opening(side, cur))
	return runs


static func boss_door_cell(grid: PackedByteArray, w: int, h: int, boss: Dictionary, spawn: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 1 << 30
	var bx: int = _ri(boss, "x")
	var by: int = _ri(boss, "y")
	var bw: int = _ri(boss, "w")
	var bh: int = _ri(boss, "h")
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y: int in range(by, by + bh):
		for x: int in range(bx, bx + bw):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var edge: bool = x == bx or y == by or x == bx + bw - 1 or y == by + bh - 1
			if not edge:
				continue
			var outside: bool = false
			for n: Vector2i in nbs:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if nx < bx or ny < by or nx >= bx + bw or ny >= by + bh:
					if grid[idx(nx, ny, w)] == FLOOR:
						outside = true
			if not outside:
				continue
			var d: int = absi(x - spawn.x) + absi(y - spawn.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


static func far_cell(room: Dictionary, from: Vector2i) -> Vector2i:
	var best: Vector2i = Carve.center(room)
	var best_d: int = -1
	var rx: int = _ri(room, "x")
	var ry: int = _ri(room, "y")
	var rw: int = _ri(room, "w")
	var rh: int = _ri(room, "h")
	for y: int in range(ry + 1, ry + rh - 1):
		for x: int in range(rx + 1, rx + rw - 1):
			var d: int = absi(x - from.x) + absi(y - from.y)
			if d > best_d:
				best_d = d
				best = Vector2i(x, y)
	return best
