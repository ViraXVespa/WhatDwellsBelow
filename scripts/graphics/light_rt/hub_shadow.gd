extends Object

## Hub image helper: the 3x3 blur shared by the runtime yard and the bake.

static func _row(img: Image, y: int, w: int) -> PackedColorArray:
	var r := PackedColorArray()
	r.resize(w)
	for x in w:
		r[x] = img.get_pixel(x, y)
	return r
static func _blur_hub(img: Image) -> void:
	# 3x3 mean, edges renormalised. Same Color math and add order as the generic form (byte-identical).
	# Interior pixels read three cached source rows (each pixel fetched once, not nine times).
	var w: int = img.get_width()
	var h: int = img.get_height()
	var copy: Image = img.duplicate()
	var up: PackedColorArray
	var mid: PackedColorArray = _row(copy, 0, w)
	var down: PackedColorArray = _row(copy, 1, w) if h > 1 else mid
	var y: int = 0
	while y < h:
		var inner_y: bool = y > 0 and y < h - 1
		if inner_y:
			for x in range(1, w - 1):
				img.set_pixel(x, y, (
					up[x - 1] + up[x] + up[x + 1] + mid[x - 1] + mid[x] + mid[x + 1]
					+ down[x - 1] + down[x] + down[x + 1]
				) / 9.0)
		var edges: Array = [0, w - 1] if inner_y else range(w)
		for x in edges:
			var acc := Color(0, 0, 0, 0)
			var n: float = 0.0
			for oy in range(-1, 2):
				var py: int = y + oy
				if py < 0 or py >= h:
					continue
				for ox in range(-1, 2):
					var px: int = x + ox
					if px < 0 or px >= w:
						continue
					acc += copy.get_pixel(px, py)
					n += 1.0
			img.set_pixel(x, y, acc / n)
		up = mid
		mid = down
		down = _row(copy, y + 2, w) if y + 2 < h else mid
		y += 1
