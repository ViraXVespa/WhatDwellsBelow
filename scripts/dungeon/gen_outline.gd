extends Object

const LoadTiming := preload("res://scripts/debug/load_timing.gd")

## OR-fill each room rect and hall band. outline_spans is the solid perimeter.
## The 1 m grid stays the logical map. Do not push every shape loop as brick.

const FLOOR := 1
const LONG_EDGE := 4
const K_HALL := 1
const K_INTERIOR := 2
const K_RIM := 3
const PAD := 0.75


static func stamp(data: Dictionary, rng: RandomNumberGenerator, bal: Object) -> void:
	var fine_m: float = _fine_m(bal)
	var per: int = _per_m(fine_m)
	var grid: PackedByteArray = data["grid"]
	var w: int = int(data["w"])
	var h: int = int(data["h"])
	var rooms: Array = data["rooms"]
	var halls: Array = []
	var raw_halls: Variant = data.get("halls", [])
	if raw_halls is Array:
		halls = raw_halls
	var kind: PackedByteArray = _kinds(grid, w, h, rooms)
	var shapes: Array = _shapes(rooms, halls, per)
	LoadTiming.dmark("gen_outline_up")
	var parts: Array = []
	for shape_v in shapes:
		var poly: PackedVector2Array = shape_v
		if poly.size() >= 3:
			parts.append(poly)
	for i in parts.size():
		var flip: PackedVector2Array = parts[i]
		if _area(flip) < 0.0:
			flip.reverse()
			parts[i] = flip
	var fillet: float = _frac(bal, "outline_fillet_frac", 0.40)
	var loops: Array = []
	for part_v in parts:
		var part: PackedVector2Array = part_v
		if _area(part) <= 1.0:
			loops.append(part)
			continue
		var pts: Array[Vector2] = _copy_pts(part)
		if per >= 2 and part.size() > 4:
			pts = _fillet_points(pts, rng, fillet, per, kind, w, h)
		loops.append(_fold_pts(pts))
	LoadTiming.dmark("gen_outline_jag")
	var sw: int = w * per
	var sh: int = h * per
	var solid: PackedByteArray = PackedByteArray()
	solid.resize(sw * sh)
	solid.fill(0)
	for loop_v in loops:
		var loop: PackedVector2Array = loop_v
		if _area(loop) < 0.0:
			loop.reverse()
		if _area(loop) > 1.0:
			_fill(solid, sw, sh, loop, 1)
	_keep_rooms(solid, sw, sh, rooms, per)
	var spans: Array = _spans_from_solid(solid, sw, sh)
	data["outline_fine_m"] = fine_m
	data["solid"] = solid
	data["solid_w"] = sw
	data["solid_h"] = sh
	data["solid_n"] = per
	data["outline_spans"] = spans
	LoadTiming.dmark("gen_outline_spans")


static func _fine_m(bal: Object) -> float:
	var m: float = 0.25
	if bal != null:
		m = float(bal.get("outline_fine_m"))
	if m >= 0.87:
		return 1.0
	if m >= 0.37:
		return 0.5
	return 0.25


static func _per_m(fine_m: float) -> int:
	return clampi(int(round(1.0 / fine_m)), 1, 4)


static func _frac(bal: Object, key: String, fallback: float) -> float:
	var v: float = fallback
	if bal != null:
		v = float(bal.get(key))
	return clampf(v, 0.0, 1.0)


static func _kinds(grid: PackedByteArray, w: int, h: int, rooms: Array) -> PackedByteArray:
	var kind: PackedByteArray = PackedByteArray()
	kind.resize(w * h)
	kind.fill(0)
	for y in h:
		var row: int = y * w
		for x in w:
			if grid[row + x] == FLOOR:
				kind[row + x] = K_HALL
	for room_v in rooms:
		var room: Dictionary = room_v
		var rx: int = int(room["x"])
		var ry: int = int(room["y"])
		var rw: int = int(room["w"])
		var rh: int = int(room["h"])
		var x1: int = rx + rw
		var y1: int = ry + rh
		for yy in range(ry, y1):
			if yy <= 0 or yy >= h - 1:
				continue
			for xx in range(rx, x1):
				if xx <= 0 or xx >= w - 1:
					continue
				if grid[yy * w + xx] != FLOOR:
					continue
				var inset: bool = xx > rx and yy > ry and xx < x1 - 1 and yy < y1 - 1
				kind[yy * w + xx] = K_INTERIOR if inset else K_RIM
	return kind


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(Vector2(x0, y0))
	poly.append(Vector2(x1, y0))
	poly.append(Vector2(x1, y1))
	poly.append(Vector2(x0, y1))
	return poly


static func _band(a: Vector2, b: Vector2, rad: float) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	var delta: Vector2 = b - a
	var span_l: float = delta.length()
	if span_l < 0.001:
		return _circle(a, rad, 8)
	var dir: Vector2 = delta / span_l
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var steps: int = 4
	poly.append(a + perp * rad)
	poly.append(b + perp * rad)
	var ang0: float = atan2(perp.y, perp.x)
	for s in range(1, steps):
		var ang: float = ang0 - PI * float(s) / float(steps)
		poly.append(b + Vector2(cos(ang), sin(ang)) * rad)
	poly.append(b - perp * rad)
	poly.append(a - perp * rad)
	var ang1: float = atan2(-perp.y, -perp.x)
	for s2 in range(1, steps):
		var ang_b: float = ang1 - PI * float(s2) / float(steps)
		poly.append(a + Vector2(cos(ang_b), sin(ang_b)) * rad)
	return poly


static func _circle(c: Vector2, rad: float, steps: int) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	for s in steps:
		var ang: float = TAU * float(s) / float(steps)
		poly.append(c + Vector2(cos(ang), sin(ang)) * rad)
	return poly


static func _shapes(rooms: Array, halls: Array, per: int) -> Array:
	var out: Array = []
	var pad: float = PAD
	var scale: float = float(per)
	for room_v in rooms:
		var room: Dictionary = room_v
		var x0: float = float(int(room["x"])) * scale
		var y0: float = float(int(room["y"])) * scale
		var x1: float = float(int(room["x"]) + int(room["w"])) * scale
		var y1: float = float(int(room["y"]) + int(room["h"])) * scale
		out.append(_rect(x0, y0, x1, y1))
	for hall_v in halls:
		var hall: Dictionary = hall_v
		if str(hall.get("k", "")) == "band":
			var half: float = float(maxi(1, int(hall["w"]))) * 0.5
			var rad: float = sqrt(half * half + 0.25) * scale + pad
			var a: Vector2 = Vector2((float(int(hall["ax"])) + 0.5) * scale, (float(int(hall["ay"])) + 0.5) * scale)
			var b: Vector2 = Vector2((float(int(hall["bx"])) + 0.5) * scale, (float(int(hall["by"])) + 0.5) * scale)
			out.append(_band(a, b, rad))
		else:
			var hx0: float = float(int(hall["x0"])) * scale - pad
			var hy0: float = float(int(hall["y0"])) * scale - pad
			var hx1: float = float(int(hall["x1"]) + 1) * scale + pad
			var hy1: float = float(int(hall["y1"]) + 1) * scale + pad
			out.append(_rect(hx0, hy0, hx1, hy1))
	return out


static func _area(poly: PackedVector2Array) -> float:
	var count: int = poly.size()
	var acc: float = 0.0
	if count < 3:
		return 0.0
	for i in count:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % count]
		acc += p.x * q.y - q.x * p.y
	return acc * 0.5


static func _box(poly: PackedVector2Array) -> Vector4:
	var x0: float = poly[0].x
	var y0: float = poly[0].y
	var x1: float = x0
	var y1: float = y0
	for i in poly.size():
		var p: Vector2 = poly[i]
		x0 = minf(x0, p.x)
		y0 = minf(y0, p.y)
		x1 = maxf(x1, p.x)
		y1 = maxf(y1, p.y)
	return Vector4(x0, y0, x1, y1)


static func _box_hit(a: Vector4, b: Vector4) -> bool:
	return not (a.z < b.x or b.z < a.x or a.w < b.y or b.w < a.y)


static func _union_all(shapes: Array) -> Array:
	var parts: Array = []
	var boxes: Array = []
	for shape_v in shapes:
		var poly: PackedVector2Array = shape_v
		if poly.size() < 3:
			continue
		var pending: Array = [poly]
		var pending_box: Array = [_box(poly)]
		var spins: int = 0
		while not pending.is_empty() and spins < 8000:
			spins += 1
			var last: int = pending.size() - 1
			var cur: PackedVector2Array = pending[last]
			var cur_box: Vector4 = pending_box[last] as Vector4
			pending.remove_at(last)
			pending_box.remove_at(last)
			var i: int = 0
			var guard: int = 0
			while i < parts.size() and guard < 8000:
				guard += 1
				if not _box_hit(cur_box, boxes[i] as Vector4):
					i += 1
					continue
				var other: PackedVector2Array = parts[i]
				var got: Array = Geometry2D.merge_polygons(other, cur)
				if got.is_empty():
					i += 1
					continue
				parts.remove_at(i)
				boxes.remove_at(i)
				var best: int = 0
				var best_a: float = -1.0e20
				for gi in got.size():
					var piece: PackedVector2Array = got[gi] as PackedVector2Array
					var area: float = _area(piece)
					if area > best_a:
						best_a = area
						best = gi
				cur = got[best] as PackedVector2Array
				cur_box = _box(cur)
				for gi2 in got.size():
					if gi2 == best:
						continue
					var extra: PackedVector2Array = got[gi2] as PackedVector2Array
					pending.append(extra)
					pending_box.append(_box(extra))
				i = 0
			parts.append(cur)
			boxes.append(cur_box)
	return parts


static func _orient(parts: Array) -> void:
	var max_abs: float = 0.0
	var max_signed: float = 0.0
	for part_v in parts:
		var poly: PackedVector2Array = part_v
		var area: float = _area(poly)
		if absf(area) > max_abs:
			max_abs = absf(area)
			max_signed = area
	if max_signed >= 0.0:
		return
	for i in parts.size():
		var flip: PackedVector2Array = parts[i]
		flip.reverse()
		parts[i] = flip


static func _copy_pts(poly: PackedVector2Array) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for p in poly:
		pts.append(p)
	return pts


static func _collinear(a: Vector2, b: Vector2, c: Vector2) -> bool:
	var ab: Vector2 = b - a
	var ac: Vector2 = c - a
	var cross: float = ab.x * ac.y - ab.y * ac.x
	return absf(cross) <= 0.2 * maxf(ab.length(), 1.0)


static func _fold_pts(pts: Array[Vector2]) -> PackedVector2Array:
	var count: int = pts.size()
	var out: PackedVector2Array = PackedVector2Array()
	if count < 3:
		return out
	for i in count:
		var prev: Vector2 = pts[(i + count - 1) % count]
		var cur: Vector2 = pts[i]
		var nxt: Vector2 = pts[(i + 1) % count]
		if cur.distance_squared_to(prev) < 0.01:
			continue
		if _collinear(prev, cur, nxt):
			continue
		out.append(cur)
	if out.size() < 3:
		for p in pts:
			out.append(p)
	return out


static func _depth(rng: RandomNumberGenerator) -> int:
	if rng.randf() > 0.72:
		return 0
	if rng.randf() < 0.5:
		return 1
	return 2


static func _jag_edge(out: Array[Vector2], rng: RandomNumberGenerator, a: Vector2, b: Vector2, per: int) -> void:
	var delta: Vector2 = b - a
	var span_l: float = delta.length()
	if span_l < 1.0:
		return
	var dir: Vector2 = delta / span_l
	var outward: Vector2 = Vector2(dir.y, -dir.x)
	var segs: Array[int] = [4, 6, 8, 12]
	var t: float = float(per)
	var end: float = span_l - float(per)
	while t < end:
		if end - t < float(per):
			break
		var seg: int = segs[rng.randi() % segs.size()]
		var depth: int = _depth(rng)
		if depth == 0 and rng.randf() < 0.4:
			depth = 0
		var run: float = float(seg)
		if t + run > end:
			run = end - t
		if depth > 0 and run >= 2.0:
			var p0: Vector2 = a + dir * t
			out.append(p0)
			out.append(p0 + outward * float(depth))
			out.append(p0 + outward * float(depth) + dir * run)
			out.append(a + dir * (t + run))
		t += run + float(4 + rng.randi() % 5)


static func _jag_points(pts: Array[Vector2], rng: RandomNumberGenerator, frac: float, per: int) -> Array[Vector2]:
	var count: int = pts.size()
	if frac <= 0.0 or count < 3:
		return pts
	var edges: PackedInt32Array = PackedInt32Array()
	var limit: float = float(LONG_EDGE * per)
	for i in count:
		var delta: Vector2 = pts[(i + 1) % count] - pts[i]
		var card_x: bool = absf(delta.y) < 0.2 and absf(delta.x) >= limit
		var card_y: bool = absf(delta.x) < 0.2 and absf(delta.y) >= limit
		if card_x or card_y:
			edges.append(i)
	if edges.is_empty():
		return pts
	var want: int = int(round(frac * float(edges.size())))
	if want < 1:
		want = 1
	if want > edges.size():
		want = edges.size()
	for i in want:
		var j: int = i + (rng.randi() % (edges.size() - i))
		var swap: int = edges[i]
		edges[i] = edges[j]
		edges[j] = swap
	var picked: Dictionary = {}
	for i2 in want:
		picked[int(edges[i2])] = true
	var out: Array[Vector2] = []
	for i3 in count:
		var a: Vector2 = pts[i3]
		out.append(a)
		if not bool(picked.get(i3, false)):
			continue
		_jag_edge(out, rng, a, pts[(i3 + 1) % count], per)
	return out


static func _fillet_at(out: Array[Vector2], pts: Array[Vector2], i: int, per: int, kind: PackedByteArray, gw: int, gh: int) -> void:
	var count: int = pts.size()
	var prev: Vector2 = pts[(i + count - 1) % count]
	var cur: Vector2 = pts[i]
	var nxt: Vector2 = pts[(i + 1) % count]
	var vin: Vector2 = cur - prev
	var vout: Vector2 = nxt - cur
	var lin: float = vin.length()
	var lout: float = vout.length()
	if lin < 0.5 or lout < 0.5:
		out.append(cur)
		return
	vin = vin / lin
	vout = vout / lout
	var dot: float = clampf(vin.dot(vout), -0.999, 0.999)
	var phi: float = acos(dot)
	if absf(phi - PI * 0.5) > 0.35:
		out.append(cur)
		return
	var inward: Vector2 = Vector2(-vin.y, vin.x)
	var sample: Vector2 = cur + inward * float(per) * 0.75
	var cx: int = int(floor(sample.x / float(per)))
	var cy: int = int(floor(sample.y / float(per)))
	var hall: bool = false
	if cx >= 0 and cy >= 0 and cx < gw and cy < gh:
		hall = int(kind[cy * gw + cx]) == K_HALL
	var rad: float = float(per - 1) if hall else float(maxi(1, per - 2))
	var bis: Vector2 = vout - vin
	if bis.length_squared() < 0.0001:
		out.append(cur)
		return
	bis = bis.normalized()
	if hall:
		var bite: float = minf(rad * 0.5, minf(lin, lout) * 0.3)
		if bite < 0.4:
			out.append(cur)
			return
		var bump: Vector2 = cur - bis * rad
		out.append(cur - vin * bite)
		out.append(cur - vin * bite * 0.35 + bump * 0.65)
		out.append(bump)
		out.append(cur + vout * bite * 0.35 + bump * 0.65)
		out.append(cur + vout * bite)
		return
	var tlen: float = rad * tan(phi * 0.5)
	if tlen < 0.4 or tlen > lin * 0.45 or tlen > lout * 0.45:
		out.append(cur)
		return
	var t1: Vector2 = cur - vin * tlen
	var t2: Vector2 = cur + vout * tlen
	var dist: float = rad / sin(phi * 0.5)
	var center: Vector2 = cur + bis * dist
	var a0: float = atan2(t1.y - center.y, t1.x - center.x)
	var a1: float = atan2(t2.y - center.y, t2.x - center.x)
	var da: float = a1 - a0
	if da > PI:
		da -= TAU
	elif da < -PI:
		da += TAU
	out.append(t1)
	var steps: int = 3
	for s in range(1, steps):
		var ang: float = a0 + da * float(s) / float(steps)
		out.append(center + Vector2(cos(ang), sin(ang)) * rad)
	out.append(t2)


static func _fillet_points(pts: Array[Vector2], rng: RandomNumberGenerator, frac: float, per: int, kind: PackedByteArray, gw: int, gh: int) -> Array[Vector2]:
	var count: int = pts.size()
	if frac <= 0.0 or count < 4:
		return pts
	var corners: PackedInt32Array = PackedInt32Array()
	var min_arm: float = float(LONG_EDGE * per)
	for i in count:
		var prev: Vector2 = pts[(i + count - 1) % count]
		var cur: Vector2 = pts[i]
		var nxt: Vector2 = pts[(i + 1) % count]
		var vin: Vector2 = cur - prev
		var vout: Vector2 = nxt - cur
		var lin: float = vin.length()
		var lout: float = vout.length()
		if lin < 0.5 or lout < 0.5:
			continue
		if lin < min_arm and lout < min_arm:
			continue
		vin = vin / lin
		vout = vout / lout
		var cross: float = vin.x * vout.y - vin.y * vout.x
		if cross <= 0.08:
			continue
		corners.append(i)
	if corners.is_empty():
		return pts
	var want: int = int(round(frac * float(corners.size())))
	if want < 1:
		want = 1
	if want > corners.size():
		want = corners.size()
	for i in want:
		var j: int = i + (rng.randi() % (corners.size() - i))
		var swap: int = corners[i]
		corners[i] = corners[j]
		corners[j] = swap
	var picked: Dictionary = {}
	for i2 in want:
		var idx: int = int(corners[i2])
		var prev_i: int = (idx + count - 1) % count
		var next_i: int = (idx + 1) % count
		if picked.has(prev_i) or picked.has(next_i):
			continue
		picked[idx] = true
	var out: Array[Vector2] = []
	for i3 in count:
		if not bool(picked.get(i3, false)):
			out.append(pts[i3])
			continue
		_fillet_at(out, pts, i3, per, kind, gw, gh)
	if out.size() < 3:
		return pts
	return out


static func _sort_xs(xs: PackedFloat32Array) -> void:
	for i in range(1, xs.size()):
		var v: float = xs[i]
		var j: int = i
		while j > 0 and xs[j - 1] > v:
			xs[j] = xs[j - 1]
			j -= 1
		xs[j] = v


static func _fill(solid: PackedByteArray, sw: int, sh: int, poly: PackedVector2Array, value: int) -> void:
	var count: int = poly.size()
	if count < 3 or sw < 1 or sh < 1:
		return
	var y_min: int = sh
	var y_max: int = -1
	for i in count:
		var iy: int = int(floor(poly[i].y))
		if iy < y_min:
			y_min = iy
		if iy > y_max:
			y_max = iy
	if y_min < 0:
		y_min = 0
	if y_max >= sh:
		y_max = sh - 1
	if y_max < y_min:
		return
	for y in range(y_min, y_max + 1):
		var scan: float = float(y) + 0.5
		var xs: PackedFloat32Array = PackedFloat32Array()
		for e in count:
			var a: Vector2 = poly[e]
			var b: Vector2 = poly[(e + 1) % count]
			var lo: float = a.y if a.y < b.y else b.y
			var hi: float = b.y if b.y > a.y else a.y
			if scan < lo or scan >= hi:
				continue
			var t: float = (scan - a.y) / (b.y - a.y)
			xs.append(a.x + (b.x - a.x) * t)
		if xs.size() < 2:
			continue
		_sort_xs(xs)
		var k: int = 0
		var row: int = y * sw
		while k + 1 < xs.size():
			var left: float = xs[k]
			var right: float = xs[k + 1]
			var x_from: int = int(ceil(left - 0.5))
			var x_to: int = int(floor(right - 0.5))
			if x_from < 0:
				x_from = 0
			if x_to >= sw:
				x_to = sw - 1
			for x in range(x_from, x_to + 1):
				solid[row + x] = value
			k += 2


static func _spans_from_solid(solid: PackedByteArray, sw: int, sh: int) -> Array:
	var spans: Array = []
	if sw < 1 or sh < 1:
		return spans
	var used: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for y in sh:
		var row: int = y * sw
		for x in sw:
			if solid[row + x] == 0:
				continue
			for di in 4:
				var n: Vector2i = dirs[di]
				var nx: int = x + n.x
				var ny: int = y + n.y
				var outside: bool = nx < 0 or ny < 0 or nx >= sw or ny >= sh
				if not outside and solid[ny * sw + nx] != 0:
					continue
				var key: Vector3i = Vector3i(x, y, di)
				if bool(used.get(key, false)):
					continue
				var tan: Vector2i = Vector2i(absi(n.y), absi(n.x))
				var run_n: int = 1
				while true:
					var xx: int = x + tan.x * run_n
					var yy: int = y + tan.y * run_n
					if xx < 0 or yy < 0 or xx >= sw or yy >= sh:
						break
					if solid[yy * sw + xx] == 0:
						break
					var ox: int = xx + n.x
					var oy: int = yy + n.y
					var out2: bool = ox < 0 or oy < 0 or ox >= sw or oy >= sh
					if not out2 and solid[oy * sw + ox] != 0:
						break
					var nk: Vector3i = Vector3i(xx, yy, di)
					if bool(used.get(nk, false)):
						break
					run_n += 1
				for k in run_n:
					used[Vector3i(x + tan.x * k, y + tan.y * k, di)] = true
				var origin: Vector2 = Vector2(float(x), float(y))
				var delta: Vector2 = Vector2.ZERO
				var nrm: Vector2 = Vector2.ZERO
				var run_f: float = float(run_n) - 0.02
				if run_f < 0.5:
					run_f = 0.5
				if n.x == 1:
					origin = Vector2(float(x) + 0.99, float(y) + 0.01)
					delta = Vector2(0.0, run_f)
					nrm = Vector2(-1.0, 0.0)
				elif n.x == -1:
					origin = Vector2(float(x) + 0.01, float(y + run_n) - 0.01)
					delta = Vector2(0.0, -run_f)
					nrm = Vector2(1.0, 0.0)
				elif n.y == 1:
					origin = Vector2(float(x + run_n) - 0.01, float(y) + 0.99)
					delta = Vector2(-run_f, 0.0)
					nrm = Vector2(0.0, -1.0)
				else:
					origin = Vector2(float(x) + 0.01, float(y) + 0.01)
					delta = Vector2(run_f, 0.0)
					nrm = Vector2(0.0, 1.0)
				spans.append({"origin": origin, "delta": delta, "normal": nrm, "thick": 1.0})
	return spans


static func _push_loop(spans: Array, poly: PackedVector2Array) -> void:
	var count: int = poly.size()
	if count < 2 or _area(poly) <= 1.0:
		return
	for i in count:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var delta: Vector2 = b - a
		if delta.length_squared() < 0.25:
			continue
		var nrm: Vector2 = Vector2(-delta.y, delta.x)
		if nrm.length_squared() > 0.0001:
			nrm = nrm.normalized()
		spans.append({"origin": a, "delta": delta, "normal": nrm, "thick": 1.0})


static func _paint(solid: PackedByteArray, sw: int, sh: int, run: Dictionary) -> void:
	var o: Vector2 = run["origin"]
	var d: Vector2 = run["delta"]
	var span_l: float = d.length()
	if span_l < 0.5 or sw < 1 or sh < 1:
		return
	var steps: int = maxi(1, int(span_l))
	for si in range(steps + 1):
		var t: float = float(si) / float(steps)
		var p: Vector2 = o + d * t
		var fx: int = clampi(int(floor(p.x)), 0, sw - 1)
		var fy: int = clampi(int(floor(p.y)), 0, sh - 1)
		solid[fy * sw + fx] = 1


static func _keep_rooms(solid: PackedByteArray, sw: int, sh: int, rooms: Array, per: int) -> void:
	if per < 1 or sw < 1 or sh < 1:
		return
	for room_v in rooms:
		var room: Dictionary = room_v
		var cx: int = int(room["x"]) + int(int(room["w"]) / 2.0)
		var cy: int = int(room["y"]) + int(int(room["h"]) / 2.0)
		var fx: int = cx * per + int(float(per) / 2.0)
		var fy: int = cy * per + int(float(per) / 2.0)
		if fx < 0 or fy < 0 or fx >= sw or fy >= sh:
			continue
		solid[fy * sw + fx] = 1
