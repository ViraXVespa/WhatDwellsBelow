extends Object

## Hub art at the ground's pixel size: the ground's visible pixel is GRID_M (1/32 m, 4 texels of the 128 px/m
## sheets). A sprite whose texel is finer (pixel_size < GRID_M) is shrunk to that grid (detail-keeping cell colour, box coverage; tools key.pixelate) and nearest-scaled
## back to its own size, so texel rects (lamps, window, crop) still hold. Cached per texture and size.

const GRID_M := 1.0 / 32.0
static var _cache: Dictionary = {}

## fast: per-frame animation art; native box shrink plus nearest pick per cell (no per-source-pixel detail pass).
static func tex(t: Texture2D, px_m: float, fast := false) -> Texture2D:
	if t == null or px_m <= 0.0:
		return t
	var f: float = GRID_M / px_m
	if f < 1.3:
		return t
	var key: String = "%d:%.4f%s" % [t.get_rid().get_id(), f, "f" if fast else ""]
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
	var small: Image
	if fast:
		small = img.duplicate()
		small.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		var pick: Image = img.duplicate()
		pick.resize(tw, th, Image.INTERPOLATE_NEAREST)
		for y in th:
			for x in tw:
				var p: Color = pick.get_pixel(x, y)
				small.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0) if small.get_pixel(x, y).a >= 0.5 and p.a >= 0.5 else Color(0, 0, 0, 0))
	else:
		small = _detail(img, tw, th)
	small.resize(w, h, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(small)
	# Keeps the source name readable (checks find the face art by path) without stealing the source's cache slot.
	if t.resource_path != "":
		out.resource_path = "%s::chunky_%s" % [t.resource_path, key.replace(":", "_").replace(".", "_")]
	_cache[key] = out
	return out

## Mirrors tools imglib geom.shrink_detail: alpha = the cell's mean coverage, snapped at 0.5 (hard pixel edges);
## colour = the opaque pixel furthest in luminance from the cell mean when over DETAIL_L (thin dark bands and
## highlights survive), else the opaque pixel nearest the mean colour (dominant tone, no averaging blur).
const DETAIL_L := 0.15 * 255.0

static func _detail(img: Image, tw: int, th: int) -> Image:
	var w: int = img.get_width()
	var src: PackedByteArray = img.get_data()
	var out := PackedByteArray()
	out.resize(tw * th * 4)
	for cy in th:
		var y0: int = cy * img.get_height() / th
		var y1: int = maxi(y0 + 1, (cy + 1) * img.get_height() / th)
		for cx in tw:
			var x0: int = cx * w / tw
			var x1: int = maxi(x0 + 1, (cx + 1) * w / tw)
			var n := 0
			var cov := 0
			var sr := 0
			var sg := 0
			var sb := 0
			for y in range(y0, y1):
				for x in range(x0, x1):
					var i: int = (y * w + x) * 4
					cov += src[i + 3]
					if src[i + 3] >= 128:
						n += 1
						sr += src[i]
						sg += src[i + 1]
						sb += src[i + 2]
			var o: int = (cy * tw + cx) * 4
			if n == 0 or cov * 2 < 255 * (y1 - y0) * (x1 - x0):
				continue
			var mr: float = float(sr) / n
			var mg: float = float(sg) / n
			var mb: float = float(sb) / n
			var ml: float = 0.299 * mr + 0.587 * mg + 0.114 * mb
			var far := -1.0
			var fi := 0
			var near := INF
			var ni := 0
			for y in range(y0, y1):
				for x in range(x0, x1):
					var i: int = (y * w + x) * 4
					if src[i + 3] < 128:
						continue
					var gap: float = absf(0.299 * src[i] + 0.587 * src[i + 1] + 0.114 * src[i + 2] - ml)
					if gap > far:
						far = gap
						fi = i
					var d: float = (src[i] - mr) ** 2 + (src[i + 1] - mg) ** 2 + (src[i + 2] - mb) ** 2
					if d < near:
						near = d
						ni = i
			var k: int = fi if far > DETAIL_L else ni
			out[o] = src[k]
			out[o + 1] = src[k + 1]
			out[o + 2] = src[k + 2]
			out[o + 3] = 255
	return Image.create_from_data(tw, th, false, Image.FORMAT_RGBA8, out)
