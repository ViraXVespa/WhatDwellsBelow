extends RefCounted

## Mark-matrix mask half (mark_matrix.gd): the mark silhouette (lit_emis: see-through and glowing pixels cut) at
## the ground cell scale, its detached pieces and enclosed holes, and the contact-sheet tile.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Emis := preload("res://scripts/graphics/actor_lit/lit_emis.gd")
const CELL := K.GRID_M
## Sizes in metres (a 1/64 m cell era: 3 and 2 cells), counted in cells of the current grid.
const CHUNK := int(ceil(0.047 / CELL))
const HOLE := int(ceil(0.031 / CELL))
const DRAWN := 0.02

## Mark mask (sprite alpha) at the ground cell scale: detached pieces and enclosed holes
## beyond those the art itself has (a cell as fine as the texel keeps the art's own gaps).
## kind_rule: the kind's K.GLOW rule; glowing pixels left in the mark show as glow=N.
static func faults(tex: Texture2D, px: float, plant: bool, rule: String = "", kind_rule: String = "") -> PackedStringArray:
	var raw: Image = tex.get_image()
	var base: Array = _count(raw, 1.0, false, 0.5)
	var img: Image = Emis.image(raw, rule)
	var got: Array = _count(img, maxf(1.0, CELL / px), plant, DRAWN)
	var out: PackedStringArray = PackedStringArray()
	if kind_rule != "" and kind_rule != rule:
		var lit: int = _opaque(img) - _opaque(Emis.image(raw, kind_rule))
		if lit >= CHUNK:
			out.append("glow=%d" % lit)
	if got[0] > base[0]:
		out.append("chunk=%d" % got[2])
	if got[1] > base[1]:
		out.append("hole=%d" % got[3])
	return out

static func _opaque(img: Image) -> int:
	var im: Image = img.duplicate()
	im.convert(Image.FORMAT_RGBA8)
	var n := 0
	var d: PackedByteArray = im.get_data()
	for i in range(3, d.size(), 4):
		n += 1 if d[i] > 127 else 0
	return n

## [chunks, holes, largest chunk, largest hole] of img alpha > cut, downscaled by f.
static func _count(src: Image, f: float, plant: bool, cut: float) -> Array:
	var img: Image = src.duplicate()
	var w: int = maxi(1, roundi(img.get_width() / f))
	var h: int = maxi(1, roundi(img.get_height() / f))
	img.convert(Image.FORMAT_RGBA8)
	if f > 1.0:
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var on: PackedByteArray = PackedByteArray()
	on.resize(w * h)
	for i in w * h:
		on[i] = 1 if img.get_pixel(i % w, i / w).a > cut else 0
	if plant:
		on[0] = 1; on[1] = 1; on[w] = 1; on[w + 1] = 1
	var r: Array = [0, 0, 0, 0]
	var pieces: Array = _parts(on, w, h, 1)
	pieces.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(1, pieces.size()):
		if pieces[i][0] >= CHUNK:
			r[0] += 1; r[2] = maxi(r[2], pieces[i][0])
	for hole: Array in _parts(on, w, h, 0):
		if not hole[1] and hole[0] >= HOLE:
			r[1] += 1; r[3] = maxi(r[3], hole[0])
	return r

## [size, touches_border] per 4-connected component of value v.
static func _parts(on: PackedByteArray, w: int, h: int, v: int) -> Array:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for start in w * h:
		if on[start] != v or seen[start]:
			continue
		var stack: Array[int] = [start]
		seen[start] = 1
		var size := 0
		var edge := false
		while not stack.is_empty():
			var i: int = stack.pop_back()
			size += 1
			var x: int = i % w
			var y: int = i / w
			edge = edge or x == 0 or y == 0 or x == w - 1 or y == h - 1
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < w * h and on[j] == v and not seen[j]:
					seen[j] = 1
					stack.append(j)
		out.append([size, edge])
	return out

static func tile(sheet: Image, n: int, tex: Texture2D, ok: bool, TILE: Vector2i) -> void:
	var img: Image = tex.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE.x, TILE.y - 4, Image.INTERPOLATE_NEAREST)
	var at := Vector2i((n % 32) * TILE.x, (n / 32) * TILE.y)
	sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.fill_rect(Rect2i(at + Vector2i(0, TILE.y - 4), Vector2i(TILE.x, 4)), Color.GREEN if ok else Color.RED)
