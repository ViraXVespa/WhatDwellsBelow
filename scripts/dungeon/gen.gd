class_name DungeonGen
extends Object

const W := 88
const H := 64
const WALL := 0
const FLOOR := 1

const GATHER_TYPES := ["miner", "lumberjack", "alchemist", "stonemason", "fishmonger"]
const MISC_TYPES := ["gopher", "runner"]
const SLICE_MAX_FLOOR := 6


static func is_boss_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number % 3 == 0


static func generate(floor_number: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grid := PackedByteArray()
	grid.resize(W * H)
	grid.fill(WALL)
	var rooms: Array[Rect2i] = []
	for _i in 90:
		var rw := rng.randi_range(6, 12)
		var rh := rng.randi_range(5, 10)
		var rx := rng.randi_range(2, W - rw - 3)
		var ry := rng.randi_range(2, H - rh - 3)
		var r := Rect2i(rx, ry, rw, rh)
		var ok := true
		for other: Rect2i in rooms:
			if r.grow(2).intersects(other):
				ok = false
				break
		if ok:
			rooms.append(r)
			_carve_room(grid, r)
		if rooms.size() >= 16:
			break
	if rooms.size() < 10:
		return generate(floor_number, seed_value + 17)
	_connect_rooms(grid, rooms, rng)
	var entrance: Rect2i = rooms[0]
	var stairs_room: Rect2i = rooms[rooms.size() - 1]
	var best_d := 0
	for r: Rect2i in rooms:
		var d: int = _center(r).distance_squared_to(_center(entrance))
		if d > best_d:
			best_d = d
			stairs_room = r
	var gather: String = "miner"
	if floor_number != 1:
		gather = String(GATHER_TYPES[rng.randi_range(0, GATHER_TYPES.size() - 1)])
	var misc: String = String(MISC_TYPES[rng.randi_range(0, MISC_TYPES.size() - 1)])
	# Crystal sits on the north wall of the start room; player appears one tile south.
	var crystal := Vector2i(entrance.position.x + entrance.size.x / 2, entrance.position.y + 1)
	var spawn := Vector2i(crystal.x, crystal.y + 1)
	_ensure_floor(grid, crystal)
	_ensure_floor(grid, spawn)
	var stairs := _center(stairs_room)
	var hosts: Array[Rect2i] = []
	for r: Rect2i in rooms:
		if r != entrance:
			hosts.append(r)
	hosts.shuffle()
	# Prefer extract off the spawn AND not both sitting on the stairs.
	if hosts.size() >= 2 and hosts[0] == stairs_room:
		var tmp: Rect2i = hosts[0]
		hosts[0] = hosts[1]
		hosts[1] = tmp
	var safe_rooms: Array[Rect2i] = []
	var clerk_a := _hide_clerk(grid, rooms, hosts[0] if hosts.size() > 0 else entrance, rng, safe_rooms)
	var host_b: Rect2i = hosts[1] if hosts.size() > 1 else (hosts[0] if hosts.size() > 0 else entrance)
	var clerk_b := _hide_clerk(grid, rooms, host_b, rng, safe_rooms)
	_ensure_floor(grid, clerk_a)
	_ensure_floor(grid, clerk_b)
	var loot: Array = []
	var pocket_hosts: Array[Rect2i] = []
	for r: Rect2i in rooms:
		if r != entrance and r != stairs_room and not _is_safe_room(r, safe_rooms):
			pocket_hosts.append(r)
	pocket_hosts.shuffle()
	for host: Rect2i in pocket_hosts:
		if loot.size() >= 7:
			break
		var pocket := _try_alcove(grid, rooms, host, rng, rng.randi_range(4, 7))
		if pocket.size.x <= 0:
			continue
		rooms.append(pocket)
		safe_rooms.append(pocket)
		loot.append(_center(pocket))
	var mines: Array = []
	var mine_set := {}
	var enemies: Array = []
	var roles := ["bruiser", "ranged", "tank"]
	var boss_floor := is_boss_floor(floor_number)
	for r: Rect2i in rooms:
		if r == entrance or _is_safe_room(r, safe_rooms):
			continue
		if boss_floor and r == stairs_room:
			continue
		var edges := _wall_edge_floors(grid, r)
		edges.shuffle()
		var vein_n := 1 + (1 if rng.randf() < 0.45 else 0)
		for i in mini(vein_n, edges.size()):
			var mp: Vector2i = edges[i]
			if mp == stairs or mp == crystal or mp == spawn:
				continue
			mines.append(mp)
			mine_set[mp] = true
		var c := _center(r)
		var n := rng.randi_range(1, 2) + mini(floor_number - 1, 1)
		var spawned := 0
		var guard := 0
		while spawned < n and guard < 20:
			guard += 1
			var ep := Vector2i(c.x + rng.randi_range(-2, 2), c.y + rng.randi_range(-2, 2))
			if mine_set.has(ep):
				continue
			_ensure_floor(grid, ep)
			enemies.append({"pos": ep, "role": roles[rng.randi_range(0, 2)]})
			spawned += 1
	var occupied := {}
	occupied[crystal] = true
	occupied[spawn] = true
	occupied[stairs] = true
	occupied[clerk_a] = true
	occupied[clerk_b] = true
	for mp in mines:
		occupied[mp] = true
	for e in enemies:
		occupied[e.pos] = true
	for lp in loot:
		occupied[lp] = true
	var breakables: Array = []
	for r: Rect2i in rooms:
		if r == entrance or _is_safe_room(r, safe_rooms):
			continue
		var n := rng.randi_range(1, 3)
		var guard := 0
		var placed := 0
		while placed < n and guard < 24:
			guard += 1
			var bp := Vector2i(
				r.position.x + rng.randi_range(0, maxi(0, r.size.x - 1)),
				r.position.y + rng.randi_range(0, maxi(0, r.size.y - 1))
			)
			if occupied.has(bp) or grid[idx(bp.x, bp.y)] != FLOOR:
				continue
			occupied[bp] = true
			breakables.append({"pos": bp, "kind": "pot" if rng.randf() < 0.6 else "barrel"})
			placed += 1
	return {
		"w": W,
		"h": H,
		"grid": grid,
		"rooms": rooms,
		"crystal": crystal,
		"stairs": stairs,
		"clerk_gather": clerk_a,
		"clerk_misc": clerk_b,
		"gather_type": gather,
		"misc_type": misc,
		"mines": mines,
		"enemies": enemies,
		"loot": loot,
		"breakables": breakables,
		"boss": boss_floor,
		"boss_pos": Vector2i(_center(stairs_room).x, _center(stairs_room).y - 1),
		"spawn": spawn,
	}


static func has_grid_los(grid: PackedByteArray, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if b.x > a.x else -1
	var sy := 1 if b.y > a.y else -1
	var err := dx - dy
	while x != b.x or y != b.y:
		var e2 := err * 2
		var nx := x
		var ny := y
		if e2 > -dy:
			err -= dy
			nx += sx
		if e2 < dx:
			err += dx
			ny += sy
		if nx != x and ny != y:
			if _cell_blocks_los(grid, nx, y) or _cell_blocks_los(grid, x, ny):
				return false
		x = nx
		y = ny
		if x == b.x and y == b.y:
			break
		if _cell_blocks_los(grid, x, y):
			return false
	return true


static func world_has_los(grid: PackedByteArray, from_world: Vector2, to_world: Vector2) -> bool:
	var a := Vector2i(int(from_world.x / 64.0), int(from_world.y / 64.0))
	var b := Vector2i(int(to_world.x / 64.0), int(to_world.y / 64.0))
	return has_grid_los(grid, a, b)


static func _cell_blocks_los(grid: PackedByteArray, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return true
	return grid[idx(x, y)] != FLOOR


static func idx(x: int, y: int) -> int:
	return x + y * W


static func _is_safe_room(r: Rect2i, safe_rooms: Array[Rect2i]) -> bool:
	for s: Rect2i in safe_rooms:
		if s == r:
			return true
	return false


static func _hide_clerk(grid: PackedByteArray, rooms: Array[Rect2i], host: Rect2i, rng: RandomNumberGenerator, safe_rooms: Array[Rect2i]) -> Vector2i:
	var alcove := _try_alcove(grid, rooms, host, rng, 2)
	if alcove.size.x > 0:
		rooms.append(alcove)
		safe_rooms.append(alcove)
		return _center(alcove)
	safe_rooms.append(host)
	var c := _center(host)
	return Vector2i(c.x + rng.randi_range(-1, 1), c.y + rng.randi_range(-1, 1))


static func _connect_rooms(grid: PackedByteArray, rooms: Array[Rect2i], rng: RandomNumberGenerator) -> void:
	var n := rooms.size()
	var parent: Array = []
	for i in n:
		parent.append(i)
	var edges: Array = []
	for i in n:
		for j in range(i + 1, n):
			var d: int = _center(rooms[i]).distance_squared_to(_center(rooms[j]))
			edges.append({"a": i, "b": j, "d": d})
	edges.sort_custom(func(x, y): return int(x.d) < int(y.d))
	var linked := 0
	for e in edges:
		var ia := _uf(parent, int(e.a))
		var ib := _uf(parent, int(e.b))
		if ia == ib:
			continue
		parent[ia] = ib
		_carve_corridor(grid, _center(rooms[int(e.a)]), _center(rooms[int(e.b)]), rng)
		linked += 1
		if linked >= n - 1:
			break
	var loops := 0
	for e in edges:
		if loops >= 4:
			break
		if rng.randf() > 0.14:
			continue
		_carve_corridor(grid, _center(rooms[int(e.a)]), _center(rooms[int(e.b)]), rng)
		loops += 1


static func _uf(parent: Array, i: int) -> int:
	var x := i
	while int(parent[x]) != x:
		parent[x] = parent[parent[x]]
		x = int(parent[x])
	return x


static func _try_alcove(grid: PackedByteArray, rooms: Array[Rect2i], host: Rect2i, rng: RandomNumberGenerator, gap: int = 2) -> Rect2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		var aw := rng.randi_range(4, 5)
		var ah := rng.randi_range(4, 5)
		var rx := host.position.x
		var ry := host.position.y
		if d.x > 0:
			rx = host.end.x + gap
			ry = host.position.y + rng.randi_range(0, maxi(0, host.size.y - ah))
		elif d.x < 0:
			rx = host.position.x - gap - aw
			ry = host.position.y + rng.randi_range(0, maxi(0, host.size.y - ah))
		elif d.y > 0:
			ry = host.end.y + gap
			rx = host.position.x + rng.randi_range(0, maxi(0, host.size.x - aw))
		else:
			ry = host.position.y - gap - ah
			rx = host.position.x + rng.randi_range(0, maxi(0, host.size.x - aw))
		if rx < 2 or ry < 2 or rx + aw >= W - 2 or ry + ah >= H - 2:
			continue
		var alcove := Rect2i(rx, ry, aw, ah)
		var blocked := false
		for other: Rect2i in rooms:
			if alcove.grow(1).intersects(other):
				blocked = true
				break
		if blocked:
			continue
		_carve_room(grid, alcove)
		_carve_corridor(grid, _center(host), _center(alcove), rng)
		return alcove
	return Rect2i()


static func _carve_room(grid: PackedByteArray, r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			grid[idx(x, y)] = FLOOR


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


static func _wall_edge_floors(grid: PackedByteArray, room: Rect2i) -> Array:
	var out: Array = []
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			if grid[idx(x, y)] != FLOOR:
				continue
			var walls: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if grid[idx(nx, ny)] == WALL:
					walls.append(d)
			if walls.size() == 1:
				out.append(Vector2i(x, y))
	return out


static func _ensure_floor(grid: PackedByteArray, p: Vector2i) -> void:
	if p.x > 0 and p.y > 0 and p.x < W - 1 and p.y < H - 1:
		grid[idx(p.x, p.y)] = FLOOR


static func _carve_corridor(grid: PackedByteArray, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var x := a.x
	var y := a.y
	if rng.randf() < 0.5:
		while x != b.x:
			x += 1 if b.x > x else -1
			_paint_wide(grid, x, y)
		while y != b.y:
			y += 1 if b.y > y else -1
			_paint_wide(grid, x, y)
	else:
		while y != b.y:
			y += 1 if b.y > y else -1
			_paint_wide(grid, x, y)
		while x != b.x:
			x += 1 if b.x > x else -1
			_paint_wide(grid, x, y)


static func _paint_wide(grid: PackedByteArray, x: int, y: int) -> void:
	for ox in range(0, 2):
		for oy in range(0, 2):
			var px := x + ox
			var py := y + oy
			if px > 0 and py > 0 and px < W - 1 and py < H - 1:
				grid[idx(px, py)] = FLOOR
