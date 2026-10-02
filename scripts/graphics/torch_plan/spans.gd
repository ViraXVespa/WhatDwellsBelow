extends Object

## Torch plan outline spans: build, bin, and place hall brackets. Owns the span buffers.

static var _sori: PackedVector2Array = PackedVector2Array()
static var _smid: PackedVector2Array = PackedVector2Array()
static var _snrm: PackedVector2Array = PackedVector2Array()
static var _sux: PackedFloat32Array = PackedFloat32Array()
static var _suy: PackedFloat32Array = PackedFloat32Array()
static var _slen: PackedFloat32Array = PackedFloat32Array()
static var _pn: int = 0
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
		var bucket: Variant = _bins.get(key)
		if bucket is Array:
			(bucket as Array).append(pi)
		else:
			var row: Array = []
			row.append(pi)
			_bins[key] = row
		s += 1

static func _bin_near(cell: Vector2i) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var dy: int = -2
	while dy <= 2:
		var dx: int = -2
		while dx <= 2:
			_collect_bin(out, seen, cell + Vector2i(dx, dy))
			dx += 1
		dy += 1
	return out

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
	var seen: Dictionary = {}
	var hits: PackedInt32Array = PackedInt32Array()
	var x: int = rx
	while x < rx + rw:
		_collect_bin(hits, seen, Vector2i(x, ry))
		_collect_bin(hits, seen, Vector2i(x, ry + rh - 1))
		x += 1
	var y: int = ry + 1
	while y < ry + rh - 1:
		_collect_bin(hits, seen, Vector2i(rx, y))
		_collect_bin(hits, seen, Vector2i(rx + rw - 1, y))
		y += 1
	var hi: int = 0
	while hi < hits.size():
		var i: int = hits[hi]
		hi += 1
		var nrm: Vector2 = _snrm[i]
		var mid: Vector2 = _smid[i]
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

static func _collect_bin(hits: PackedInt32Array, seen: Dictionary, cell: Vector2i) -> void:
	var bucket: Variant = _bins.get(cell)
	if not (bucket is Array):
		return
	var arr: Array = bucket
	var i: int = 0
	while i < arr.size():
		var pi: int = int(arr[i])
		i += 1
		if seen.has(pi):
			continue
		seen[pi] = true
		hits.append(pi)

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
