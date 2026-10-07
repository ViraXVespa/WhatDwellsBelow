extends Object

## Pictures of the anvil front, drawn in code for the anvil menu (no files).
## The frame script places them. The world anvil sprite stays on the hub prop.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const IRON: Color = Color(0.50, 0.53, 0.58, 1)
const IRON_DARK: Color = Color(0.22, 0.24, 0.28, 1)
const IRON_LIT: Color = Color(0.86, 0.88, 0.90, 1)
const BARK: Color = Color(0.34, 0.20, 0.11, 1)
const FACE: Color = Color(0.90, 0.80, 0.64, 1)
const RING: Color = Color(0.78, 0.66, 0.48, 1)

static var _images: Dictionary = {}

static func stump() -> Texture2D:
	if _images.has("stump"):
		return _images["stump"]
	var w: int = 240
	var h: int = 160
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx: float = float(w) * 0.5
	var cy: float = float(h) * 0.62
	for y: int in h:
		for x: int in w:
			var dx: float = (float(x) - cx) / (cx * 0.82)
			var dy: float = (float(y) - cy) / (float(h) * 0.34)
			var d: float = sqrt(dx * dx + dy * dy)
			var px: Color = FACE
			if y > int(float(h) * 0.42):
				var ring: float = fmod(d * 5.0, 1.0)
				if ring < 0.08:
					px = RING
			var n: int = (x * 13 + y * 5) % 7 - 3
			px.r = clampf(px.r + float(n) * 0.01, 0.0, 1.0)
			if x < 14 or x >= w - 14 or y < 10 or y >= h - 14:
				px = BARK
				if (x + y) % 11 == 0:
					px = BARK.lerp(ThemeS.INK, 0.25)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "stump", img)

static func shadow() -> Texture2D:
	if _images.has("shadow"):
		return _images["shadow"]
	var w: int = 64
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in h:
		for x: int in w:
			var dx: float = (float(x) - 32.0) / 32.0
			var dy: float = (float(y) - 8.0) / 8.0
			var d: float = dx * dx + dy * dy
			if d < 1.0:
				img.set_pixel(x, y, Color(0.12, 0.07, 0.04, 0.45 * (1.0 - d)))
	return UiBuild.keep(_images, "shadow", img)

## Side-view anvil, matching the hub prop: horn to the right, flat face, hardy hole, waist, two feet. One mass.
static func anvil() -> Texture2D:
	if _images.has("anvil"):
		return _images["anvil"]
	var w: int = 180
	var h: int = 110
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pts: Array[Vector2i] = [
		Vector2i(14, 18), Vector2i(108, 18), Vector2i(132, 20), Vector2i(152, 26), Vector2i(166, 32),
		Vector2i(152, 38), Vector2i(132, 44), Vector2i(114, 48),
		Vector2i(102, 58), Vector2i(94, 66), Vector2i(112, 74), Vector2i(124, 80), Vector2i(124, 100),
		Vector2i(92, 100), Vector2i(92, 86), Vector2i(56, 86), Vector2i(56, 100),
		Vector2i(16, 100), Vector2i(16, 80), Vector2i(34, 74), Vector2i(46, 66), Vector2i(30, 56), Vector2i(14, 48),
	]
	_fill(img, pts, IRON)
	_lit_top(img)
	for y: int in range(24, 31):
		for x: int in range(34, 52):
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, IRON_DARK)
	for y: int in range(97, 101):
		for x: int in w:
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, IRON_DARK)
	_edge(img)
	return UiBuild.keep(_images, "anvil", img)

static func _fill(img: Image, pts: Array[Vector2i], col: Color) -> void:
	var n: int = pts.size()
	var miny: int = pts[0].y
	var maxy: int = pts[0].y
	for p: Vector2i in pts:
		miny = mini(miny, p.y)
		maxy = maxi(maxy, p.y)
	var w: int = img.get_width()
	for y: int in range(miny, maxy + 1):
		var xs: Array[int] = []
		for i: int in n:
			var a: Vector2i = pts[i]
			var b: Vector2i = pts[(i + 1) % n]
			if a.y > b.y:
				var swap: Vector2i = a
				a = b
				b = swap
			if y < a.y or y >= b.y:
				continue
			var t: float = float(y - a.y) / float(b.y - a.y)
			xs.append(int(round(float(a.x) + t * float(b.x - a.x))))
		xs.sort()
		var j: int = 0
		while j + 1 < xs.size():
			var x0: int = xs[j]
			var x1: int = xs[j + 1]
			if x0 > x1:
				var tmp: int = x0
				x0 = x1
				x1 = tmp
			for x: int in range(x0, x1):
				if x >= 0 and x < w:
					img.set_pixel(x, y, col)
			j += 2

static func _lit_top(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in range(1, h):
		for x: int in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			if img.get_pixel(x, y - 1).a < 0.5:
				for k: int in 4:
					var yy: int = y + k
					if yy < h and img.get_pixel(x, yy).a > 0.5:
						img.set_pixel(x, yy, IRON_LIT)

static func _edge(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var mark: Array = []
	for y: int in h:
		for x: int in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var rim: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			if not rim:
				rim = img.get_pixel(x - 1, y).a < 0.5 or img.get_pixel(x + 1, y).a < 0.5 or img.get_pixel(x, y - 1).a < 0.5 or img.get_pixel(x, y + 1).a < 0.5
			if rim:
				mark.append(Vector2i(x, y))
	for p: Vector2i in mark:
		img.set_pixel(p.x, p.y, IRON_DARK)

