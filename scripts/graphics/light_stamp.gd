extends Object

## Fine solid blocks. Discs flood walkable texels from the mount. Cold fill is those samples only.
## The walk mask is the fine cell under the texel center. A 4-neighbor does not open a cell past the lip.
## Wall texels stay dark except the neighbor sample along the bake. SUB stays 4.

const SUB := 4
const COL_FLOOR := Color(0.50, 0.56, 0.74)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func solid_open(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	world_x: float,
	world_z: float
) -> bool:
	if n < 1 or solid.is_empty() or sw < 1 or sh < 1:
		return false
	var fx: int = int(floor(world_x * float(n)))
	var fy: int = int(floor(world_z * float(n)))
	if fx < 0 or fy < 0 or fx >= sw or fy >= sh:
		return false
	return solid[fy * sw + fx] != 0


static func near_open(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	world_x: float,
	world_z: float
) -> bool:
	if n < 1 or solid.is_empty():
		return true
	var step: float = 1.0 / float(SUB)
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var sx: float = world_x + float(ox) * step
			var sz: float = world_z + float(oy) * step
			if solid_open(solid, sw, sh, n, sx, sz):
				return true
	return false


static func paint(
	img: Image,
	tw: int,
	th: int,
	lights: Array,
	ambient: Color = Color(0, 0, 0, 1),
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 0,
	x0: int = 0,
	z0: int = 0,
	loops: Array = []
) -> void:
	var iw: int = tw * SUB
	var ih: int = th * SUB
	var pxn: int = iw * ih
	var walk: PackedByteArray = _walk_mask(solid, sw, sh, n, x0, z0, iw, ih, loops)
	var rr: PackedFloat32Array = PackedFloat32Array()
	var gg: PackedFloat32Array = PackedFloat32Array()
	var bb: PackedFloat32Array = PackedFloat32Array()
	rr.resize(pxn)
	gg.resize(pxn)
	bb.resize(pxn)
	rr.fill(0.0)
	gg.fill(0.0)
	bb.fill(0.0)
	for src in lights:
		var item: Dictionary = src
		_disc(rr, gg, bb, walk, iw, ih, item, x0, z0, loops, n)
	_lift_floor(rr, gg, bb, walk, iw, ih, ambient, n)
	_walls(rr, gg, bb, walk, iw, ih, n)
	for y in ih:
		for x in iw:
			var i: int = y * iw + x
			if rr[i] <= 0.0 and gg[i] <= 0.0 and bb[i] <= 0.0:
				continue
			img.set_pixel(x, y, Color(rr[i], gg[i], bb[i], 1.0))


static func _walk_mask(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	x0: int,
	z0: int,
	iw: int,
	ih: int,
	loops: Array = []
) -> PackedByteArray:
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(iw * ih)
	if n < 1:
		walk.fill(1)
		return walk
	if not loops.is_empty():
		_fill_loops(walk, loops, x0, z0, iw, ih, n)
		return walk
	for py in ih:
		var row: int = py * iw
		for px in iw:
			if _lip_open(solid, sw, sh, n, x0, z0, px, py, loops):
				walk[row + px] = 1
	return walk


static func _fill_loops(
	walk: PackedByteArray,
	loops: Array,
	x0: int,
	z0: int,
	iw: int,
	ih: int,
	n: int
) -> void:
	var nf: float = float(maxi(n, 1))
	var sub: float = float(SUB)
	for item in loops:
		var poly: PackedVector2Array = item as PackedVector2Array
		if poly.size() < 3:
			continue
		var min_x: float = poly[0].x
		var max_x: float = poly[0].x
		var min_z: float = poly[0].y
		var max_z: float = poly[0].y
		for i in range(1, poly.size()):
			var q: Vector2 = poly[i]
			min_x = minf(min_x, q.x)
			max_x = maxf(max_x, q.x)
			min_z = minf(min_z, q.y)
			max_z = maxf(max_z, q.y)
		var px0: int = clampi(int(floor((min_x / nf - float(x0)) * sub)), 0, iw - 1)
		var px1: int = clampi(int(ceil((max_x / nf - float(x0)) * sub)), 0, iw - 1)
		var py0: int = clampi(int(floor((min_z / nf - float(z0)) * sub)), 0, ih - 1)
		var py1: int = clampi(int(ceil((max_z / nf - float(z0)) * sub)), 0, ih - 1)
		var py: int = py0
		while py <= py1:
			var row: int = py * iw
			var px: int = px0
			while px <= px1:
				var fx: float = (float(x0) + (float(px) + 0.5) / sub) * nf
				var fz: float = (float(z0) + (float(py) + 0.5) / sub) * nf
				if Geometry2D.is_point_in_polygon(Vector2(fx, fz), poly):
					walk[row + px] = 1
				px += 1
			py += 1


static func _lift_floor(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	walk: PackedByteArray,
	iw: int,
	ih: int,
	ambient: Color,
	n: int
) -> void:
	if n < 1:
		return
	if ambient.r <= 0.0 and ambient.g <= 0.0 and ambient.b <= 0.0:
		return
	for py in ih:
		var row: int = py * iw
		for px in iw:
			var i: int = row + px
			if walk[i] == 0:
				continue
			rr[i] = minf(rr[i] + ambient.r, 1.0)
			gg[i] = minf(gg[i] + ambient.g, 1.0)
			bb[i] = minf(bb[i] + ambient.b, 1.0)


static func _disc(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	walk: PackedByteArray,
	iw: int,
	ih: int,
	src: Dictionary,
	x0: int,
	z0: int,
	loops: Array = [],
	n: int = 1
) -> void:
	var reach: float = float(src["reach"])
	if reach < 0.25:
		return
	var energy: float = float(src["energy"])
	var col: Color = src["col"] as Color
	var mx: float = float(src["mx"])
	var mz: float = float(src["mz"])
	var seed: int = _seed(walk, iw, ih, mx, mz, x0, z0)
	if seed < 0:
		return
	var home: Array = _loops_at(loops, n, mx, mz)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(iw * ih)
	var q: PackedInt32Array = PackedInt32Array()
	q.resize(iw * ih)
	var head: int = 0
	var tail: int = 0
	seen[seed] = 1
	q[tail] = seed
	tail += 1
	while head < tail:
		var i: int = q[head]
		head += 1
		var py: int = int(float(i) / float(iw))
		var px: int = i - py * iw
		var wx: float = float(x0) + (float(px) + 0.5) / float(SUB)
		var wz: float = float(z0) + (float(py) + 0.5) / float(SUB)
		var dist: float = sqrt((wx - mx) * (wx - mx) + (wz - mz) * (wz - mz))
		if dist <= reach:
			var fall: float = energy * (1.0 - dist / reach)
			rr[i] = minf(rr[i] + col.r * fall, 1.0)
			gg[i] = minf(gg[i] + col.g * fall, 1.0)
			bb[i] = minf(bb[i] + col.b * fall, 1.0)
		for d: Vector2i in DIRS:
			var npx: int = px + d.x
			var npy: int = py + d.y
			if npx < 0 or npy < 0 or npx >= iw or npy >= ih:
				continue
			var ni: int = npy * iw + npx
			if seen[ni] != 0 or walk[ni] == 0:
				continue
			var nwx: float = float(x0) + (float(npx) + 0.5) / float(SUB)
			var nwz: float = float(z0) + (float(npy) + 0.5) / float(SUB)
			if not home.is_empty() and not _inside_loops(home, nwx * float(maxi(n, 1)), nwz * float(maxi(n, 1))):
				continue
			var nd: float = sqrt((nwx - mx) * (nwx - mx) + (nwz - mz) * (nwz - mz))
			if nd > reach:
				continue
			seen[ni] = 1
			q[tail] = ni
			tail += 1


static func _walls(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	walk: PackedByteArray,
	iw: int,
	ih: int,
	n: int
) -> void:
	if n < 1:
		return
	for py in ih:
		var row: int = py * iw
		for px in iw:
			var i: int = row + px
			if walk[i] != 0:
				continue
			var br: float = 0.0
			var bg: float = 0.0
			var bv: float = 0.0
			for d: Vector2i in DIRS:
				var npx: int = px + d.x
				var npy: int = py + d.y
				if npx < 0 or npy < 0 or npx >= iw or npy >= ih:
					continue
				var ni: int = npy * iw + npx
				if walk[ni] == 0:
					continue
				br = maxf(br, rr[ni])
				bg = maxf(bg, gg[ni])
				bv = maxf(bv, bb[ni])
			if br <= 0.0 and bg <= 0.0 and bv <= 0.0:
				continue
			rr[i] = br
			gg[i] = bg
			bb[i] = bv


static func _lip_open(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	x0: int,
	z0: int,
	px: int,
	py: int,
	loops: Array = []
) -> bool:
	if n < 1:
		return true
	var world_x: float = float(x0) + (float(px) + 0.5) / float(SUB)
	var world_z: float = float(z0) + (float(py) + 0.5) / float(SUB)
	if not loops.is_empty():
		return _inside_loops(loops, world_x * float(maxi(n, 1)), world_z * float(maxi(n, 1)))
	return solid_open(solid, sw, sh, n, world_x, world_z)


static func _inside_loops(loops: Array, fx: float, fz: float) -> bool:
	var p: Vector2 = Vector2(fx, fz)
	for item in loops:
		var poly: PackedVector2Array = item as PackedVector2Array
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


static func _past_span(spans: Array, world_x: float, world_z: float) -> bool:
	if spans.is_empty():
		return false
	var p: Vector2 = Vector2(world_x, world_z)
	for item in spans:
		if not (item is Dictionary):
			continue
		var run: Dictionary = item
		if not run.has("delta"):
			continue
		var o: Vector2 = run["origin"] as Vector2
		var d: Vector2 = run["delta"] as Vector2
		var sl: float = d.length_squared()
		if sl < 0.04:
			continue
		var nrm: Vector2 = run["normal"] as Vector2
		if nrm.length_squared() < 0.0001:
			nrm = Vector2(-d.y, d.x)
		if nrm.length_squared() < 0.0001:
			continue
		nrm = nrm.normalized()
		var t: float = clampf((p - o).dot(d) / sl, 0.0, 1.0)
		var hit: Vector2 = o + d * t
		if p.distance_to(hit) > 1.25:
			continue
		if (p - o).dot(nrm) < 0.0:
			return true
	return false


static func _loops_at(loops: Array, n: int, wx: float, wz: float) -> Array:
	var hit: Array = []
	var fx: float = wx * float(maxi(n, 1))
	var fz: float = wz * float(maxi(n, 1))
	for item in loops:
		var poly: PackedVector2Array = item as PackedVector2Array
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(fx, fz), poly):
			hit.append(item)
	return hit


static func _loop_segs(loops: Array, n: int) -> Array:
	var segs: Array = []
	for item in loops:
		var poly: PackedVector2Array = item as PackedVector2Array
		var count: int = poly.size()
		if count < 2:
			continue
		var prev: Vector2 = poly[count - 1]
		for i in count:
			var cur: Vector2 = poly[i]
			var d: Vector2 = cur - prev
			if d.length_squared() >= 0.04:
				var s: float = 1.0 / float(maxi(n, 1))
				segs.append(prev * s)
				segs.append(cur * s)
			prev = cur
	return segs


static func _span_hit(segs: Array, ax: float, az: float, bx: float, bz: float) -> bool:
	var count: int = segs.size()
	if count < 2:
		return false
	var a: Vector2 = Vector2(ax, az)
	var b: Vector2 = Vector2(bx, bz)
	if a.distance_to(b) < 0.05:
		return false
	var minx: float = minf(a.x, b.x)
	var maxx: float = maxf(a.x, b.x)
	var minz: float = minf(a.y, b.y)
	var maxz: float = maxf(a.y, b.y)
	var i: int = 0
	while i + 1 < count:
		var c: Vector2 = segs[i]
		var d: Vector2 = segs[i + 1]
		i += 2
		if maxf(c.x, d.x) < minx or minf(c.x, d.x) > maxx:
			continue
		if maxf(c.y, d.y) < minz or minf(c.y, d.y) > maxz:
			continue
		if _seg_cross(a, b, c, d):
			return true
	return false


static func _seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var den: float = ab.x * cd.y - ab.y * cd.x
	if absf(den) < 0.0000001:
		return false
	var ac: Vector2 = c - a
	var t: float = (ac.x * cd.y - ac.y * cd.x) / den
	var u: float = (ac.x * ab.y - ac.y * ab.x) / den
	if t <= 0.04 or t >= 0.96 or u <= 0.02 or u >= 0.98:
		return false
	var hit: Vector2 = a + ab * t
	if hit.distance_to(a) < 1.6 or hit.distance_to(b) < 1.6:
		return false
	return true


static func _seed(
	walk: PackedByteArray,
	iw: int,
	ih: int,
	mx: float,
	mz: float,
	x0: int,
	z0: int
) -> int:
	var cx: int = int(floor((mx - float(x0)) * float(SUB)))
	var cy: int = int(floor((mz - float(z0)) * float(SUB)))
	for rad in range(0, 3):
		for oy in range(-rad, rad + 1):
			for ox in range(-rad, rad + 1):
				if rad > 0 and absi(ox) != rad and absi(oy) != rad:
					continue
				var px: int = cx + ox
				var py: int = cy + oy
				if px < 0 or py < 0 or px >= iw or py >= ih:
					continue
				if walk[py * iw + px] != 0:
					return py * iw + px
	return -1
