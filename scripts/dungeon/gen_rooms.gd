extends Object

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen_carve.gd")


static func idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func min_boss_sep(w: int, h: int) -> int:
	return maxi(16, int(maxf(w, h) * 0.5))


static func find_kind(rooms: Array, kind: String) -> Dictionary:
	for r in rooms:
		if r.kind == kind:
			return r
	return {}


static func kind_centers(rooms: Array, kind: String) -> Array:
	var out: Array = []
	for r in rooms:
		if r.kind == kind:
			out.append(Carve.center(r))
	return out


static func _floor_nbs(grid: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var n := 0
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in nbs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
			continue
		if grid[idx(nx, ny, w)] == FLOOR:
			n += 1
	return n


static func _in_room(r: Dictionary, c: Vector2i) -> bool:
	return c.x >= int(r.x) and c.y >= int(r.y) and c.x < int(r.x) + int(r.w) and c.y < int(r.y) + int(r.h)


static func _room_exits(grid: PackedByteArray, w: int, h: int, r: Dictionary) -> int:
	var seen := {}
	var nbs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for yy in range(int(r.y), int(r.y) + int(r.h)):
		for xx in range(int(r.x), int(r.x) + int(r.w)):
			for d in nbs:
				var nx: int = xx + d.x
				var ny: int = yy + d.y
				if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
					continue
				if grid[idx(nx, ny, w)] != FLOOR:
					continue
				var c := Vector2i(nx, ny)
				if _in_room(r, c) or seen.has(c):
					continue
				seen[c] = true
	return seen.size()


static func mark_ambushes(grid: PackedByteArray, w: int, h: int, rooms: Array, bal: Object = null) -> Array:
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
			if _floor_nbs(grid, w, h, x, y) >= 2:
				halls.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 73856093 + h * 19349663 + halls.size()
	shuffle_i(rng, halls)
	var spacing := 10
	var cap := 40
	if bal:
		spacing = maxi(4, int(bal.get("ambush_spacing")))
		cap = maxi(4, int(bal.get("ambush_cap")))
	var out: Array = []
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


static func mark_deadends(grid: PackedByteArray, w: int, h: int, rooms: Array) -> Array:
	var out: Array = []
	for r in rooms:
		var kind := str(r.get("kind", "normal"))
		if kind == "spawn" or kind == "boss":
			continue
		if _room_exits(grid, w, h, r) <= 1:
			out.append(Carve.center(r))
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[idx(x, y, w)] != FLOOR:
				continue
			if _floor_nbs(grid, w, h, x, y) != 1:
				continue
			var c := Vector2i(x, y)
			var inside := false
			for r in rooms:
				if _in_room(r, c):
					inside = true
					break
			if inside:
				continue
			out.append(c)
	var cleaned: Array = []
	for c in out:
		var ok := true
		for p in cleaned:
			var q: Vector2i = p
			if absi(q.x - c.x) + absi(q.y - c.y) < 8:
				ok = false
				break
		if ok:
			cleaned.append(c)
	return cleaned


static func bfs(grid: PackedByteArray, w: int, h: int, start: Vector2i) -> PackedInt32Array:
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


static func cell_dist(dist: PackedInt32Array, w: int, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0:
		return -1
	var i := idx(c.x, c.y, w)
	if i < 0 or i >= dist.size():
		return -1
	return dist[i]


static func shuffle_i(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in arr.size():
		var j := rng.randi_range(i, arr.size() - 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func assign_extract_gates(rooms: Array, rng: RandomNumberGenerator, bal: Object) -> void:
	var want := maxi(1, mini(3, int(bal.get("max_clerks"))))
	var spawn: Vector2i = Vector2i.ZERO
	var sr: Dictionary = find_kind(rooms, "spawn")
	if not sr.is_empty():
		spawn = Carve.center(sr)
	var cands: Array = []
	for i in rooms.size():
		if str(rooms[i].kind) != "normal":
			continue
		if int(rooms[i].w) < 5 or int(rooms[i].h) < 4 or int(rooms[i].y) < 1:
			continue
		cands.append(i)
	shuffle_i(rng, cands)
	var picked: Array = []
	var min_sep := 28
	for _n in want:
		var best := -1
		var best_s := -1.0
		for i in cands:
			if picked.has(i):
				continue
			var c: Vector2i = Carve.center(rooms[i])
			var s := float(absi(c.x - spawn.x) + absi(c.y - spawn.y))
			var ok := true
			for j in picked:
				var d: Vector2i = Carve.center(rooms[j])
				var sep := absi(c.x - d.x) + absi(c.y - d.y)
				if sep < min_sep:
					ok = false
					break
				s = minf(s, float(sep))
			if ok and s > best_s:
				best_s = s
				best = i
		if best < 0:
			for i in cands:
				if not picked.has(i):
					best = i
					break
		if best < 0:
			break
		picked.append(best)
		rooms[best].kind = "extract_gate"
	if picked.is_empty():
		for r in rooms:
			if str(r.kind) == "normal" and int(r.w) >= 5 and int(r.y) >= 1:
				r.kind = "extract_gate"
				break


static func assign_kinds(rng: RandomNumberGenerator, grid: PackedByteArray, w: int, h: int, rooms: Array, bal: Object) -> void:
	var spawn_i := 0
	var best_s := 1 << 30
	for i in rooms.size():
		var c: Vector2i = Carve.center(rooms[i])
		var s := c.x + c.y
		if s < best_s:
			best_s = s
			spawn_i = i
	rooms[spawn_i].kind = "spawn"
	var dist := bfs(grid, w, h, Carve.center(rooms[spawn_i]))
	var max_d := 0
	for i in rooms.size():
		if i == spawn_i:
			continue
		max_d = maxi(max_d, cell_dist(dist, w, Carve.center(rooms[i])))
	var need := maxi(min_boss_sep(w, h), int(float(maxi(1, max_d)) * 0.55))
	var candidates: Array[int] = []
	var far_i := spawn_i
	var far_d := -1
	for i in rooms.size():
		if i == spawn_i:
			continue
		var d := cell_dist(dist, w, Carve.center(rooms[i]))
		var md := Carve.dist(rooms[i], rooms[spawn_i])
		if d > far_d:
			far_d = d
			far_i = i
		if d >= need and md >= min_boss_sep(w, h):
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
	shuffle_i(rng, vein_types)
	var vein_idxs: Array = []
	for i in rooms.size():
		if str(rooms[i].kind) != "normal":
			continue
		if int(rooms[i].w) * int(rooms[i].h) < 16:
			continue
		vein_idxs.append(i)
	shuffle_i(rng, vein_idxs)
	var veins := 0
	for i in vein_idxs:
		if veins >= vein_n:
			break
		rooms[i].kind = "vein"
		rooms[i].vein = str(vein_types[veins % vein_types.size()])
		veins += 1
	assign_extract_gates(rooms, rng, bal)
	if find_kind(rooms, "shop").is_empty() and rng.randf() < float(bal.get("ghost_shop_chance")):
		for r in rooms:
			if str(r.kind) == "normal":
				r.kind = "shop"
				break
	if find_kind(rooms, "puzzle").is_empty():
		for r in rooms:
			if str(r.kind) == "normal":
				r.kind = "puzzle"
				break


static func fallback(floor_n: int, w: int, h: int, cycle_of: Callable, boss_title: Callable, is_gate_master: Callable, door_fn: Callable, openings_fn: Callable, far_fn: Callable, guess_fn: Callable, make_fn: Callable) -> Dictionary:
	w = maxi(28, w)
	h = maxi(28, h)
	var grid := PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = [
		{"x": 3, "y": 3, "w": 8, "h": 8, "kind": "spawn"},
		{"x": mini(w - 12, maxi(12, int(w * 0.35))), "y": 4, "w": 7, "h": 7, "kind": "base"},
		{"x": 4, "y": mini(h - 12, maxi(12, int(h * 0.35))), "w": 7, "h": 7, "kind": "extract_gate"},
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
	var door: Vector2i = door_fn.call(grid, w, h, boss_r, spawn)
	if door == Vector2i(-1, -1):
		door = Vector2i(boss_r.x, Carve.center(boss_r).y)
		Carve.dig(grid, w, h, door.x - 1, door.y)
	var openings: Array = openings_fn.call(grid, w, h, boss_r)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [make_fn.call(guess_fn.call(boss_r, door), [door])]
	return {
		"ok": true,
		"grid": grid,
		"w": w,
		"h": h,
		"rooms": rooms,
		"spawn": spawn,
		"crystal": spawn,
		"stairs": far_fn.call(boss_r, door),
		"door": door,
		"openings": openings,
		"boss": Carve.center(boss_r),
		"ambushes": [],
		"deadends": [],
		"bases": [Carve.center(rooms[1])],
		"safe": [Carve.center(rooms[2])],
		"floor": floor_n,
		"cycle": cycle_of.call(floor_n),
		"boss_title": boss_title.call(floor_n),
		"gate_master": is_gate_master.call(floor_n),
	}
