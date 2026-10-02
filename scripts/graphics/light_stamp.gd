extends Object

## Fine solid blocks. Discs flood walkable texels from the mount. Cold fill is those samples only.
## Falloff is straight-line meters on a clear segment. Wall mass blocks the disc.
## The walk mask is gen solid under the texel center. Loops do not replace that mask.
## A 4-neighbor does not open a cell past the lip.
## Wall texels stay dark except the neighbor sample along the bake. SUB stays 4.

const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const SUB := 4
const COL_FLOOR := Color(0.50, 0.56, 0.74)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _rgba: PackedByteArray = PackedByteArray()
static var _walk_buf: PackedByteArray = PackedByteArray()
static var _floor_ix: PackedInt32Array = PackedInt32Array()
static var _floor_n: int = 0
static var _vis_buf: PackedByteArray = PackedByteArray()
static var _rr_buf: PackedFloat32Array = PackedFloat32Array()
static var _gg_buf: PackedFloat32Array = PackedFloat32Array()
static var _bb_buf: PackedFloat32Array = PackedFloat32Array()

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
	HitchLog.mark("light_walk")
	if _rr_buf.size() != pxn:
		_rr_buf.resize(pxn)
		_gg_buf.resize(pxn)
		_bb_buf.resize(pxn)
	var rr: PackedFloat32Array = _rr_buf
	var gg: PackedFloat32Array = _gg_buf
	var bb: PackedFloat32Array = _bb_buf
	var zi: int = 0
	while zi < _floor_n:
		var fi: int = _floor_ix[zi]
		rr[fi] = 0.0
		gg[fi] = 0.0
		bb[fi] = 0.0
		zi += 1
	for src in lights:
		var item: Dictionary = src
		_disc(rr, gg, bb, walk, iw, ih, item, x0, z0, loops, n)
	HitchLog.mark("light_disc")
	_lift_floor(rr, gg, bb, walk, iw, ih, ambient, n)
	HitchLog.mark("light_lift")
	_walls(rr, gg, bb, walk, iw, ih, n)
	HitchLog.mark("light_walls")
	_blit(img, rr, gg, bb, walk, iw, ih)
	HitchLog.mark("light_blit")

static func _blit(
	img: Image,
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	walk: PackedByteArray,
	iw: int,
	ih: int
) -> void:
	var pxn: int = iw * ih
	if _rgba.size() != pxn * 4:
		_rgba.resize(pxn * 4)
	if _floor_n < 1:
		var i: int = 0
		while i < pxn:
			var o: int = i * 4
			_rgba[o] = int(minf(rr[i], 1.0) * 255.0 + 0.5)
			_rgba[o + 1] = int(minf(gg[i], 1.0) * 255.0 + 0.5)
			_rgba[o + 2] = int(minf(bb[i], 1.0) * 255.0 + 0.5)
			_rgba[o + 3] = 255
			i += 1
		img.set_data(iw, ih, false, Image.FORMAT_RGBA8, _rgba)
		return
	_rgba.fill(0)
	var k: int = 0
	while k < _floor_n:
		var i2: int = _floor_ix[k]
		var o2: int = i2 * 4
		_rgba[o2] = int(minf(rr[i2], 1.0) * 255.0 + 0.5)
		_rgba[o2 + 1] = int(minf(gg[i2], 1.0) * 255.0 + 0.5)
		_rgba[o2 + 2] = int(minf(bb[i2], 1.0) * 255.0 + 0.5)
		_rgba[o2 + 3] = 255
		var py: int = int(float(i2) / float(iw))
		var px: int = i2 - py * iw
		for d: Vector2i in DIRS:
			var npx: int = px + d.x
			var npy: int = py + d.y
			if npx < 0 or npy < 0 or npx >= iw or npy >= ih:
				continue
			var ni: int = npy * iw + npx
			if walk[ni] != 0:
				continue
			var no: int = ni * 4
			_rgba[no] = int(minf(rr[ni], 1.0) * 255.0 + 0.5)
			_rgba[no + 1] = int(minf(gg[ni], 1.0) * 255.0 + 0.5)
			_rgba[no + 2] = int(minf(bb[ni], 1.0) * 255.0 + 0.5)
			_rgba[no + 3] = 255
		k += 1
	img.set_data(iw, ih, false, Image.FORMAT_RGBA8, _rgba)

static func _walk_mask(
	solid: PackedByteArray,
	sw: int,
	sh: int,
	n: int,
	x0: int,
	z0: int,
	iw: int,
	ih: int,
	_loops: Array = []
) -> PackedByteArray:
	var need: int = iw * ih
	if _walk_buf.size() != need:
		_walk_buf.resize(need)
	if _floor_ix.size() != need:
		_floor_ix.resize(need)
	var walk: PackedByteArray = _walk_buf
	walk.fill(0)
	_floor_n = 0
	if n < 1:
		walk.fill(1)
		return walk
	if solid.is_empty() or sw < 1 or sh < 1:
		return walk
	var py: int = 0
	while py < ih:
		var row: int = py * iw
		var fy: int = z0 * n + (py * n) / SUB
		if fy >= 0 and fy < sh:
			var srow: int = fy * sw
			var px: int = 0
			while px < iw:
				var fx: int = x0 * n + (px * n) / SUB
				if fx >= 0 and fx < sw and solid[srow + fx] != 0:
					var i: int = row + px
					walk[i] = 1
					_floor_ix[_floor_n] = i
					_floor_n += 1
				px += 1
		py += 1
	return walk

static func _lift_floor(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	_walk: PackedByteArray,
	_iw: int,
	_ih: int,
	ambient: Color,
	n: int
) -> void:
	if n < 1:
		return
	if ambient.r <= 0.0 and ambient.g <= 0.0 and ambient.b <= 0.0:
		return
	var k: int = 0
	while k < _floor_n:
		var i: int = _floor_ix[k]
		rr[i] = minf(rr[i] + ambient.r, 1.0)
		gg[i] = minf(gg[i] + ambient.g, 1.0)
		bb[i] = minf(bb[i] + ambient.b, 1.0)
		k += 1

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
	_loops: Array = [],
	_n: int = 1
) -> void:
	var reach: float = float(src["reach"])
	if reach < 0.25:
		return
	var energy: float = float(src["energy"])
	var col: Color = src["col"] as Color
	var mx: float = float(src["mx"])
	var mz: float = float(src["mz"])
	var start_i: int = _seed(walk, iw, ih, mx, mz, x0, z0)
	if start_i < 0:
		return
	var sy: int = int(float(start_i) / float(iw))
	var sx: int = start_i - sy * iw
	var rpx: int = int(ceil(reach * float(SUB)))
	var py0: int = maxi(0, sy - rpx)
	var py1: int = mini(ih - 1, sy + rpx)
	var px0: int = maxi(0, sx - rpx)
	var px1: int = mini(iw - 1, sx + rpx)
	var block: bool = bool(src.get("occlude", true))
	if _n >= 1 and block:
		_fov_mark(walk, iw, ih, sx, sy, px0, py0, px1, py1)
	var py: int = py0
	while py <= py1:
		var row: int = py * iw
		var px: int = px0
		while px <= px1:
			var i: int = row + px
			if walk[i] != 0 and (_n < 1 or not block or _vis_buf[i] != 0):
				var wx: float = float(x0) + (float(px) + 0.5) / float(SUB)
				var wz: float = float(z0) + (float(py) + 0.5) / float(SUB)
				var dist: float = sqrt((wx - mx) * (wx - mx) + (wz - mz) * (wz - mz))
				if dist <= reach:
					var fall: float = energy * (1.0 - dist / reach)
					rr[i] = minf(rr[i] + col.r * fall, 1.0)
					gg[i] = minf(gg[i] + col.g * fall, 1.0)
					bb[i] = minf(bb[i] + col.b * fall, 1.0)
			px += 1
		py += 1

static func _fov_mark(
	walk: PackedByteArray,
	iw: int,
	ih: int,
	sx: int,
	sy: int,
	px0: int,
	py0: int,
	px1: int,
	py1: int
) -> void:
	var need: int = iw * ih
	if _vis_buf.size() != need:
		_vis_buf.resize(need)
		_vis_buf.fill(0)
	else:
		var zy: int = py0
		while zy <= py1:
			var zrow: int = zy * iw
			var zx: int = px0
			while zx <= px1:
				_vis_buf[zrow + zx] = 0
				zx += 1
			zy += 1
	var px: int = px0
	while px <= px1:
		_mark_ray(walk, iw, ih, sx, sy, px, py0)
		_mark_ray(walk, iw, ih, sx, sy, px, py1)
		px += 1
	var py: int = py0 + 1
	while py <= py1 - 1:
		_mark_ray(walk, iw, ih, sx, sy, px0, py)
		_mark_ray(walk, iw, ih, sx, sy, px1, py)
		py += 1

static func _mark_ray(
	walk: PackedByteArray,
	iw: int,
	ih: int,
	x0: int,
	y0: int,
	x1: int,
	y1: int
) -> void:
	if x0 < 0 or y0 < 0 or x0 >= iw or y0 >= ih:
		return
	if walk[y0 * iw + x0] == 0:
		return
	_vis_buf[y0 * iw + x0] = 1
	if x0 == x1 and y0 == y1:
		return
	var dx: int = x1 - x0
	var dy: int = y1 - y0
	var nx: int = absi(dx)
	var ny: int = absi(dy)
	var step_x: int = 0
	var step_y: int = 0
	if dx > 0:
		step_x = 1
	elif dx < 0:
		step_x = -1
	if dy > 0:
		step_y = 1
	elif dy < 0:
		step_y = -1
	var x: int = x0
	var y: int = y0
	var ix: int = 0
	var iy: int = 0
	while ix < nx or iy < ny:
		var decision: int = (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if decision == 0:
			var cx: int = x + step_x
			var cy: int = y + step_y
			if cx < 0 or cy < 0 or cx >= iw or cy >= ih:
				return
			if walk[y * iw + cx] == 0 or walk[cy * iw + x] == 0:
				return
			x = cx
			y = cy
			ix += 1
			iy += 1
		elif decision < 0:
			x += step_x
			ix += 1
		else:
			y += step_y
			iy += 1
		if x < 0 or y < 0 or x >= iw or y >= ih:
			return
		if walk[y * iw + x] == 0:
			return
		_vis_buf[y * iw + x] = 1

static func _walls(
	rr: PackedFloat32Array,
	gg: PackedFloat32Array,
	bb: PackedFloat32Array,
	walk: PackedByteArray,
	iw: int,
	ih: int,
	n: int
) -> void:
	if n < 1 or _floor_n < 1:
		return
	var k: int = 0
	while k < _floor_n:
		var i: int = _floor_ix[k]
		var py: int = int(float(i) / float(iw))
		var px: int = i - py * iw
		for d: Vector2i in DIRS:
			var npx: int = px + d.x
			var npy: int = py + d.y
			if npx < 0 or npy < 0 or npx >= iw or npy >= ih:
				continue
			var ni: int = npy * iw + npx
			if walk[ni] != 0:
				continue
			rr[ni] = maxf(rr[ni], rr[i])
			gg[ni] = maxf(gg[ni], gg[i])
			bb[ni] = maxf(bb[ni], bb[i])
		k += 1

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
