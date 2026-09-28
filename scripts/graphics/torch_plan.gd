extends Object

## One torch per unlit room. Halls only at doorways, junctions, and dead ends.
## Brackets sit on outline spans that face floor. No 1 m face mount.

const Gen := preload("res://scripts/dungeon/gen.gd")

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const RING: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

static var _sori: PackedVector2Array = PackedVector2Array()
static var _smid: PackedVector2Array = PackedVector2Array()
static var _snrm: PackedVector2Array = PackedVector2Array()
static var _sux: PackedFloat32Array = PackedFloat32Array()
static var _suy: PackedFloat32Array = PackedFloat32Array()
static var _slen: PackedFloat32Array = PackedFloat32Array()
static var _pn: int = 0
static var _cache_key: String = ""
static var _cache: Array[Dictionary] = []
static var _bins: Dictionary = {}

static func _prep_spans(spans: Array, per: int) -> void:
	_pn = 0
	_bins.clear()
	var n: int = spans.size()
	if _sori.size() != n:
		_sori.resize(n)
		_smid.resize(n)
		_snrm.resize(n)
		_sux.resize(n)
		_suy.resize(n)
		_slen.resize(n)
	var scale: float = float(maxi(1, per))
	var i: int = 0
	while i < n:
		var item: Variant = spans[i]
		i += 1
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		var ends: PackedVector2Array = _span_ends(run)
		if ends.size() < 2:
			continue
		var nrm: Vector2 = _span_normal(run)
		if nrm == Vector2.ZERO:
			continue
		var o: Vector2 = ends[0]
		var d: Vector2 = ends[1] - o
		var slen: float = d.length()
		if slen < 0.001:
			continue
		var pi: int = _pn
		_sori[pi] = o
		_smid[pi] = (ends[0] + ends[1]) * 0.5
		_snrm[pi] = nrm
		_sux[pi] = d.x / slen
		_suy[pi] = d.y / slen
		_slen[pi] = slen
		_pn += 1
		_bin_span(pi, ends[0], ends[1], scale)


static func _bin_span(pi: int, a: Vector2, b: Vector2, scale: float) -> void:
	var steps: int = maxi(1, int(ceil(a.distance_to(b) / scale)))
	var s: int = 0
	while s <= steps:
		var t: float = float(s) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		var key: Vector2i = Vector2i(int(floor(p.x / scale)), int(floor(p.y / scale)))
		var bucket: Variant = _bins.get(key, PackedInt32Array())
		var arr: PackedInt32Array = bucket
		arr.append(pi)
		_bins[key] = arr
		s += 1


static func _bin_near(cell: Vector2i) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var dy: int = -2
	while dy <= 2:
		var dx: int = -2
		while dx <= 2:
			var bucket: Variant = _bins.get(cell + Vector2i(dx, dy), PackedInt32Array())
			var arr: PackedInt32Array = bucket
			var i: int = 0
			while i < arr.size():
				var pi: int = arr[i]
				i += 1
				if seen.has(pi):
					continue
				seen[pi] = true
				out.append(pi)
			dx += 1
		dy += 1
	return out




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
	var rooms_n: int = (host.data.get("rooms", []) as Array).size()
	var key: String = "%d:%d:%d:%d" % [map_w, map_h, rooms_n, spans.size()]
	if key == _cache_key and not _cache.is_empty():
		return _apply_lit(host, props, _cache)
	var per: int = maxi(1, int(host.data.get("solid_n", 1)))
	_prep_spans(spans, per)
	var rooms: Array = host.data.get("rooms", [])
	var inside: PackedInt32Array = PackedInt32Array()
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
	for i2 in rooms.size():
		var site: Dictionary = _span_in_room(rooms[i2], per)
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
	for y2 in range(1, map_h - 1):
		var row2: int = y2 * map_w
		for x2 in range(1, map_w - 1):
			var i3: int = row2 + x2
			if inside[i3] >= 0:
				continue
			if grid[i3] != Gen.FLOOR:
				continue
			hall[i3] = 1
			if _touches_room_arr(grid, inside, map_w, map_h, x2, y2):
				mouth[i3] = 1
				mouths.append(Vector2i(x2, y2))
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
			for d: Vector2i in DIRS:
				var nxt: Vector2i = cur + d
				var ni: int = nxt.y * map_w + nxt.x
				if mouth[ni] != 0 and seen[ni] == 0:
					seen[ni] = 1
					q.append(nxt)
		if run.is_empty():
			continue
		var hall_site: Dictionary = _run_site(run, per)
		if hall_site.is_empty():
			continue
		var at: Vector2i = Vector2i(int(hall_site["fx"]), int(hall_site["fz"]))
		if _taken(used, at):
			continue
		used[at] = true
		out.append(hall_site)
	_thin_arr(hall, mouth, map_w, map_h)
	for y3 in range(1, map_h - 1):
		var row3: int = y3 * map_w
		for x3 in range(1, map_w - 1):
			if hall[row3 + x3] == 0:
				continue
			if mouth[row3 + x3] != 0:
				continue
			var spot: Vector2i = Vector2i(x3, y3)
			var exits: int = _ring_exits_arr(hall, map_w, map_h, spot)
			if exits != 1 and exits < 3:
				continue
			if _taken(used, spot):
				continue
			var spur: Dictionary = _span_at(per, spot)
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
	var inside: PackedInt32Array = PackedInt32Array()
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


static func _span_in_room(room: Dictionary, per: int) -> Dictionary:
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
	var i: int = 0
	while i < _pn:
		var nrm: Vector2 = _snrm[i]
		var mid: Vector2 = _smid[i]
		var sample: Vector2 = mid + nrm * inset
		var sx: int = int(floor(sample.x / scale))
		var sz: int = int(floor(sample.y / scale))
		i += 1
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


static func _run_site(run: Array[Vector2i], per: int) -> Dictionary:
	if run.is_empty():
		return {}
	var mid: int = int(float(run.size() - 1) / 2.0)
	var site: Dictionary = _span_at(per, run[mid])
	if not site.is_empty():
		return site
	for step in range(1, run.size()):
		var lo: int = mid - step
		var hi: int = mid + step
		if lo >= 0:
			site = _span_at(per, run[lo])
			if not site.is_empty():
				return site
		if hi < run.size():
			site = _span_at(per, run[hi])
			if not site.is_empty():
				return site
	return {}


static func _span_at(per: int, cell: Vector2i) -> Dictionary:
	var scale: float = float(maxi(1, per))
	var aim: Vector2 = Vector2((float(cell.x) + 0.5) * scale, (float(cell.y) + 0.5) * scale)
	var limit: float = 2.0 * scale
	var best_d: float = limit
	var best_hit: Vector2 = Vector2.ZERO
	var best_n: Vector2 = Vector2.ZERO
	var found: bool = false
	var hits: PackedInt32Array = _bin_near(cell)
	var hi: int = 0
	while hi < hits.size():
		var i: int = hits[hi]
		hi += 1
		var o: Vector2 = _sori[i]
		var slen: float = _slen[i]
		if slen < 0.001:
			continue
		var ux: float = _sux[i]
		var uy: float = _suy[i]
		var nrm: Vector2 = _snrm[i]
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


static func _thin_arr(mask: PackedByteArray, mouths: PackedByteArray, w: int, h: int) -> void:
	var step: int = 0
	while step < 6:
		step += 1
		var peel: PackedInt32Array = PackedInt32Array()
		for y in range(1, h - 1):
			var row: int = y * w
			for x in range(1, w - 1):
				var i: int = row + x
				if mask[i] == 0 or mouths[i] != 0:
					continue
				if _peelable_arr(mask, mouths, w, h, x, y):
					peel.append(i)
			for j in peel.size():
				mask[peel[j]] = 0
		if peel.is_empty():
			break

static func _peelable_arr(mask: PackedByteArray, mouths: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	var i: int = y * w + x
	if mouths[i] != 0:
		return false
	var orth: int = 0
	var pos_side: bool = false
	for d: Vector2i in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		var ni: int = ny * w + nx
		if mask[ni] != 0:
			orth += 1
		elif (d.x > 0 or d.y > 0) and mask[i - d.y * w - d.x] != 0:
			pos_side = true
	if orth < 2 or not pos_side:
		return false
	return _ring_exits_arr(mask, w, h, Vector2i(x, y)) == 1

static func _ring_exits_arr(mask: PackedByteArray, w: int, h: int, cell: Vector2i) -> int:
	var any: bool = false
	var on0: bool = false
	var prev: bool = false
	var exits: int = 0
	var i: int = 0
	while i < 8:
		var n: Vector2i = cell + RING[i]
		var hit: bool = n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and mask[n.y * w + n.x] != 0
		if i == 0:
			on0 = hit
		else:
			if hit and not prev:
				exits += 1
		if hit:
			any = true
		prev = hit
		i += 1
	if on0 and not prev:
		exits += 1
	if not any:
		return 0
	return exits

static func _touches_room_arr(
	grid: PackedByteArray,
	inside: PackedInt32Array,
	map_w: int,
	map_h: int,
	x: int,
	y: int
) -> bool:
	for d: Vector2i in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= map_w or ny >= map_h:
			continue
		var ni: int = ny * map_w + nx
		if inside[ni] < 0:
			continue
		if grid[ni] == Gen.FLOOR:
			return true
	return false


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
