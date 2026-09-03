extends Object

const WALL := 0
const FLOOR := 1
const Carve := preload("res://scripts/dungeon/gen_carve.gd")
const Rooms := preload("res://scripts/dungeon/gen_rooms.gd")
const Doors := preload("res://scripts/dungeon/gen_doors.gd")


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
	return Doors.idx(x, y, w)


static func generate(floor_n: int, seed: int, bal: Object) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed) * 10007 + floor_n * 9176
	var w: int = maxi(24, int(bal.get("gen_w")))
	var h: int = maxi(24, int(bal.get("gen_h")))
	var want: int = maxi(6, int(bal.get("gen_rooms")))
	var rmin: int = maxi(4, int(bal.get("gen_room_min")))
	var rmax: int = maxi(rmin + 1, int(bal.get("gen_room_max")))
	var loops: int = maxi(0, int(bal.get("gen_extra_loops")))
	for _try: int in 24:
		var data: Dictionary = _try_gen(rng, w, h, want, rmin, rmax, loops, bal)
		if data.get("ok", false):
			data["floor"] = floor_n
			data["cycle"] = cycle_of(floor_n)
			data["boss_title"] = boss_title(floor_n)
			data["gate_master"] = is_gate_master(floor_n)
			return data
	return _fallback(floor_n, w, h)


static func _try_gen(rng: RandomNumberGenerator, w: int, h: int, want: int, rmin: int, rmax: int, loops: int, bal: Object) -> Dictionary:
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = []
	var pack: int = clampi(want, 28, 42)
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
	var spawn: Vector2i = Carve.center(spawn_r)
	var openings: Array = Doors.boss_openings(grid, w, h, boss_r)
	var door: Vector2i = Doors.boss_door_cell(grid, w, h, boss_r, spawn)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [Doors.make_opening(Doors.guess_side(boss_r, door), [door])]
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
		"stairs": Doors.far_cell(boss_r, door),
		"door": door,
		"openings": openings,
		"boss": Carve.center(boss_r),
		"ambushes": ambushes,
		"bases": Rooms.kind_centers(rooms, "base"),
		"safe": Rooms.kind_centers(rooms, "extract_gate") + Rooms.kind_centers(rooms, "shop") + Rooms.kind_centers(rooms, "puzzle") + Rooms.kind_centers(rooms, "stash") + Rooms.kind_centers(rooms, "vein"),
	}


static func _ri(r: Dictionary, k: String) -> int:
	return Doors._ri(r, k)


static func _outside_floor(grid: PackedByteArray, w: int, h: int, boss: Dictionary, x: int, y: int) -> bool:
	return Doors.outside_floor(grid, w, h, boss, x, y)


static func _guess_side(boss: Dictionary, cell: Vector2i) -> String:
	return Doors.guess_side(boss, cell)


static func make_opening(side: String, cells: Array) -> Dictionary:
	return Doors.make_opening(side, cells)


static func boss_openings(grid: PackedByteArray, w: int, h: int, boss: Dictionary) -> Array:
	return Doors.boss_openings(grid, w, h, boss)


static func _side_runs(side: String, cells: Array) -> Array:
	return Doors._side_runs(side, cells)


static func _boss_door_cell(grid: PackedByteArray, w: int, h: int, boss: Dictionary, spawn: Vector2i) -> Vector2i:
	return Doors.boss_door_cell(grid, w, h, boss, spawn)


static func _far_cell(room: Dictionary, from: Vector2i) -> Vector2i:
	return Doors.far_cell(room, from)


static func is_safe_kind(kind: String) -> bool:
	return kind == "extract_gate" or kind == "shop" or kind == "puzzle" or kind == "spawn" or kind == "stash" or kind == "vein"


static func _fallback(floor_n: int, w: int, h: int) -> Dictionary:
	w = maxi(28, w)
	h = maxi(28, h)
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(w * h)
	grid.fill(WALL)
	var rooms: Array = [
		{"x": 3, "y": 3, "w": 8, "h": 8, "kind": "spawn"},
		{"x": mini(w - 12, maxi(12, int(w * 0.35))), "y": 4, "w": 7, "h": 7, "kind": "base"},
		{"x": 4, "y": mini(h - 12, maxi(12, int(h * 0.35))), "w": 7, "h": 7, "kind": "extract_gate"},
		{"x": maxi(12, w - 11), "y": maxi(12, h - 11), "w": 8, "h": 8, "kind": "boss"},
	]
	for r: Variant in rooms:
		Carve.carve_room(grid, w, h, r)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[0]), Carve.center(rooms[1]))
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[0]), Carve.center(rooms[2]))
	Carve.carve_winding(rng, grid, w, h, Carve.center(rooms[1]), Carve.center(rooms[3]))
	var boss_r: Dictionary = rooms[3]
	var spawn: Vector2i = Carve.center(rooms[0])
	var door: Vector2i = Doors.boss_door_cell(grid, w, h, boss_r, spawn)
	if door == Vector2i(-1, -1):
		door = Vector2i(boss_r.x, Carve.center(boss_r).y)
		Carve.dig(grid, w, h, door.x - 1, door.y)
	var openings: Array = Doors.boss_openings(grid, w, h, boss_r)
	if openings.is_empty() and door != Vector2i(-1, -1):
		openings = [Doors.make_opening(Doors.guess_side(boss_r, door), [door])]
	return {
		"ok": true,
		"grid": grid,
		"w": w,
		"h": h,
		"rooms": rooms,
		"spawn": spawn,
		"crystal": spawn,
		"stairs": Doors.far_cell(boss_r, door),
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
