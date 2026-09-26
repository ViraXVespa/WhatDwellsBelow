extends Object

## One occupancy pass, then disc stamps. WALL blocks. Floor, door, opening, and stairs pass.

const Gen := preload("res://scripts/dungeon/gen.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func occupancy(
	grid: PackedByteArray,
	map_w: int,
	map_h: int,
	x0: int,
	z0: int,
	tw: int,
	th: int,
	open_cells: Dictionary
) -> PackedByteArray:
	var occ: PackedByteArray = PackedByteArray()
	occ.resize(tw * th)
	for tz in th:
		for tx in tw:
			var cx: int = x0 + tx
			var cz: int = z0 + tz
			var block: int = 0
			if _pass(grid, map_w, map_h, cx, cz, open_cells):
				block = 0
			else:
				block = 1
			occ[tz * tw + tx] = block
	return occ


static func paint(img: Image, occ: PackedByteArray, tw: int, th: int, lights: Array) -> void:
	var n: int = tw * th
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
		_disc(rr, gg, bb, occ, tw, th, src)
	_walls(rr, gg, bb, occ, tw, th)
	for y in th:
		for x in tw:
			var i: int = y * tw + x
			img.set_pixel(x, y, Color(rr[i], gg[i], bb[i], 1.0))


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


static func _disc(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	occ: PackedByteArray,
	tw: int,
	th: int,
	src: Dictionary
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
		if dist > reach:
			continue
		var fall: float = energy * (1.0 - dist / reach)
		var i: int = c.y * tw + c.x
		rr[i] = minf(rr[i] + col.r * fall, 1.0)
		gg[i] = minf(gg[i] + col.g * fall, 1.0)
		bb[i] = minf(bb[i] + col.b * fall, 1.0)
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
			if sqrt(ndx * ndx + ndy * ndy) > reach:
				continue
			seen[n] = true
			q.append(n)


static func _walls(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	occ: PackedByteArray,
	tw: int,
	th: int
) -> void:
	var sr: PackedFloat32Array = rr.duplicate()
	var sg: PackedFloat32Array = gg.duplicate()
	var sb: PackedFloat32Array = bb.duplicate()
	for y in th:
		for x in tw:
			var i: int = y * tw + x
			if occ[i] == 0:
				continue
			var br: float = 0.0
			var bg: float = 0.0
			var bv: float = 0.0
			for d: Vector2i in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= tw or ny >= th:
					continue
				var j: int = ny * tw + nx
				if occ[j] != 0:
					continue
				br = maxf(br, sr[j])
				bg = maxf(bg, sg[j])
				bv = maxf(bv, sb[j])
			if br > 0.0 or bg > 0.0 or bv > 0.0:
				rr[i] = br
				gg[i] = bg
				bb[i] = bv
