extends Object

## Hub art at the ground's pixel size: the ground's visible pixel is GRID_M (1/32 m, 4 texels of the 128 px/m
## sheets). A sprite whose texel is finer (pixel_size < GRID_M) is shrunk to that grid (nearest colour, box coverage; tools key.pixelate crisp) and nearest-scaled
## back to its own size, so texel rects (lamps, window, crop) still hold. Cached per texture and size.

const GRID_M := 1.0 / 32.0
static var _cache: Dictionary = {}

static func tex(t: Texture2D, px_m: float) -> Texture2D:
	if t == null or px_m <= 0.0:
		return t
	var f: float = GRID_M / px_m
	if f < 1.3:
		return t
	var key: String = "%d:%.4f" % [t.get_rid().get_id(), f]
	if _cache.has(key):
		return _cache[key]
	var img: Image = t.get_image()
	if img == null:
		return t
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var tw: int = maxi(1, roundi(w / f))
	var th: int = maxi(1, roundi(h / f))
	var small: Image = img.duplicate()
	small.premultiply_alpha()
	while small.get_width() >= tw * 2 and small.get_height() >= th * 2:
		small.resize(small.get_width() / 2, small.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	small.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var pick: Image = img.duplicate()
	pick.resize(tw, th, Image.INTERPOLATE_NEAREST)
	_crisp(small, pick)
	small.resize(w, h, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(small)
	# Keeps the source name readable (checks find the face art by path) without stealing the source's cache slot.
	if t.resource_path != "":
		out.resource_path = "%s::chunky_%s" % [t.resource_path, key.replace(":", "_").replace(".", "_")]
	_cache[key] = out
	return out

## Like tools imglib geom.shrink_art: opaque cells take the nearest source pixel (keeps the art's contrast), the box
## average only decides coverage; alpha snaps to 0/1 so edges stay hard pixel steps. Box colour where the pick is clear.
static func _crisp(box: Image, pick: Image) -> void:
	for y in box.get_height():
		for x in box.get_width():
			var c: Color = box.get_pixel(x, y)
			if c.a < 0.5:
				box.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var p: Color = pick.get_pixel(x, y)
			box.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0) if p.a >= 0.5 else Color(c.r / c.a, c.g / c.a, c.b / c.a, 1.0))
