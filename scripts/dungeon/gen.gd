extends Object

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen_carve.gd")
const Rooms := preload("res://scripts/dungeon/gen_rooms.gd")


static func cycle_of(floor_n: int) -> int:
	return int((maxi(1, floor_n) - 1) / 5)


static func loop_index(floor_n: int) -> int:
	return ((maxi(1, floor_n) - 1) % 5) + 1


static func is_gate_master(floor_n: int) -> bool:
	return loop_index(floor_n) == 5


static func boss_title(floor_n: int) -> String:
	if is_gate_master(floor_n):
		return "Gate Master"
	return "Floor Guardian"


static func idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func generate(floor_n: int, seed: int, bal: Object) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) * 10007 + floor_n * 9176
	var w := maxi(24, int(bal.get("gen_w")))
	var h := maxi(24, int(bal.get("gen_h")))
	var want := maxi(6, int(bal.get("gen_rooms")))
	var rmin := maxi(4, int(bal.get("gen_room_min")))
	var rmax := maxi(rmin + 1, int(bal.get("gen_room_max")))
	var loops := maxi(0, int(bal.get("gen_extra_loops")))
	for _try in 24:
		var data := _try_gen(rng, w, h, want, rmin, rmax, loops, bal)
		if data.get("ok", false):
			data["floor"] = floor_n
			data["cycle"] = cycle_of(floor_n)
			data["boss_title"] = boss_title(floor_n)
			data["gate_master"] = is_gate_master(floor_n)
			return data
	return _fallback(floor_n, w, h)


static func _try_gen(rng: RandomNumberGenerator, w: int, h: int, want: int, rmin: int, rmax: int, loops: int, bal: Object) -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = []
	var pack := clampi(want, 28, 42)
	Carve.place_spread_rooms(rng, grid, w, h, rooms, pack, rmin, rmax)
	if rooms.size() < 6:
		return {"ok": false, "rooms": rooms}
	Carve.connect_winding_tree(rng, grid, w, h, rooms)
	Carve.extra_winding_loops(rng, grid, w, h, rooms, mini(2, loops))
	Carve.carve_deadend_spurs(rng, grid, w, h, rooms, mini(6, maxi(3, pack / 10)))
	Rooms.assign_kinds(rng, grid, w, h, rooms, bal)
	var spawn_r: Dictionary = Rooms.find_kind(rooms, "spawn")
	var boss_r: Dictionary = Rooms.find_kind(rooms, "boss")
	if spawn_r.is_empty() or boss_r.is_empty():
		return {"ok": false, "rooms": rooms}
	if Carve.dist(spawn_r, boss_r) < Rooms.min_boss_sep(w, h):
		return {"ok": false, "rooms": rooms}
	var ambushes: Array = Rooms.mark_ambushes(grid, w, h, rooms)
	var spawn := Carve.center(spawn_r)
	var openings: Array = boss_openings(grid, w, h, boss_r)
	var door := _boss_door_cell(grid, w, h, boss_r, spawn)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [make_opening(_guess_side(boss_r, door), [door])]
	if openings.is_empty() or door == Vector2i(-1, -1):
		if openings.is_empty():
			return {"ok": false, "rooms": rooms}
		door = openings[0]["cells"][0]
	return {
		"ok": true,
		"grid": grid,
		"w": w,
		"h": h,
		"rooms": rooms,
		"spawn": spawn,
		"crystal": spawn,
		"stairs": _far_cell(boss_r, door),
		"door": door,
		"openings": openings,
		"boss": Carve.center(boss_r),
		"ambushes": ambushes,
		"bases": Rooms.kind_centers(rooms, "base"),
		"safe": Rooms.kind_centers(rooms, "clerk") + Rooms.kind_centers(rooms, "shop") + Rooms.kind_centers(rooms, "puzzle") + Rooms.kind_centers(rooms, "stash") + Rooms.kind_centers(rooms, "vein"),
	}


static func _ri(r: Dictionary, k: String) -> int:
	return int(r[k])


static func _outside_floor(grid: PackedByteArray, w: int, h: int, boss: Dictionary, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var bx := _ri(boss, "x")
	var by := _ri(boss, "y")
	var bw := _ri(boss, "w")
	var bh := _ri(boss, "h")
	if x >= bx and y >= by and x < bx + bw and y < by + bh:
		return false
	return grid[idx(x, y, w)] == FLOOR


static func _guess_side(boss: Dictionary, cell: Vector2i) -> String:
	var bx := _ri(boss, "x")
	var by := _ri(boss, "y")
	var bw := _ri(boss, "w")
	var bh := _ri(boss, "h")
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
	for raw in cells:
		packed.append(Vector2i(raw))
	if packed.is_empty():
		return {}
	var minx: int = packed[0].x
	var maxx: int = packed[0].x
	var miny: int = packed[0].y
	var maxy: int = packed[0].y
	for c in packed:
		var cell: Vector2i = c
		minx = mini(minx, cell.x)
		maxx = maxi(maxx, cell.x)
		miny = mini(miny, cell.y)
		maxy = maxi(maxy, cell.y)
	var thick := 1.05
	var pad := 0.2
	var sx: float
	var sz: float
	if side == "n" or side == "s":
		sx = float(maxx - minx + 1) + pad
		sz = thick
	else:
		sx = thick
		sz = float(maxy - miny + 1) + pad
	var cx := (float(minx) + float(maxx) + 1.0) * 0.5
	var cz := (float(miny) + float(maxy) + 1.0) * 0.5
	var span := maxf(sx, sz)
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
	var bx := _ri(boss, "x")
	var by := _ri(boss, "y")
	var bw := _ri(boss, "w")
	var bh := _ri(boss, "h")
	var north: Array = []
	var south: Array = []
	var east: Array = []
	var west: Array = []
	for y in range(by, by + bh):
		for x in range(bx, bx + bw):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var cell := Vector2i(x, y)
			if _outside_floor(grid, w, h, boss, x, y - 1):
				north.append(cell)
			if _outside_floor(grid, w, h, boss, x, y + 1):
				south.append(cell)
			if _outside_floor(grid, w, h, boss, x - 1, y):
				west.append(cell)
			if _outside_floor(grid, w, h, boss, x + 1, y):
				east.append(cell)
	out.append_array(_side_runs("n", north))
	out.append_array(_side_runs("s", south))
	out.append_array(_side_runs("e", east))
	out.append_array(_side_runs("w", west))
	return out


static func _side_runs(side: String, cells: Array) -> Array:
	var uniq := {}
	var list: Array = []
	for raw in cells:
		var c := Vector2i(raw)
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
	for c in list:
		if cur.is_empty():
			cur.append(c)
			continue
		var prev: Vector2i = cur[cur.size() - 1]
		var gap := absi(c.x - prev.x) + absi(c.y - prev.y)
		if gap == 1:
			cur.append(c)
		else:
			runs.append(make_opening(side, cur))
			cur = [c]
	if not cur.is_empty():
		runs.append(make_opening(side, cur))
	return runs


static func _boss_door_cell(grid: PackedByteArray, w: int, h: int, boss: Dictionary, spawn: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	var bx := _ri(boss, "x")
	var by := _ri(boss, "y")
	var bw := _ri(boss, "w")
	var bh := _ri(boss, "h")
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(by, by + bh):
		for x in range(bx, bx + bw):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var edge: bool = x == bx or y == by or x == bx + bw - 1 or y == by + bh - 1
			if not edge:
				continue
			var outside := false
			for n in nbs:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if nx < bx or ny < by or nx >= bx + bw or ny >= by + bh:
					if grid[idx(nx, ny, w)] == FLOOR:
						outside = true
			if not outside:
				continue
			var d := absi(x - spawn.x) + absi(y - spawn.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


static func _far_cell(room: Dictionary, from: Vector2i) -> Vector2i:
	var best := Carve.center(room)
	var best_d := -1
	var rx := _ri(room, "x")
	var ry := _ri(room, "y")
	var rw := _ri(room, "w")
	var rh := _ri(room, "h")
	for y in range(ry + 1, ry + rh - 1):
		for x in range(rx + 1, rx + rw - 1):
			var d := absi(x - from.x) + absi(y - from.y)
			if d > best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


static func is_safe_kind(kind: String) -> bool:
	return kind == "clerk" or kind == "shop" or kind == "puzzle" or kind == "spawn" or kind == "stash" or kind == "vein"


static func _fallback(floor_n: int, w: int, h: int) -> Dictionary:
	w = maxi(28, w)
	h = maxi(28, h)
	var grid := PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = [
		{"x": 3, "y": 3, "w": 8, "h": 8, "kind": "spawn"},
		{"x": mini(w - 12, maxi(12, int(w * 0.35))), "y": 4, "w": 7, "h": 7, "kind": "base"},
		{"x": 4, "y": mini(h - 12, maxi(12, int(h * 0.35))), "w": 7, "h": 7, "kind": "clerk", "role": "gather"},
		{"x": maxi(12, w - 11), "y": maxi(12, h - 11), "w": 8, "h": 8, "kind": "boss"},
	]
	for r in rooms:
		Carve.carve_room(grid, w, h, r)
	var rng := RandomNumberGenerator.new()
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[0]), Carve.center(rooms[1]))
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[0]), Carve.center(rooms[2]))
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[1]), Carve.center(rooms[3]))
	var boss_r: Dictionary = rooms[3]
	var spawn := Carve.center(rooms[0])
	var door := _boss_door_cell(grid, w, h, boss_r, spawn)
	if door == Vector2i(-1, -1):
		door = Vector2i(boss_r.x, Carve.center(boss_r).y)
		Carve.dig(grid, w, h, door.x - 1, door.y)
	var openings: Array = boss_openings(grid, w, h, boss_r)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [make_opening(_guess_side(boss_r, door), [door])]
	return {
		"ok": true,
		"grid": grid,
		"w": w,
		"h": h,
		"rooms": rooms,
		"spawn": spawn,
		"crystal": spawn,
		"stairs": _far_cell(boss_r, door),
		"door": door,
		"openings": openings,
		"boss": Carve.center(boss_r),
		"ambushes": [],
		"bases": [Carve.center(rooms[1])],
		"safe": [Carve.center(rooms[2])],
		"floor": floor_n,
		"cycle": cycle_of(floor_n),
		"boss_title": boss_title(floor_n),
		"gate_master": is_gate_master(floor_n),
	}
