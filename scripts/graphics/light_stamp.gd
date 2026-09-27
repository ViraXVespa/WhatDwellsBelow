extends Object

## One occupancy pass, then disc stamps. Dungeon walkable floor gets a cold fill.
## WALL blocks. Floor, door, opening, and stairs pass. Pits stay black.

const Gen := preload("res://scripts/dungeon/gen.gd")

const SUB := 4
const COL_FLOOR := Color(0.50, 0.56, 0.74)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func occupancy(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	x0: int,
	z0: int,
	tw: int,
	th: int,
	open_cells: Dictionary,
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 1
) -> PackedByteArray:
	var occ: PackedByteArray = PackedByteArray()
	occ.resize(tw * th)
	for tz in th:
		for tx in tw:
			var cx: int = x0 + tx
			var cz: int = z0 + tz
			var block: int = 1
			if _pass(grid, map_w, map_h, cx, cz, open_cells):
				block = 0
			elif _fine_walk(solid, sw, sh, n, cx, cz):
				block = 0
			occ[tz * tw + tx] = block
	return occ


static func paint(
	img: Image,
	occ: PackedByteArray,
	tw: int,
	th: int,
	lights: Array,
	ambient: Color = Color(0, 0, 0, 1),
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 1,
	x0: int = 0,
	z0: int = 0
) -> void:
	var iw: int = tw * SUB
	var ih: int = th * SUB
	var n: int = iw * ih
	var rr: PackedFloat32Array = PackedFloat32Array()
	var gg: PackedFloat32Array = PackedFloat32Array()
	var bb: PackedFloat32Array = PackedFloat32Array()
	rr.resize(n)
	gg.resize(n)
	bb.resize(n)
	rr.fill(0.0)
	gg.fill(0.0)
	bb.fill(0.0)
	for src in lights:
		_disc(rr, gg, bb, occ, tw, th, src, solid, sw, sh, n, x0, z0)
	_walls(rr, gg, bb, occ, tw, th)
	_lift_floor(rr, gg, bb, occ, tw, th, ambient, solid, sw, sh, n, x0, z0)
	for y in ih:
		for x in iw:
			var i: int = y * iw + x
			if rr[i] <= 0.0 and gg[i] <= 0.0 and bb[i] <= 0.0:
				continue
			img.set_pixel(x, y, Color(rr[i], gg[i], bb[i], 1.0))


static func _lift_floor(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	occ: PackedByteArray,
	tw: int,
	th: int,
	ambient: Color,
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 1,
	x0: int = 0,
	z0: int = 0
) -> void:
	if ambient.r <= 0.0 and ambient.g <= 0.0 and ambient.b <= 0.0:
		return
	var iw: int = tw * SUB
	for y in th:
		for x in tw:
			if occ[y * tw + x] != 0 and solid.is_empty():
				continue
			for sy in SUB:
				for sx in SUB:
					if not _sub_walk(solid, sw, sh, n, x0 + x, z0 + y, sx, sy):
						continue
					var i: int = (y * SUB + sy) * iw + x * SUB + sx
					rr[i] = minf(rr[i] + ambient.r, 1.0)
					gg[i] = minf(gg[i] + ambient.g, 1.0)
					bb[i] = minf(bb[i] + ambient.b, 1.0)


static func _sub_walk(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	cx: int,
	cz: int,
	sx: int,
	sy: int
) -> bool:
	if solid.is_empty() or n < 1 or sw < 1 or sh < 1:
		return true
	var fx: int = cx * n + int(sx * n / SUB)
	var fy: int = cz * n + int(sy * n / SUB)
	if fx < 0 or fy < 0 or fx >= sw or fy >= sh:
		return false
	return solid[fy * sw + fx] != 0

static func _pass(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	x: int,
	y: int,
	open_cells: Dictionary
) -> bool:
	var cell: Vector2i = Vector2i(x, y)
	if open_cells.has(cell):
		return true
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return false
	if grid.is_empty():
		return true
	return grid[y * map_w + x] == Gen.FLOOR


static func _fine_walk(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	cx: int,
	cz: int
) -> bool:
	if solid.is_empty() or n < 1 or sw < 1 or sh < 1:
		return false
	var fx0: int = cx * n
	var fz0: int = cz * n
	for dz in n:
		var fy: int = fz0 + dz
		if fy < 0 or fy >= sh:
			continue
		var row: int = fy * sw
		for dx in n:
			var fx: int = fx0 + dx
			if fx < 0 or fx >= sw:
				continue
			if solid[row + fx] != 0:
				return true
	return false


static func _disc(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	occ: PackedByteArray,
	tw: int,
	th: int,
	src: Dictionary,
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 1,
	x0: int = 0,
	z0: int = 0
) -> void:
	var sx: int = int(src["tx"])
	var sy: int = int(src["tz"])
	if sx < 0 or sy < 0 or sx >= tw or sy >= th:
		return
	if occ[sy * tw + sx] != 0:
		return
	var reach: float = float(src["reach"])
	if reach < 0.25:
		return
	var energy: float = float(src["energy"])
	var col: Color = src["col"]
	var q: Array[Vector2i] = [Vector2i(sx, sy)]
	var seen: Dictionary = {Vector2i(sx, sy): true}
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var dx: float = float(c.x - sx)
		var dy: float = float(c.y - sy)
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist > reach + 1.0:
			continue
		_paint_tile(rr, gg, bb, tw, c.x, c.y, sx, sy, reach, energy, col, solid, sw, sh, n, x0, z0)
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= tw or n.y >= th:
				continue
			if seen.has(n):
				continue
			if occ[n.y * tw + n.x] != 0:
				continue
			var ndx: float = float(n.x - sx)
			var ndy: float = float(n.y - sy)
			if sqrt(ndx * ndx + ndy * ndy) > reach + 1.0:
				continue
			seen[n] = true
			q.append(n)


static func _paint_tile(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	tw: int,
	tile_x: int,
	tile_y: int,
	src_x: int,
	src_y: int,
	reach: float,
	energy: float,
	col: Color,
	solid: PackedByteArray = PackedByteArray(),
	sw: int = 0,
	sh: int = 0,
	n: int = 1,
	x0: int = 0,
	z0: int = 0
) -> void:
	var iw: int = tw * SUB
	var cx: float = float(src_x) + 0.5
	var cz: float = float(src_y) + 0.5
	for sy in SUB:
		for sx in SUB:
			var px: int = tile_x * SUB + sx
			var py: int = tile_y * SUB + sy
			if not _sub_walk(solid, sw, sh, n, x0 + tile_x, z0 + tile_y, sx, sy):
				continue
			var wx: float = (float(px) + 0.5) / float(SUB)
			var wz: float = (float(py) + 0.5) / float(SUB)
			var dist: float = sqrt((wx - cx) * (wx - cx) + (wz - cz) * (wz - cz))
			if dist > reach:
				continue
			var fall: float = energy * (1.0 - dist / reach)
			var i: int = py * iw + px
			rr[i] = minf(rr[i] + col.r * fall, 1.0)
			gg[i] = minf(gg[i] + col.g * fall, 1.0)
			bb[i] = minf(bb[i] + col.b * fall, 1.0)


static func _walls(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	occ: PackedByteArray,
	tw: int,
	th: int
) -> void:
	var iw: int = tw * SUB
	for y in th:
		for x in tw:
			var ti: int = y * tw + x
			if occ[ti] == 0:
				continue
			var br: float = 0.0
			var bg: float = 0.0
			var bv: float = 0.0
			for d: Vector2i in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= tw or ny >= th:
					continue
				if occ[ny * tw + nx] != 0:
					continue
				var edge: Vector3 = _edge_max(rr, gg, bb, iw, nx, ny, -d)
				br = maxf(br, edge.x)
				bg = maxf(bg, edge.y)
				bv = maxf(bv, edge.z)
			if br <= 0.0 and bg <= 0.0 and bv <= 0.0:
				continue
			for sy in SUB:
				for sx in SUB:
					var i: int = (y * SUB + sy) * iw + x * SUB + sx
					rr[i] = br
					gg[i] = bg
					bb[i] = bv


static func _edge_max(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	iw: int,
	tile_x: int,
	tile_y: int,
	toward: Vector2i
) -> Vector3:
	var br: float = 0.0
	var bg: float = 0.0
	var bv: float = 0.0
	var sx0: int = 0
	var sy0: int = 0
	if toward.x > 0:
		sx0 = SUB - 1
	elif toward.y > 0:
		sy0 = SUB - 1
	for k in SUB:
		var sx: int = sx0
		var sy: int = sy0
		if toward.x != 0:
			sy = k
		else:
			sx = k
		var i: int = (tile_y * SUB + sy) * iw + tile_x * SUB + sx
		br = maxf(br, rr[i])
		bg = maxf(bg, gg[i])
		bv = maxf(bv, bb[i])
	return Vector3(br, bg, bv)
