extends Object

## Hub bake only: the one 3x3 blur over the shadowed yard image (after hub_shadow.gd). With zones (one id per texel:
## 0 = yard, i + 1 = footprint i) a texel averages only same-zone neighbours, so a bright unshaded footprint (its roof
## samples it) never bleeds a lit rim onto the shadowed yard around the walls (bake.py check: leak).

const RT_PATH := "res://scripts/graphics/light_rt.gd"

## Zone id per texel (row-major) for img with origin org (m): first footprint Rect2 holding the texel centre.
static func zones(img: Image, org: Vector2, rects: Array) -> PackedInt32Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sub: float = float(load(RT_PATH).HUB_SUB)
	var z := PackedInt32Array()
	z.resize(w * h)
	for i in rects.size():
		var r: Rect2 = rects[i]
		var x0: int = maxi(0, ceili((r.position.x - org.x) * sub - 0.5))
		var x1: int = mini(w - 1, floori((r.end.x - org.x) * sub - 0.5))
		var y0: int = maxi(0, ceili((r.position.y - org.y) * sub - 0.5))
		var y1: int = mini(h - 1, floori((r.end.y - org.y) * sub - 0.5))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if z[y * w + x] == 0:
					z[y * w + x] = i + 1
	return z

static func _row(img: Image, y: int, w: int) -> PackedColorArray:
	var r := PackedColorArray()
	r.resize(w)
	for x in w:
		r[x] = img.get_pixel(x, y)
	return r
static func _blur_hub(img: Image, zone := PackedInt32Array()) -> void:
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
				if not zone.is_empty() and _mixed(zone, w, x, y):
					img.set_pixel(x, y, _masked(copy, zone, w, h, x, y))
					continue
				img.set_pixel(x, y, (
					up[x - 1] + up[x] + up[x + 1] + mid[x - 1] + mid[x] + mid[x + 1]
					+ down[x - 1] + down[x] + down[x + 1]
				) / 9.0)
		var edges: Array = [0, w - 1] if inner_y else range(w)
		for x in edges:
			if not zone.is_empty():
				img.set_pixel(x, y, _masked(copy, zone, w, h, x, y))
				continue
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

static func _mixed(zone: PackedInt32Array, w: int, x: int, y: int) -> bool:
	var c: int = zone[y * w + x]
	for oy in range(-1, 2):
		var row: int = (y + oy) * w + x
		if zone[row - 1] != c or zone[row] != c or zone[row + 1] != c:
			return true
	return false

## Mean of the in-image 3x3 neighbours in the texel's own zone.
static func _masked(copy: Image, zone: PackedInt32Array, w: int, h: int, x: int, y: int) -> Color:
	var c: int = zone[y * w + x]
	var acc := Color(0, 0, 0, 0)
	var n: float = 0.0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var px: int = x + ox
			var py: int = y + oy
			if px >= 0 and px < w and py >= 0 and py < h and zone[py * w + px] == c:
				acc += copy.get_pixel(px, py)
				n += 1.0
	return acc / n
