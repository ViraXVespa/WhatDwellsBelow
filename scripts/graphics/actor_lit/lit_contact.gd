extends Object

## Per-column contact lift for the mark shader (lit_k contact_tex): for each texel column of a grounded boot (lowest
## opaque texel within RAISED_M of that foot's lowest pixel, on its side of the feet split), the v distance from its
## own lowest texel to the contact row. The shader reads that column that much higher, so every grounded sole (toe and
## heel) starts the cast; legs and raised feet read 0. Cached per texture.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
static var _cache: Dictionary = {}

## flat: the debug plant (actor_lit.plant_flat), a higher standing foot read as raised.
static func tex(t: Texture2D, soles: Vector4, px: float, flat := false) -> Texture2D:
	var key: String = "%d:%.5f:%s" % [t.get_rid().get_id(), px, flat]
	if _cache.has(key):
		return _cache[key]
	var img: Image = t.get_image()
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var up: float = K.RAISED_M / maxf(px, 1e-5)
	var sole_y: float = maxf(soles.y, soles.w)
	var split: float = (soles.x + soles.z) * 0.5
	var out: Image = Image.create(w, 1, false, Image.FORMAT_RF)
	for x in w:
		var left: bool = (float(x) < split) == (soles.x <= soles.z)
		var fy: float = soles.y if left else soles.w
		var dv: float = 0.0
		if sole_y - fy < up and not (flat and fy < sole_y):  # this side's foot is grounded
			var low: int = _low(img, x)
			if low >= 0 and fy - float(low) < up:
				dv = (sole_y - float(low)) / float(h)
		out.set_pixel(x, 0, Color(dv, 0.0, 0.0))
	var made: ImageTexture = ImageTexture.create_from_image(out)
	if _cache.size() > 512:
		_cache.clear()
	_cache[key] = made
	return made

static func _low(img: Image, x: int) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		if img.get_pixel(x, y).a >= 0.5:
			return y
	return -1
