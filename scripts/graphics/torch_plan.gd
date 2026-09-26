extends Object

## One torch per unlit room. Halls only at doorways, junctions, and dead ends.

const Gen := preload("res://scripts/dungeon/gen.gd")
const WallRects := preload("res://scripts/world/wall_rects.gd")

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


static func build(host: Node, props: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if host == null or host.data == null:
		return out
	var grid: PackedByteArray = host.data.grid
	var map_w: int = int(host.data.w)
	var map_h: int = int(host.data.h)
	if map_w < 3 or map_h < 3 or grid.is_empty():
		return out
	var rooms: Array = host.data.get("rooms", [])
	var inside: Dictionary = {}
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var rx: int = int(room["x"])
		var ry: int = int(room["y"])
		var rw: int = int(room["w"])
		var rh: int = int(room["h"])
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				inside[Vector2i(x, y)] = i
	var lit: Dictionary = {}
	for node in props:
		if not is_instance_valid(node):
			continue
		var cell: Vector2i = _prop_cell(node)
		if not inside.has(cell):
			continue
		lit[int(inside[cell])] = true
	var facing: Dictionary = _face_map(grid, map_w, map_h)
	var used: Dictionary = {}
	for i in rooms.size():
		if lit.has(i):
			continue
		var room_s: Dictionary = rooms[i]
		var floor_cell: Vector2i = _room_floor(grid, map_w, map_h, room_s, facing)
		if floor_cell.x < 0:
			continue
		var site: Dictionary = _site(facing, floor_cell)
		if site.is_empty():
			continue
		used[floor_cell] = true
		out.append(site)
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			var cell: Vector2i = Vector2i(x, y)
			if inside.has(cell):
				continue
			if grid[y * map_w + x] != Gen.FLOOR:
				continue
			var deg: int = _degree(grid, map_w, map_h, cell)
			var mouth: bool = _touches_room(inside, cell)
			if deg != 1 and deg < 3 and not mouth:
				continue
			if _taken(used, cell):
				continue
			var hall: Dictionary = _site(facing, cell)
			if hall.is_empty():
				continue
			used[cell] = true
			out.append(hall)
	return out


static func _prop_cell(node: Node) -> Vector2i:
	if str(node.get("kind")) == "crystal":
		var raw: Variant = node.get("crystal_cell")
		if raw is Vector2i:
			return raw
	var p: Vector3 = (node as Node3D).global_position
	return Vector2i(int(round(p.x - 0.5)), int(round(p.z - 0.5)))


static func _face_map(grid: PackedByteArray, map_w: int, map_h: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if grid[y * map_w + x] != Gen.FLOOR:
				cells.append(Vector2i(x, y))
	var runs: Array[Dictionary] = WallRects.faces(grid, map_w, map_h, cells)
	var by_floor: Dictionary = {}
	for run in runs:
		var origin: Vector2i = run["origin"]
		var n: Vector2i = run["normal"]
		var span: Vector2i = run["size"]
		var along: Vector2i = Vector2i(1, 0) if span.x >= span.y else Vector2i(0, 1)
		var length: int = maxi(span.x, span.y)
		for k in length:
			var wall: Vector2i = origin + Vector2i(along.x * k, along.y * k)
			var floor_cell: Vector2i = wall + n
			if by_floor.has(floor_cell):
				continue
			by_floor[floor_cell] = {"wx": wall.x, "wz": wall.y, "nx": n.x, "nz": n.y}
	return by_floor


static func _room_floor(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	room: Dictionary,
	facing: Dictionary
) -> Vector2i:
	var rx: int = int(room["x"])
	var ry: int = int(room["y"])
	var rw: int = int(room["w"])
	var rh: int = int(room["h"])
	var cx: int = rx + int(float(rw) / 2.0)
	var cy: int = ry + int(float(rh) / 2.0)
	var best: Vector2i = Vector2i(-1, -1)
	var best_s: int = 1 << 30
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if x < 0 or y < 0 or x >= map_w or y >= map_h:
				continue
			if grid[y * map_w + x] != Gen.FLOOR:
				continue
			if not facing.has(Vector2i(x, y)):
				continue
			var score: int = absi(x - cx) + absi(y - cy)
			var better: bool = score < best_s
			if not better and score == best_s and best.x >= 0:
				better = x < best.x or (x == best.x and y < best.y)
			if better:
				best_s = score
				best = Vector2i(x, y)
	return best


static func _site(facing: Dictionary, floor_cell: Vector2i) -> Dictionary:
	if not facing.has(floor_cell):
		return {}
	var hit: Dictionary = facing[floor_cell]
	return {
		"fx": floor_cell.x,
		"fz": floor_cell.y,
		"wx": int(hit["wx"]),
		"wz": int(hit["wz"]),
		"nx": int(hit["nx"]),
		"nz": int(hit["nz"]),
	}


static func _degree(grid: PackedByteArray, map_w: int, map_h: int, cell: Vector2i) -> int:
	var n: int = 0
	for d: Vector2i in DIRS:
		var nx: int = cell.x + d.x
		var ny: int = cell.y + d.y
		if nx < 0 or ny < 0 or nx >= map_w or ny >= map_h:
			continue
		if grid[ny * map_w + nx] == Gen.FLOOR:
			n += 1
	return n


static func _touches_room(inside: Dictionary, cell: Vector2i) -> bool:
	for d: Vector2i in DIRS:
		if inside.has(cell + d):
			return true
	return false


static func _taken(used: Dictionary, cell: Vector2i) -> bool:
	if used.has(cell):
		return true
	for d: Vector2i in DIRS:
		if used.has(cell + d):
			return true
	return false
