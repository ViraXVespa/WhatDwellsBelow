extends Object

## One torch per unlit room. Halls only at doorways, junctions, and dead ends.
## Brackets sit on outline spans that face floor. No 1 m face mount.

const Gen := preload("res://scripts/dungeon/gen.gd")

const Spans := preload("res://scripts/graphics/torch_plan/spans.gd")
const Grid := preload("res://scripts/graphics/torch_plan/plan_grid.gd")

static var _cache_key: String = ""
static var _cache: Array[Dictionary] = []
static var _room_ix: PackedInt32Array = PackedInt32Array()

static func build(host: Node, props: Array, clip: Rect2i = Rect2i()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if host == null or host.data == null:
		return out
	var grid: PackedByteArray = host.data.grid
	var map_w: int = int(host.data.w)
	var map_h: int = int(host.data.h)
	if map_w < 3 or map_h < 3 or grid.is_empty():
		return out
	var spans: Array = _span_list(host)
	if spans.is_empty():
		return out
	var rooms_n: int = (host.data.get("rooms", []) as Array).size()
	var seed_n: int = 0
	var floor_n: int = 0
	if App != null:
		seed_n = int(App.run_seed)
		floor_n = int(App.floor_n)
	var key: String = "%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [map_w, map_h, rooms_n, spans.size(), seed_n, floor_n, clip.position.x, clip.position.y, clip.size.x, clip.size.y]
	if key == _cache_key and not _cache.is_empty():
		return _apply_lit(host, props, _cache)
	var per: int = maxi(1, int(host.data.get("solid_n", 1)))
	Spans._prep_spans(spans, per)
	var rooms: Array = host.data.get("rooms", [])
	var inside: PackedInt32Array = PackedInt32Array()
	inside.resize(map_w * map_h)
	inside.fill(-1)
	var cx0: int = 1
	var cy0: int = 1
	var cx1: int = map_w - 1
	var cy1: int = map_h - 1
	if clip.size.x > 0 and clip.size.y > 0:
		cx0 = clampi(clip.position.x, 1, map_w - 1)
		cy0 = clampi(clip.position.y, 1, map_h - 1)
		cx1 = clampi(clip.position.x + clip.size.x, 1, map_w - 1)
		cy1 = clampi(clip.position.y + clip.size.y, 1, map_h - 1)
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var rx: int = int(room["x"])
		var ry: int = int(room["y"])
		var rw: int = int(room["w"])
		var rh: int = int(room["h"])
		var y: int = ry
		while y < ry + rh:
			if y >= 0 and y < map_h:
				var row: int = y * map_w
				var x: int = rx
				while x < rx + rw:
					if x >= 0 and x < map_w:
						inside[row + x] = i
					x += 1
			y += 1
	_room_ix = inside
	var used: Dictionary = {}
	for i2 in rooms.size():
		var room2: Dictionary = rooms[i2]
		var rx2: int = int(room2["x"])
		var ry2: int = int(room2["y"])
		var rw2: int = int(room2["w"])
		var rh2: int = int(room2["h"])
		if rx2 + rw2 < cx0 or ry2 + rh2 < cy0 or rx2 > cx1 or ry2 > cy1:
			continue
		var site: Dictionary = Spans._span_in_room(room2, per)
		if site.is_empty():
			continue
		used[Vector2i(int(site["fx"]), int(site["fz"]))] = true
		out.append(site)
	var mouth: PackedByteArray = PackedByteArray()
	var hall: PackedByteArray = PackedByteArray()
	mouth.resize(map_w * map_h)
	hall.resize(map_w * map_h)
	mouth.fill(0)
	hall.fill(0)
	var mouths: Array[Vector2i] = []
	var hall_ix: PackedInt32Array = PackedInt32Array()
	var y2: int = cy0
	while y2 < cy1:
		var row2: int = y2 * map_w
		var x2: int = cx0
		while x2 < cx1:
			var i3: int = row2 + x2
			if inside[i3] >= 0:
				x2 += 1
				continue
			if grid[i3] != Gen.FLOOR:
				x2 += 1
				continue
			hall[i3] = 1
			hall_ix.append(i3)
			if Grid._touches_room_arr(grid, inside, map_w, map_h, x2, y2):
				mouth[i3] = 1
				mouths.append(Vector2i(x2, y2))
			x2 += 1
		y2 += 1
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(map_w * map_h)
	seen.fill(0)
	for mi in mouths.size():
		var start: Vector2i = mouths[mi]
		var si: int = start.y * map_w + start.x
		if seen[si] != 0:
			continue
		var run: Array[Vector2i] = []
		var q: Array[Vector2i] = [start]
		seen[si] = 1
		var head: int = 0
		while head < q.size():
			var cur: Vector2i = q[head]
			head += 1
			run.append(cur)
			for d: Vector2i in Grid.DIRS:
				var nxt: Vector2i = cur + d
				if nxt.x < 1 or nxt.y < 1 or nxt.x > map_w - 2 or nxt.y > map_h - 2:
					continue
				var ni: int = nxt.y * map_w + nxt.x
				if mouth[ni] != 0 and seen[ni] == 0:
					seen[ni] = 1
					q.append(nxt)
		if run.is_empty():
			continue
		var hall_site: Dictionary = Spans._run_site(run, per)
		if hall_site.is_empty():
			continue
		var at: Vector2i = Vector2i(int(hall_site["fx"]), int(hall_site["fz"]))
		if _taken(used, at):
			continue
		used[at] = true
		out.append(hall_site)
	Grid._thin_arr(hall, mouth, map_w, map_h, hall_ix)
	var hi3: int = 0
	while hi3 < hall_ix.size():
		var i4: int = hall_ix[hi3]
		hi3 += 1
		if hall[i4] == 0:
			continue
		if mouth[i4] != 0:
			continue
		var y3: int = int(float(i4) / float(map_w))
		var x3: int = i4 - y3 * map_w
		var spot: Vector2i = Vector2i(x3, y3)
		var exits: int = Grid._ring_exits_arr(hall, map_w, map_h, spot)
		if exits != 1 and exits < 3:
			continue
		if _taken(used, spot):
			continue
		var spur: Dictionary = Spans._span_at(per, spot)
		if spur.is_empty():
			continue
		var mounted: Vector2i = Vector2i(int(spur["fx"]), int(spur["fz"]))
		if _taken(used, mounted):
			continue
		used[mounted] = true
		out.append(spur)
	_cache_key = key
	_cache = out
	return _apply_lit(host, props, out)
static func _apply_lit(host: Node, props: Array, layout: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if host == null or host.data == null or layout.is_empty():
		return out
	var map_w: int = int(host.data.w)
	var map_h: int = int(host.data.h)
	var rooms: Array = host.data.get("rooms", [])
	var inside: PackedInt32Array = _room_ix
	if inside.size() != map_w * map_h:
		inside = PackedInt32Array()
		inside.resize(map_w * map_h)
		inside.fill(-1)
		for i in rooms.size():
			var room: Dictionary = rooms[i]
			var rx: int = int(room["x"])
			var ry: int = int(room["y"])
			var rw: int = int(room["w"])
			var rh: int = int(room["h"])
			var y: int = ry
			while y < ry + rh:
				if y >= 0 and y < map_h:
					var row: int = y * map_w
					var x: int = rx
					while x < rx + rw:
						if x >= 0 and x < map_w:
							inside[row + x] = i
						x += 1
				y += 1
		_room_ix = inside
	var lit: PackedByteArray = PackedByteArray()
	lit.resize(rooms.size())
	lit.fill(0)
	for node in props:
		if not is_instance_valid(node):
			continue
		var cell: Vector2i = _prop_cell(node)
		if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
			continue
		var ri: int = inside[cell.y * map_w + cell.x]
		if ri >= 0:
			lit[ri] = 1
	var used: Dictionary = {}
	for item in layout:
		var site: Dictionary = item
		var fx: int = int(site.get("fx", -1))
		var fz: int = int(site.get("fz", -1))
		if fx < 0 or fz < 0 or fx >= map_w or fz >= map_h:
			continue
		var room_i: int = inside[fz * map_w + fx]
		if room_i >= 0 and lit[room_i] != 0:
			continue
		var at: Vector2i = Vector2i(fx, fz)
		if _taken(used, at):
			continue
		used[at] = true
		out.append(site)
	return out

static func _prop_cell(node: Node) -> Vector2i:
	if str(node.get("kind")) == "crystal":
		var raw: Variant = node.get("crystal_cell")
		if raw is Vector2i:
			return raw
	var p: Vector3 = (node as Node3D).global_position
	return Vector2i(int(round(p.x - 0.5)), int(round(p.z - 0.5)))

static func _span_list(host: Node) -> Array:
	var raw: Variant = host.data.get("outline_spans", [])
	if raw is Array:
		return raw
	return []

static func _taken(used: Dictionary, cell: Vector2i) -> bool:
	for z in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) + absi(z) > 2:
				continue
			if used.has(cell + Vector2i(x, z)):
				return true
	return false
