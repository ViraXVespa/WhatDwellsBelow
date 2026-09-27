extends Object

## One torch per unlit room. Halls only at doorways, junctions, and dead ends.

const Gen := preload("res://scripts/dungeon/gen.gd")
const WallRects := preload("res://scripts/world/wall_rects.gd")

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const RING: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


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
		var floor_cell: Vector2i = _room_floor(grid, map_w, map_h, room_s, facing, true)
		if floor_cell.x < 0:
			floor_cell = _room_floor(grid, map_w, map_h, room_s, facing, false)
		if floor_cell.x < 0:
			continue
		var site: Dictionary = _site(facing, floor_cell)
		if site.is_empty():
			site = _mount(facing, floor_cell)
		if site.is_empty():
			continue
		if not _snap_span(host, site):
			continue
		used[Vector2i(int(site["fx"]), int(site["fz"]))] = true
		out.append(site)
	var mouths: Dictionary = {}
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			var cell: Vector2i = Vector2i(x, y)
			if inside.has(cell):
				continue
			if grid[y * map_w + x] != Gen.FLOOR:
				continue
			if _touches_room(grid, map_w, map_h, inside, cell):
				mouths[cell] = true
	var seen: Dictionary = {}
	var keys: Array = mouths.keys()
	for i in keys.size():
		var start: Vector2i = keys[i]
		if seen.has(start):
			continue
		var run: Array[Vector2i] = []
		var q: Array[Vector2i] = [start]
		seen[start] = true
		var head: int = 0
		while head < q.size():
			var cur: Vector2i = q[head]
			head += 1
			run.append(cur)
			for d: Vector2i in DIRS:
				var nxt: Vector2i = cur + d
				if mouths.has(nxt) and not seen.has(nxt):
					seen[nxt] = true
					q.append(nxt)
		var door: Vector2i = _run_pick(run, facing)
		if door.x < 0:
			if run.is_empty():
				continue
			door = run[int(float(run.size() - 1) / 2.0)]
		if _taken(used, door):
			continue
		var hall: Dictionary = _mount(facing, door)
		if hall.is_empty():
			continue
		if not _snap_span(host, hall):
			continue
		var at: Vector2i = Vector2i(int(hall["fx"]), int(hall["fz"]))
		if _taken(used, at):
			continue
		used[at] = true
		out.append(hall)
	var mask: Dictionary = {}
	for y3 in range(1, map_h - 1):
		for x3 in range(1, map_w - 1):
			var hall_cell: Vector2i = Vector2i(x3, y3)
			if inside.has(hall_cell):
				continue
			if grid[y3 * map_w + x3] != Gen.FLOOR:
				continue
			mask[hall_cell] = true
	_thin(mask, mouths)
	var spine: Array = mask.keys()
	for s in spine.size():
		var spot: Vector2i = spine[s]
		if mouths.has(spot):
			continue
		var exits: int = _ring_exits(mask, spot)
		if exits != 1 and exits < 3:
			continue
		if _taken(used, spot):
			continue
		var spur: Dictionary = _mount(facing, spot)
		if spur.is_empty():
			continue
		if not _snap_span(host, spur):
			continue
		var mounted: Vector2i = Vector2i(int(spur["fx"]), int(spur["fz"]))
		if _taken(used, mounted):
			continue
		used[mounted] = true
		out.append(spur)
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
			if grid[y * map_w + x] == Gen.FLOOR:
				continue
			if not _touches_floor(grid, map_w, map_h, x, y):
				continue
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
			var is_end: bool = k == 0 or k == length - 1
			if by_floor.has(floor_cell):
				var prev: Dictionary = by_floor[floor_cell]
				if bool(prev.get("end", false)) or not is_end:
					continue
			by_floor[floor_cell] = {
				"wx": wall.x, "wz": wall.y, "nx": n.x, "nz": n.y, "end": is_end,
			}
	return by_floor


static func _room_floor(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	room: Dictionary,
	facing: Dictionary,
	ends_only: bool
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
			var hit: Dictionary = facing[Vector2i(x, y)]
			if ends_only and not bool(hit.get("end", false)):
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
	if not bool(hit.get("end", false)):
		return {}
	return {
		"fx": floor_cell.x,
		"fz": floor_cell.y,
		"wx": int(hit["wx"]),
		"wz": int(hit["wz"]),
		"nx": int(hit["nx"]),
		"nz": int(hit["nz"]),
	}


static func _touches_floor(grid: PackedByteArray, map_w: int, map_h: int, x: int, y: int) -> bool:
	for d: Vector2i in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= map_w or ny >= map_h:
			continue
		if grid[ny * map_w + nx] == Gen.FLOOR:
			return true
	return false


static func _mount(facing: Dictionary, floor_cell: Vector2i) -> Dictionary:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 99
	for z in range(-2, 3):
		for x in range(-2, 3):
			var n: Vector2i = floor_cell + Vector2i(x, z)
			if not facing.has(n):
				continue
			var dist: int = absi(x) + absi(z)
			if dist < best_d:
				best_d = dist
				best = n
	if best.x < 0:
		return {}
	var hit: Dictionary = facing[best]
	return {
		"fx": best.x,
		"fz": best.y,
		"wx": int(hit["wx"]),
		"wz": int(hit["wz"]),
		"nx": int(hit["nx"]),
		"nz": int(hit["nz"]),
	}


static func _thin(mask: Dictionary, mouths: Dictionary) -> void:
	var step: int = 0
	while step < 6:
		step += 1
		var peel: Array[Vector2i] = []
		var keys: Array = mask.keys()
		for i in keys.size():
			var cell: Vector2i = keys[i]
			if _peelable(mask, mouths, cell):
				peel.append(cell)
		if peel.is_empty():
			break
		for j in peel.size():
			mask.erase(peel[j])


static func _peelable(mask: Dictionary, mouths: Dictionary, cell: Vector2i) -> bool:
	if mouths.has(cell):
		return false
	var orth: int = 0
	var pos_side: bool = false
	for d: Vector2i in DIRS:
		var nxt: Vector2i = cell + d
		if mask.has(nxt):
			orth += 1
		elif (d.x > 0 or d.y > 0) and mask.has(cell - d):
			pos_side = true
	if orth < 2 or not pos_side:
		return false
	return _ring_exits(mask, cell) == 1


static func _ring_exits(mask: Dictionary, cell: Vector2i) -> int:
	var on: Array[bool] = []
	on.resize(8)
	var any: bool = false
	for i in 8:
		var hit: bool = mask.has(cell + RING[i])
		on[i] = hit
		if hit:
			any = true
	if not any:
		return 0
	var exits: int = 0
	for j in 8:
		var prev: int = (j + 7) % 8
		if on[j] and not on[prev]:
			exits += 1
	return exits


static func _run_pick(run: Array[Vector2i], facing: Dictionary) -> Vector2i:
	var mid: int = int(float(run.size() - 1) / 2.0)
	var pick: Vector2i = Vector2i(-1, -1)
	var best: int = 1 << 30
	for i in run.size():
		var cell: Vector2i = run[i]
		if not facing.has(cell):
			continue
		var score: int = absi(i - mid)
		if score < best:
			best = score
			pick = cell
	return pick


static func _touches_room(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	inside: Dictionary,
	cell: Vector2i
) -> bool:
	for d: Vector2i in DIRS:
		var n: Vector2i = cell + d
		if not inside.has(n):
			continue
		if n.x < 0 or n.y < 0 or n.x >= map_w or n.y >= map_h:
			continue
		if grid[n.y * map_w + n.x] == Gen.FLOOR:
			return true
	return false


static func _snap_span(host: Node, site: Dictionary) -> bool:
	var spans: Variant = host.data.get("outline_spans", [])
	if not (spans is Array) or (spans as Array).is_empty():
		return true
	var n: int = maxi(1, int(host.data.get("solid_n", 1)))
	var px: float = (float(site["wx"]) + 0.5) * float(n)
	var pz: float = (float(site["wz"]) + 0.5) * float(n)
	var cn: Vector2 = Vector2(float(site["nx"]), float(site["nz"]))
	if cn.length_squared() < 0.0001:
		return false
	cn = cn.normalized()
	var best_n := Vector2.ZERO
	var best_d := 4.0
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var slen: float = d.length()
		if slen < 0.001:
			continue
		var ux: float = d.x / slen
		var uy: float = d.y / slen
		var rx: float = px - o.x
		var ry: float = pz - o.y
		var along: float = rx * ux + ry * uy
		if along < -1.0 or along > slen + 1.0:
			continue
		var dist: float = absf(-uy * rx + ux * ry)
		if dist > float(n) * 1.25 or dist >= best_d:
			continue
		var nrm: Vector2 = Vector2(-uy, ux)
		if run.has("normal"):
			var raw_n: Vector2 = run["normal"] as Vector2
			if raw_n.length_squared() > 0.0001:
				nrm = raw_n.normalized()
		var to_floor: Vector2 = Vector2(
			float(site["fx"]) + 0.5 - px,
			float(site["fz"]) + 0.5 - pz
		)
		if to_floor.dot(nrm) < 0.0:
			nrm = -nrm
		best_d = dist
		best_n = nrm
	if best_n == Vector2.ZERO:
		return true
	site["nx"] = best_n.x
	site["nz"] = best_n.y
	return true


static func _taken(used: Dictionary, cell: Vector2i) -> bool:
	for z in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) + absi(z) > 2:
				continue
			if used.has(cell + Vector2i(x, z)):
				return true
	return false
