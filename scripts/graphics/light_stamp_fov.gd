extends Object

## Split from light_stamp.gd: _disc, _fov_mark, _mark_ray....

const K := preload("res://scripts/graphics/light_stamp_k.gd")

static var _vis_buf: PackedByteArray = PackedByteArray()

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
	var rpx: int = int(ceil(reach * float(K.SUB)))
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
				var wx: float = float(x0) + (float(px) + 0.5) / float(K.SUB)
				var wz: float = float(z0) + (float(py) + 0.5) / float(K.SUB)
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

static func _seed(
	walk: PackedByteArray,
	iw: int,
	ih: int,
	mx: float,
	mz: float,
	x0: int,
	z0: int
) -> int:
	var cx: int = int(floor((mx - float(x0)) * float(K.SUB)))
	var cy: int = int(floor((mz - float(z0)) * float(K.SUB)))
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
