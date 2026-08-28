extends Object

const WALL := 0
const FLOOR := 1


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
	for _try in 8:
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
	for _i in want * 14:
		if rooms.size() >= want:
			break
		var rw := rng.randi_range(rmin, rmax)
		var rh := rng.randi_range(rmin, rmax)
		var x := rng.randi_range(2, w - rw - 3)
		var y := rng.randi_range(2, h - rh - 3)
		var ok := true
		for r in rooms:
			if _overlap(x - 1, y - 1, rw + 2, rh + 2, r):
				ok = false
				break
		if not ok:
			continue
		var room := {"x": x, "y": y, "w": rw, "h": rh, "kind": "normal"}
		rooms.append(room)
		_carve_room(grid, w, h, room)
	if rooms.size() < 6:
		return {"ok": false, "rooms": rooms}
	_connect_mst(rng, grid, w, h, rooms)
	_extra_loops(rng, grid, w, h, rooms, loops)
	_assign_kinds(rng, rooms, bal)
	var spawn_r: Dictionary = _find_kind(rooms, "spawn")
	var boss_r: Dictionary = _find_kind(rooms, "boss")
	if spawn_r.is_empty() or boss_r.is_empty():
		return {"ok": false, "rooms": rooms}
	var spawn := _center(spawn_r)
	var openings: Array = boss_openings(grid, w, h, boss_r)
	var door := _boss_door_cell(grid, w, h, boss_r, spawn)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [make_opening(_guess_side(boss_r, door), [door])]
	if openings.is_empty() or door == Vector2i(-1, -1):
		if openings.is_empty():
			return {"ok": false, "rooms": rooms}
		door = openings[0]["cells"][0]
	var stairs := _far_cell(boss_r, door)
	var crystal := spawn
	var boss_pos := _center(boss_r)
	return {
		"ok": true,
		"grid": grid,
		"w": w,
		"h": h,
		"rooms": rooms,
		"spawn": spawn,
		"crystal": crystal,
		"stairs": stairs,
		"door": door,
		"openings": openings,
		"boss": boss_pos,
		"bases": _kind_centers(rooms, "base"),
		"safe": _kind_centers(rooms, "clerk") + _kind_centers(rooms, "shop") + _kind_centers(rooms, "puzzle"),
	}


static func _overlap(x: int, y: int, bw: int, bh: int, r: Dictionary) -> bool:
	return not (x + bw <= r.x or r.x + r.w <= x or y + bh <= r.y or r.y + r.h <= y)


static func _carve_room(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> void:
	for yy in range(r.y, r.y + r.h):
		for xx in range(r.x, r.x + r.w):
			if xx <= 0 or yy <= 0 or xx >= w - 1 or xx >= h - 1:
				continue
			grid[idx(xx, yy, w)] = FLOOR


static func _center(r: Dictionary) -> Vector2i:
	return Vector2i(r.x + int(r.w / 2), r.y + int(r.h / 2))


static func _dist(a: Dictionary, b: Dictionary) -> int:
	var ca := _center(a)
	var cb := _center(b)
	return absi(ca.x - cb.x) + absi(ca.y - cb.y)


static func _connect_mst(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array) -> void:
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
				var d := _dist(rooms[i], rooms[j]) + rng.randi_range(0, 2)
				if d < best_d:
					best_d = d
					best_a = i
					best_b = j
		if best_a < 0:
			break
		used[best_b] = 1
		_carve_corridor(grid, w, h, _center(rooms[best_a]), _center(rooms[best_b]))


static func _extra_loops(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, extra: int) -> void:
	var edges: Array = []
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			edges.append({"a": i, "b": j, "d": _dist(rooms[i], rooms[j])})
	edges.sort_custom(func(p, q): return p.d < q.d)
	var added := 0
	for e in edges:
		if added >= extra:
			break
		if rng.randf() > 0.45:
			continue
		_carve_corridor(grid, w, h, _center(rooms[e.a]), _center(rooms[e.b]))
		added += 1


static func _carve_corridor(grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		x += 1 if b.x > x else -1
		_dig(grid, w, h, x, y)
		_dig(grid, w, h, x, y - 1)
	while y != b.y:
		y += 1 if b.y > y else -1
		_dig(grid, w, h, x, y)
		_dig(grid, w, h, x - 1, y)


static func _dig(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= w - 1 or y >= h - 1:
		return
	grid[idx(x, y, w)] = FLOOR


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


static func _assign_kinds(rng: RandomNumberGenerator, rooms: Array, bal: Object) -> void:
	var order: Array = rooms.duplicate()
	order.sort_custom(func(a, b): return a.w * a.h > b.w * b.h)
	rooms[0].kind = "spawn"
	var far_i := 0
	var far_d := -1
	var sc := _center(rooms[0])
	for i in rooms.size():
		var c: Vector2i = _center(rooms[i])
		var d := absi(c.x - sc.x) + absi(c.y - sc.y)
		if d > far_d:
			far_d = d
			far_i = i
	rooms[far_i].kind = "boss"
	var base_set := false
	for r in rooms:
		if r.kind != "normal":
			continue
		if not base_set:
			r.kind = "base"
			base_set = true
	var clerks := 0
	var max_clerks := maxi(1, mini(3, int(bal.get("max_clerks"))))
	for r in rooms:
		if r.kind != "normal":
			continue
		if clerks == 0:
			r.kind = "clerk"
			r.role = "gather"
			clerks += 1
		elif clerks == 1 and clerks < max_clerks:
			r.kind = "clerk"
			r.role = "misc"
			clerks += 1
	for r in rooms:
		if r.kind != "normal":
			continue
		if clerks < max_clerks and rng.randf() < 0.4:
			r.kind = "clerk"
			r.role = "patty"
			clerks += 1
			break
	if _find_kind(rooms, "shop").is_empty() and rng.randf() < float(bal.get("ghost_shop_chance")):
		for r in rooms:
			if r.kind == "normal":
				r.kind = "shop"
				break
	if _find_kind(rooms, "puzzle").is_empty():
		for r in rooms:
			if r.kind == "normal":
				r.kind = "puzzle"
				break


static func _find_kind(rooms: Array, kind: String) -> Dictionary:
	for r in rooms:
		if r.kind == kind:
			return r
	return {}


static func _kind_centers(rooms: Array, kind: String) -> Array:
	var out: Array = []
	for r in rooms:
		if r.kind == kind:
			out.append(_center(r))
	return out


static func _ri(r: Dictionary, k: String) -> int:
	return int(r[k])


static func _boss_door_cell(grid: PackedByteArray, w: int, h: int, boss: Dictionary, spawn: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	var bx := _ri(boss, "x")
	var by := _ri(boss, "y")
	var bw := _ri(boss, "w")
	var bh := _ri(boss, "h")
	for y in range(by, by + bh):
		for x in range(bx, bx + bw):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			var edge: bool = x == bx or y == by or x == bx + bw - 1 or y == by + bh - 1
			if not edge:
				continue
			var outside := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
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
	var best := _center(room)
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
	return kind == "clerk" or kind == "shop" or kind == "puzzle" or kind == "spawn"


static func _fallback(floor_n: int, w: int, h: int) -> Dictionary:
	w = maxi(28, w)
	h = maxi(28, h)
	var grid := PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = [
		{"x": 3, "y": 3, "w": 8, "h": 8, "kind": "spawn"},
		{"x": 16, "y": 4, "w": 7, "h": 7, "kind": "base"},
		{"x": 4, "y": 16, "w": 7, "h": 7, "kind": "clerk", "role": "gather"},
		{"x": 17, "y": 16, "w": 8, "h": 8, "kind": "boss"},
	]
	for r in rooms:
		_carve_room(grid, w, h, r)
	_carve_corridor(grid, w, h, _center(rooms[0]), _center(rooms[1]))
	_carve_corridor(grid, w, h, _center(rooms[0]), _center(rooms[2]))
	_carve_corridor(grid, w, h, _center(rooms[1]), _center(rooms[3]))
	var boss_r: Dictionary = rooms[3]
	var spawn := _center(rooms[0])
	var door := _boss_door_cell(grid, w, h, boss_r, spawn)
	if door == Vector2i(-1, -1):
		door = Vector2i(boss_r.x, _center(boss_r).y)
		_dig(grid, w, h, door.x - 1, door.y)
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
		"boss": _center(boss_r),
		"bases": [_center(rooms[1])],
		"safe": [_center(rooms[2])],
		"floor": floor_n,
		"cycle": cycle_of(floor_n),
		"boss_title": boss_title(floor_n),
		"gate_master": is_gate_master(floor_n),
	}