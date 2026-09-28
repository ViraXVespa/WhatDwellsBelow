extends Object

## One torch per unlit room. Halls only at doorways, junctions, and dead ends.
## Brackets sit on outline spans that face floor. No 1 m face mount.

const Gen := preload("res://scripts/dungeon/gen.gd")

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
	var spans: Array = _span_list(host)
	if spans.is_empty():
		return out
	var per: int = maxi(1, int(host.data.get("solid_n", 1)))
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
	var used: Dictionary = {}
	for i in rooms.size():
		if lit.has(i):
			continue
		var room_s: Dictionary = rooms[i]
		var site: Dictionary = _span_in_room(spans, per, room_s)
		if site.is_empty():
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
		if run.is_empty():
			continue
		var hall: Dictionary = _run_site(run, spans, per)
		if hall.is_empty():
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
		var spur: Dictionary = _span_at(spans, per, spot)
		if spur.is_empty():
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


static func _span_list(host: Node) -> Array:
	var raw: Variant = host.data.get("outline_spans", [])
	if raw is Array:
		return raw
	return []


static func _span_in_room(spans: Array, per: int, room: Dictionary) -> Dictionary:
	var rx: int = int(room["x"])
	var ry: int = int(room["y"])
	var rw: int = int(room["w"])
	var rh: int = int(room["h"])
	var cx: int = rx + int(float(rw) / 2.0)
	var cy: int = ry + int(float(rh) / 2.0)
	var best: Dictionary = {}
	var best_s: int = 1 << 30
	var scale: float = float(maxi(1, per))
	var inset: float = 0.45 * scale
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		var nrm: Vector2 = _span_normal(run)
		if nrm == Vector2.ZERO:
			continue
		var ends: PackedVector2Array = _span_ends(run)
		if ends.size() < 2:
			continue
		var o: Vector2 = ends[0]
		var tip: Vector2 = ends[1]
		var mid: Vector2 = (o + tip) * 0.5
		var sample: Vector2 = mid + nrm * inset
		var sx: int = int(floor(sample.x / scale))
		var sz: int = int(floor(sample.y / scale))
		if sx < rx or sz < ry or sx >= rx + rw or sz >= ry + rh:
			continue
		var score: int = absi(sx - cx) + absi(sz - cy)
		var better: bool = score < best_s
		if not better and score == best_s and not best.is_empty():
			var bx: int = int(best["fx"])
			var bz: int = int(best["fz"])
			better = sx < bx or (sx == bx and sz < bz)
		if not better:
			continue
		best_s = score
		best = _site_on(mid, nrm, scale, sx, sz)
	return best


static func _run_site(run: Array[Vector2i], spans: Array, per: int) -> Dictionary:
	if run.is_empty():
		return {}
	var mid: int = int(float(run.size() - 1) / 2.0)
	var site: Dictionary = _span_at(spans, per, run[mid])
	if not site.is_empty():
		return site
	for step in range(1, run.size()):
		var lo: int = mid - step
		var hi: int = mid + step
		if lo >= 0:
			site = _span_at(spans, per, run[lo])
			if not site.is_empty():
				return site
		if hi < run.size():
			site = _span_at(spans, per, run[hi])
			if not site.is_empty():
				return site
	return {}


static func _span_at(spans: Array, per: int, cell: Vector2i) -> Dictionary:
	var scale: float = float(maxi(1, per))
	var aim: Vector2 = Vector2((float(cell.x) + 0.5) * scale, (float(cell.y) + 0.5) * scale)
	var limit: float = 2.0 * scale
	var best_d: float = limit
	var best_hit: Vector2 = Vector2.ZERO
	var best_n: Vector2 = Vector2.ZERO
	var found: bool = false
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		var nrm: Vector2 = _span_normal(run)
		if nrm == Vector2.ZERO:
			continue
		var ends: PackedVector2Array = _span_ends(run)
		if ends.size() < 2:
			continue
		var o: Vector2 = ends[0]
		var d: Vector2 = ends[1] - o
		var slen: float = d.length()
		if slen < 0.001:
			continue
		var ux: float = d.x / slen
		var uy: float = d.y / slen
		var along: float = (aim.x - o.x) * ux + (aim.y - o.y) * uy
		if along < -scale or along > slen + scale:
			continue
		var t: float = clampf(along, 0.0, slen)
		var hit: Vector2 = o + Vector2(ux, uy) * t
		var to_floor: Vector2 = aim - hit
		if to_floor.dot(nrm) <= 0.0:
			continue
		var dist: float = hit.distance_to(aim)
		if dist >= best_d:
			continue
		best_d = dist
		best_hit = hit
		best_n = nrm
		found = true
	if not found:
		return {}
	return _site_on(best_hit, best_n, scale, cell.x, cell.y)


static func _span_ends(run: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var raw_o: Variant = run.get("origin", null)
	var raw_d: Variant = run.get("delta", null)
	if not (raw_o is Vector2) or not (raw_d is Vector2):
		return out
	var o: Vector2 = raw_o as Vector2
	var d: Vector2 = raw_d as Vector2
	out.append(o)
	out.append(o + d)
	return out


static func _span_normal(run: Dictionary) -> Vector2:
	var raw_n: Variant = run.get("normal", null)
	if raw_n is Vector2:
		var nrm: Vector2 = raw_n as Vector2
		if nrm.length_squared() > 0.0001:
			return nrm.normalized()
	var ends: PackedVector2Array = _span_ends(run)
	if ends.size() < 2:
		return Vector2.ZERO
	var d: Vector2 = ends[1] - ends[0]
	if d.length_squared() < 0.0001:
		return Vector2.ZERO
	return Vector2(-d.y, d.x).normalized()


static func _site_on(hit: Vector2, nrm: Vector2, scale: float, fx: int, fz: int) -> Dictionary:
	var wall: Vector2 = hit / scale
	return {
		"fx": fx,
		"fz": fz,
		"nx": nrm.x,
		"nz": nrm.y,
		"px": wall.x + nrm.x * 0.12,
		"pz": wall.y + nrm.y * 0.12,
		"lx": wall.x + nrm.x * 0.45,
		"lz": wall.y + nrm.y * 0.45,
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


static func _taken(used: Dictionary, cell: Vector2i) -> bool:
	for z in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) + absi(z) > 2:
				continue
			if used.has(cell + Vector2i(x, z)):
				return true
	return false
