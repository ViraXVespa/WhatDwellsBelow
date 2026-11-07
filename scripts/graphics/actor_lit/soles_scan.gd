extends Object

## Split from soles.gd: _scan, _none, _bottom_span.

## Pixel scan used by tools/bake.py soles. Not called from play.
static func _scan(tex: Texture2D) -> Dictionary:
	var tw: int = maxi(1, tex.get_width())
	var th: int = maxi(1, tex.get_height())
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return _none(tw, th)
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if w < 1 or h < 1 or bytes.size() < w * h * 4:
		return _none(tw, th)
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		var row: int = y * w * 4
		for x in w:
			if bytes[row + x * 4 + 3] < 51:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return _none(w, h)
	var mid: int = int(float(min_x + max_x) * 0.5)
	var ly: int = -1
	var ry: int = -1
	var ls: float = 0.0
	var ln: int = 0
	var rs: float = 0.0
	var rn: int = 0
	for y2 in range(min_y, max_y + 1):
		var row2: int = y2 * w * 4
		var lsum: float = 0.0
		var lnum: int = 0
		var rsum: float = 0.0
		var rnum: int = 0
		for x2 in range(min_x, max_x + 1):
			if bytes[row2 + x2 * 4 + 3] < 51:
				continue
			if x2 <= mid:
				lsum += float(x2) + 0.5
				lnum += 1
			else:
				rsum += float(x2) + 0.5
				rnum += 1
		if lnum > 0:
			ly = y2
			ls = lsum
			ln = lnum
		if rnum > 0:
			ry = y2
			rs = rsum
			rn = rnum
	var sole: Vector4 = _bottom_span(bytes, w, max_y, min_x, max_x)
	if ly >= 0 and ry >= 0:
		var lx: float = ls / float(ln)
		var rx: float = rs / float(rn)
		if absf(rx - lx) < 0.5:
			var mid_foot: float = (lx + rx) * 0.5
			lx = mid_foot
			rx = mid_foot
		sole = Vector4(lx, float(ly + 1), rx, float(ry + 1))
	return {
		"sole": sole,
		"min_x": min_x, "min_y": min_y, "max_x1": max_x + 1, "max_y1": max_y + 1,
		"w": w, "h": h,
	}

static func _none(w: int, h: int) -> Dictionary:
	return {
		"sole": Vector4(0.0, float(h), float(w), float(h)),
		"min_x": -1, "min_y": -1, "max_x1": -1, "max_y1": -1,
		"w": w, "h": h,
	}

static func _bottom_span(bytes: PackedByteArray, w: int, y: int, x0: int, x1: int) -> Vector4:
	var row: int = y * w * 4
	var left: int = x1
	var right: int = x0
	for x in range(x0, x1 + 1):
		if bytes[row + x * 4 + 3] < 51:
			continue
		if x < left:
			left = x
		if x > right:
			right = x
	if right <= left:
		right = mini(w - 1, left + 1)
	return Vector4(float(left) + 0.5, float(y + 1), float(right) + 0.5, float(y + 1))
