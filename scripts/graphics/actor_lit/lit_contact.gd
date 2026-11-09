extends Object

## Per-column contact lift for the mark shader (lit_k contact_tex): for each texel column of a grounded boot (lowest
## opaque texel within RAISED_M of that foot's lowest pixel, on its side of the feet split), the v distance from its
## own lowest texel to the contact row. The shader reads that column that much higher, so every grounded sole (toe and
## heel) starts the cast; legs and raised feet read 0. Cached per texture.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
static var _cache: Dictionary = {}
## Lowest opaque row per column, keyed by texture rid. The row texture above still depends on px.
static var _cols: Dictionary = {}
static var _col_h: Dictionary = {}

## flat: the debug plant (actor_lit.plant_flat), a higher standing foot read as raised.
static func tex(t: Texture2D, soles: Vector4, px: float, flat := false) -> Texture2D:
	var rid: int = t.get_rid().get_id()
	var key: String = "%d:%.5f:%s" % [rid, px, flat]
	if _cache.has(key):
		return _cache[key]
	var lows: PackedInt32Array = _columns(t, rid)
	var w: int = lows.size()
	var rows: int = int(_col_h.get(rid, maxi(1, t.get_height())))
	if w < 1 or rows < 1:
		var blank: Image = Image.create(1, 1, false, Image.FORMAT_RF)
		var empty: ImageTexture = ImageTexture.create_from_image(blank)
		_cache[key] = empty
		return empty
	var up: float = K.RAISED_M / maxf(px, 1e-5)
	var sole_y: float = maxf(soles.y, soles.w)
	var split: float = (soles.x + soles.z) * 0.5
	var out: Image = Image.create(w, 1, false, Image.FORMAT_RF)
	for x in w:
		var left: bool = (float(x) < split) == (soles.x <= soles.z)
		var fy: float = soles.y if left else soles.w
		var dv: float = 0.0
		if sole_y - fy < up and not (flat and fy < sole_y):  # this side's foot is grounded
			var low: int = int(lows[x])
			if low >= 0 and fy - float(low) < up:
				dv = (sole_y - float(low)) / float(rows)
		out.set_pixel(x, 0, Color(dv, 0.0, 0.0))
	var made: ImageTexture = ImageTexture.create_from_image(out)
	if _cache.size() > 512:
		_cache.clear()
	_cache[key] = made
	return made


## One pass over the sticker bytes. A repeat of the same texture does not call get_pixel.
static func _columns(t: Texture2D, rid: int) -> PackedInt32Array:
	if _cols.has(rid):
		return _cols[rid]
	var img: Image = t.get_image()
	var w: int = 1 if img == null else img.get_width()
	var rows: int = 1 if img == null else img.get_height()
	var lows: PackedInt32Array = PackedInt32Array()
	lows.resize(maxi(w, 0))
	lows.fill(-1)
	if img != null and not img.is_empty():
		if img.is_compressed() or img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
		w = img.get_width()
		rows = img.get_height()
		if lows.size() != w:
			lows.resize(w)
			lows.fill(-1)
		var bytes: PackedByteArray = img.get_data()
		if bytes.size() >= w * rows * 4:
			var pending: int = w
			for y in range(rows - 1, -1, -1):
				if pending <= 0:
					break
				var row: int = y * w * 4
				for x in w:
					if lows[x] >= 0:
						continue
					if bytes[row + x * 4 + 3] >= 128:
						lows[x] = y
						pending -= 1
	if _cols.size() > 512:
		_cols.clear()
		_col_h.clear()
	_cols[rid] = lows
	_col_h[rid] = rows
	return lows
