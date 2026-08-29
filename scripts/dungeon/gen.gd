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
	_place_spread_rooms(rng, grid, w, h, rooms, pack, rmin, rmax)
	if rooms.size() < 6:
		return {"ok": false, "rooms": rooms}
	_connect_winding_tree(rng, grid, w, h, rooms)
	_extra_winding_loops(rng, grid, w, h, rooms, mini(2, loops))
	_carve_deadend_spurs(rng, grid, w, h, rooms, mini(6, maxi(3, pack / 10)))
	_assign_kinds(rng, grid, w, h, rooms, bal)
	var spawn_r: Dictionary = _find_kind(rooms, "spawn")
	var boss_r: Dictionary = _find_kind(rooms, "boss")
	if spawn_r.is_empty() or boss_r.is_empty():
		return {"ok": false, "rooms": rooms}
	if _dist(spawn_r, boss_r) < _min_boss_sep(w, h):
		return {"ok": false, "rooms": rooms}
	var ambushes: Array = _mark_ambushes(grid, w, h, rooms)
	var spawn := _center(spawn_r)
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
		"boss": _center(boss_r),
		"ambushes": ambushes,
		"bases": _kind_centers(rooms, "base"),
		"safe": _kind_centers(rooms, "clerk") + _kind_centers(rooms, "shop") + _kind_centers(rooms, "puzzle") + _kind_centers(rooms, "stash") + _kind_centers(rooms, "vein"),
	}


static func _min_boss_sep(w: int, h: int) -> int:
	return maxi(16, int(maxf(w, h) * 0.5))


static func _can_place(rooms: Array, x: int, y: int, rw: int, rh: int) -> bool:
	for r in rooms:
		if _overlap(x - 1, y - 1, rw + 2, rh + 2, r):
			return false
	return true


static func _place_spread_rooms(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, want: int, rmin: int, rmax: int) -> void:
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
			if not _can_place(rooms, x, y, rw, rh):
				continue
			var room := {"x": x, "y": y, "w": rw, "h": rh, "kind": "normal"}
			rooms.append(room)
			_carve_room(grid, w, h, room)
	for _i in want * 24:
		if rooms.size() >= want:
			return
		var rw2 := rng.randi_range(rmin, rmax)
		var rh2 := rng.randi_range(rmin, rmax)
		var x2 := rng.randi_range(2, maxi(2, w - rw2 - 3))
		var y2 := rng.randi_range(2, maxi(2, h - rh2 - 3))
		if not _can_place(rooms, x2, y2, rw2, rh2):
			continue
		var extra := {"x": x2, "y": y2, "w": rw2, "h": rh2, "kind": "normal"}
		rooms.append(extra)
		_carve_room(grid, w, h, extra)


static func _connect_winding_tree(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array) -> void:
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
				var d := _dist(rooms[i], rooms[j]) + rng.randi_range(0, 8)
				if d < best_d:
					best_d = d
					best_a = i
					best_b = j
		if best_a < 0:
			break
		used[best_b] = 1
		_carve_winding(rng, grid, w, h, _center(rooms[best_a]), _center(rooms[best_b]))


static func _extra_winding_loops(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, extra: int) -> void:
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
		if _dist(rooms[a], rooms[b]) < 18:
			continue
		_carve_winding(rng, grid, w, h, _center(rooms[a]), _center(rooms[b]))
		added += 1


static func _carve_deadend_spurs(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, count: int) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var added := 0
	var guard := 0
	while added < count and guard < count * 8:
		guard += 1
		if rooms.is_empty():
			return
		var src: Dictionary = rooms[rng.randi() % rooms.size()]
		var start := _center(src)
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
			_dig_wide(grid, w, h, x, y)
			last = Vector2i(x, y)
		if _can_place(rooms, last.x, last.y, 3, 3):
			var kind := "normal"
			if rng.randf() < 0.3:
				kind = "stash"
			elif rng.randf() < 0.18:
				kind = "clerk"
			var spur := {"x": last.x, "y": last.y, "w": 3, "h": 3, "kind": kind}
			if kind == "clerk":
				spur["role"] = "patty"
			rooms.append(spur)
			_carve_room(grid, w, h, spur)
		added += 1


static func _dig_wide(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> void:
	_dig(grid, w, h, x, y)
	_dig(grid, w, h, x + 1, y)
	_dig(grid, w, h, x, y + 1)


static func _carve_winding(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	var guard := 0
	var limit := absi(a.x - b.x) + absi(a.y - b.y) + 36
	_dig_wide(grid, w, h, x, y)
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
		_dig_wide(grid, w, h, x, y)
	_dig_wide(grid, w, h, b.x, b.y)


static func _in_any_room(c: Vector2i, rooms: Array) -> bool:
	for r in rooms:
		if c.x >= int(r.x) and c.y >= int(r.y) and c.x < int(r.x) + int(r.w) and c.y < int(r.y) + int(r.h):
			return true
	return false


static func _mark_ambushes(grid: PackedByteArray, w: int, h: int, rooms: Array) -> Array:
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
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
			var n := 0
			for d in nbs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
					continue
				if grid[idx(nx, ny, w)] == FLOOR:
					n += 1
			if n >= 2:
				halls.append(c)
	var out: Array = []
	var spacing := 16
	var cap := 12
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


static func _bfs(grid: PackedByteArray, w: int, h: int, start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	if start.x < 1 or start.y < 1 or start.x >= w - 1 or start.y >= h - 1:
		return dist
	if grid[idx(start.x, start.y, w)] != FLOOR:
		return dist
	var q: Array[Vector2i] = [start]
	dist[idx(start.x, start.y, w)] = 0
	var qi := 0
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		var d := dist[idx(c.x, c.y, w)]
		for n in nbs:
			var nx: int = c.x + n.x
			var ny: int = c.y + n.y
			if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
				continue
			var i := idx(nx, ny, w)
			if grid[i] != FLOOR or dist[i] >= 0:
				continue
			dist[i] = d + 1
			q.append(Vector2i(nx, ny))
	return dist


static func _cell_dist(dist: PackedInt32Array, w: int, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0:
		return -1
	var i := idx(c.x, c.y, w)
	if i < 0 or i >= dist.size():
		return -1
	return dist[i]


static func _shuffle_i(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in arr.size():
		var j := rng.randi_range(i, arr.size() - 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _assign_kinds(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, bal: Object) -> void:
	var spawn_i := 0
	var best_s := 1 << 30
	for i in rooms.size():
		var c: Vector2i = _center(rooms[i])
		var s := c.x + c.y
		if s < best_s:
			best_s = s
			spawn_i = i
	rooms[spawn_i].kind = "spawn"
	var dist := _bfs(grid, w, h, _center(rooms[spawn_i]))
	var max_d := 0
	for i in rooms.size():
		if i == spawn_i:
			continue
		max_d = maxi(max_d, _cell_dist(dist, w, _center(rooms[i])))
	var need := maxi(_min_boss_sep(w, h), int(float(maxi(1, max_d)) * 0.55))
	var candidates: Array[int] = []
	var far_i := spawn_i
	var far_d := -1
	for i in rooms.size():
		if i == spawn_i:
			continue
		var d := _cell_dist(dist, w, _center(rooms[i]))
		var md := _dist(rooms[i], rooms[spawn_i])
		if d > far_d:
			far_d = d
			far_i = i
		if d >= need and md >= _min_boss_sep(w, h):
			candidates.append(i)
	var boss_i := far_i
	if not candidates.is_empty():
		boss_i = candidates[rng.randi() % candidates.size()]
	rooms[boss_i].kind = "boss"
	var base_set := false
	for r in rooms:
		if str(r.kind) != "normal":
			continue
		if not base_set:
			r.kind = "base"
			base_set = true
	var vein_n := mini(3, maxi(2, int(rooms.size() / 16)))
	var vein_types: Array = ["mine", "wood", "break"]
	_shuffle_i(rng, vein_types)
	var vein_idxs: Array = []
	for i in rooms.size():
		if str(rooms[i].kind) != "normal":
			continue
		if int(rooms[i].w) * int(rooms[i].h) < 16:
			continue
		vein_idxs.append(i)
	_shuffle_i(rng, vein_idxs)
	var veins := 0
	for i in vein_idxs:
		if veins >= vein_n:
			break
		rooms[i].kind = "vein"
		rooms[i].vein = str(vein_types[veins % vein_types.size()])
		veins += 1
	var clerks := 0
	var max_clerks := maxi(1, mini(3, int(bal.get("max_clerks"))))
	for r in rooms:
		if str(r.get("kind", "")) == "clerk":
			clerks += 1
	var by_area: Array = []
	for i in rooms.size():
		if str(rooms[i].kind) == "normal":
			by_area.append(i)
	by_area.sort_custom(func(a, b): return int(rooms[a].w) * int(rooms[a].h) < int(rooms[b].w) * int(rooms[b].h))
	for i in by_area:
		if clerks >= max_clerks:
			break
		if int(rooms[i].w) * int(rooms[i].h) > 16:
			continue
		if clerks == 0:
			rooms[i].kind = "clerk"
			rooms[i].role = "gather"
			clerks += 1
		elif clerks == 1:
			rooms[i].kind = "clerk"
			rooms[i].role = "misc"
			clerks += 1
		elif rng.randf() < 0.4:
			rooms[i].kind = "clerk"
			rooms[i].role = "patty"
			clerks += 1
	if clerks == 0:
		for r in rooms:
			if str(r.kind) == "normal":
				r.kind = "clerk"
				r.role = "gather"
				break
	if _find_kind(rooms, "shop").is_empty() and rng.randf() < float(bal.get("ghost_shop_chance")):
		for r in rooms:
			if str(r.kind) == "normal":
				r.kind = "shop"
				break
	if _find_kind(rooms, "puzzle").is_empty():
		for r in rooms:
			if str(r.kind) == "normal":
				r.kind = "puzzle"
				break


static func _overlap(x: int, y: int, bw: int, bh: int, r: Dictionary) -> bool:
	return not (x + bw <= r.x or r.x + r.w <= x or y + bh <= r.y or r.y + r.h <= y)


static func _carve_room(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> void:
	for yy in range(r.y, r.y + r.h):
		for xx in range(r.x, r.x + r.w):
			if xx <= 0 or yy <= 0 or xx >= w - 1 or yy >= h - 1:
				continue
			grid[idx(xx, yy, w)] = FLOOR


static func _center(r: Dictionary) -> Vector2i:
	return Vector2i(r.x + int(r.w / 2), r.y + int(r.h / 2))


static func _dist(a: Dictionary, b: Dictionary) -> int:
	var ca := _center(a)
	var cb := _center(b)
	return absi(ca.x - cb.x) + absi(ca.y - cb.y)


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
		_carve_room(grid, w, h, r)
	var rng := RandomNumberGenerator.new()
	_carve_winding(rng, grid, w, h, _center(rooms[0]), _center(rooms[1]))
	_carve_winding(rng, grid, w, h, _center(rooms[0]), _center(rooms[2]))
	_carve_winding(rng, grid, w, h, _center(rooms[1]), _center(rooms[3]))
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
		"ambushes": [],
		"bases": [_center(rooms[1])],
		"safe": [_center(rooms[2])],
		"floor": floor_n,
		"cycle": cycle_of(floor_n),
		"boss_title": boss_title(floor_n),
		"gate_master": is_gate_master(floor_n),
	}
