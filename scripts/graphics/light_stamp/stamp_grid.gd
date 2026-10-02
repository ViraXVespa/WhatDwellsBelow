extends Object

## Split from light_stamp.gd: _blit, _walk_mask, _lift_floor....

const K := preload("res://scripts/graphics/light_stamp/stamp_k.gd")

static var _rgba: PackedByteArray = PackedByteArray()
static var _walk_buf: PackedByteArray = PackedByteArray()
static var _floor_ix: PackedInt32Array = PackedInt32Array()
static var _floor_n: int = 0

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
		for d: Vector2i in K.DIRS:
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
		var fy: int = z0 * n + int((py * n) / float(K.SUB))
		if fy >= 0 and fy < sh:
			var srow: int = fy * sw
			var px: int = 0
			while px < iw:
				var fx: int = x0 * n + int((px * n) / float(K.SUB))
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
		for d: Vector2i in K.DIRS:
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
