extends Object

## Picture of the floor-crystal front, drawn in code for the loadout menu (no files).
## The frame script places it. The world crystal sprite stays on the hub prop.
## ART_W x ART_H is the source. The frame shows it at 3x, nearest, so the pale rect stays under the gear board.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const ART_W: int = 440
const ART_H: int = 352
## Image-space rect the gear board and the prompt must sit inside. The frame scales it by 3.
const PALE: Rect2i = Rect2i(36, 58, 368, 218)
const PLINTH_Y: int = 276

const GEM: Color = Color(0.16, 0.74, 0.84, 1)
const GEM_DARK: Color = Color(0.05, 0.40, 0.52, 1)
const GEM_LIT: Color = Color(0.62, 0.96, 1.0, 1)
const FACE: Color = Color(0.78, 0.94, 0.95, 1)
const FACE_LIT: Color = Color(0.90, 0.99, 1.0, 1)
const STONE: Color = Color(0.30, 0.32, 0.36, 1)
const STONE_DARK: Color = Color(0.15, 0.16, 0.19, 1)
const STONE_LIT: Color = Color(0.48, 0.50, 0.54, 1)
const PINK: Color = Color(0.93, 0.24, 0.55, 1)
const PINK_LIT: Color = Color(1.0, 0.74, 0.86, 1)
const CORE: Color = Color(0.82, 1.0, 1.0, 1)
const CORE_HOT: Color = Color(0.97, 1.0, 1.0, 1)
const EDGE: Color = Color(0.04, 0.07, 0.09, 1)

static var _images: Dictionary = {}

static func body() -> Texture2D:
	if _images.has("body"):
		return _images["body"]
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gem: Array[Vector2i] = [
		Vector2i(220, 4), Vector2i(14, 50), Vector2i(26, 288), Vector2i(414, 288), Vector2i(426, 50),
	]
	_fill(img, gem, GEM)
	_shade_gem(img)
	_line(img, 220, 8, 18, 150, GEM_DARK)
	_line(img, 220, 8, 422, 150, GEM_DARK)
	_line(img, 30, 52, 410, 52, GEM_DARK)
	_fill(img, [Vector2i(220, 34), Vector2i(PALE.position.x, PALE.position.y), Vector2i(PALE.position.x, PALE.end.y), Vector2i(PALE.end.x, PALE.end.y), Vector2i(PALE.end.x, PALE.position.y)], FACE)
	_wash_face(img)
	_plinth(img)
	_spark(img, 36, 332, 8)
	_spark(img, 404, 332, 8)
	_spark(img, 78, 292, 5)
	_spark(img, 362, 292, 5)
	_core(img, 220, 26)
	_outline(img)
	return UiBuild.keep(_images, "body", img)

static func _shade_gem(img: Image) -> void:
	for y: int in ART_H:
		for x: int in ART_W:
			var px: Color = img.get_pixel(x, y)
			if px.a < 0.5 or not _near(px, GEM):
				continue
			var col: Color = GEM
			if x < 150:
				col = GEM_DARK
			elif x > 300:
				col = GEM.lerp(GEM_LIT, 0.55)
			if y < 56:
				col = col.lerp(GEM_LIT, 0.4)
			var n: int = (x * 13 + y * 5) % 7 - 3
			col.r = clampf(col.r + float(n) * 0.012, 0.0, 1.0)
			col.g = clampf(col.g + float(n) * 0.008, 0.0, 1.0)
			img.set_pixel(x, y, col)

static func _wash_face(img: Image) -> void:
	var y0: int = PALE.position.y
	var y1: int = PALE.end.y
	for y: int in range(y0, y1):
		var t: float = float(y - y0) / float(maxi(1, y1 - y0))
		for x: int in range(PALE.position.x, PALE.end.x):
			var px: Color = img.get_pixel(x, y)
			if px.a < 0.5 or not _near(px, FACE):
				continue
			img.set_pixel(x, y, FACE_LIT.lerp(FACE, t))

static func _plinth(img: Image) -> void:
	## Two rough slabs, the lower one wider, matching the hub crystal's pedestal.
	_slab(img, 58, PLINTH_Y, 382, PLINTH_Y + 34, STONE, 4)
	_slab(img, 22, PLINTH_Y + 26, 418, ART_H - 4, STONE_DARK, 5)

static func _slab(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, stones: int) -> void:
	var cuts: Array[int] = [x0]
	var step: int = maxi(1, (x1 - x0) / stones)
	for i: int in range(1, stones):
		cuts.append(clampi(x0 + i * step + (i * 13) % 9 - 4, x0 + 12, x1 - 12))
	cuts.append(x1)
	for y: int in range(y0, y1):
		var chip: int = 0
		if y < y0 + 4:
			chip = (y0 + 4 - y) * 3
		for x: int in range(x0 + chip, x1 - chip):
			var px: Color = col
			if y < y0 + 4:
				px = px.lerp(STONE_LIT, 0.75)
			for c: int in cuts:
				if c != x0 and c != x1 and absi(x - c) <= 1:
					px = px.lerp(EDGE, 0.62)
			var n: int = (x * 19 + y * 7) % 5 - 2
			px.r = clampf(px.r + float(n) * 0.02, 0.0, 1.0)
			px.g = clampf(px.g + float(n) * 0.02, 0.0, 1.0)
			px.b = clampf(px.b + float(n) * 0.02, 0.0, 1.0)
			_px(img, x, y, px)

static func _spark(img: Image, cx: int, cy: int, r: int) -> void:
	for y: int in range(cy - r, cy + r + 1):
		var dy: int = absi(y - cy)
		var half: int = r - dy
		for x: int in range(cx - half, cx + half + 1):
			var d: int = absi(x - cx) + dy
			var col: Color = PINK_LIT if d < maxi(2, r / 3) else PINK
			if x >= cx and y >= cy and d > r / 2:
				col = PINK.lerp(EDGE, 0.35)
			_px(img, x, y, col)

static func _core(img: Image, cx: int, cy: int) -> void:
	for y: int in range(cy - 16, cy + 17):
		var dy: int = absi(y - cy)
		var half: int = 16 - dy
		for x: int in range(cx - half, cx + half + 1):
			var d: int = absi(x - cx) + dy
			var col: Color = CORE_HOT if d < 6 else CORE
			if d > 12:
				col = GEM_LIT
			_px(img, x, y, col)

static func _fill(img: Image, pts: Array[Vector2i], col: Color) -> void:
	var n: int = pts.size()
	var miny: int = pts[0].y
	var maxy: int = pts[0].y
	for p: Vector2i in pts:
		miny = mini(miny, p.y)
		maxy = maxi(maxy, p.y)
	for y: int in range(miny, maxy + 1):
		var xs: Array[int] = []
		for i: int in n:
			var a: Vector2i = pts[i]
			var b: Vector2i = pts[(i + 1) % n]
			if a.y > b.y:
				var swap: Vector2i = a
				a = b
				b = swap
			if a.y == b.y or y < a.y or y >= b.y:
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
				_px(img, x, y, col)
			j += 2

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var steps: int = maxi(absi(x1 - x0), absi(y1 - y0))
	if steps < 1:
		_px(img, x0, y0, col)
		return
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: int = int(round(lerpf(float(x0), float(x1), t)))
		var y: int = int(round(lerpf(float(y0), float(y1), t)))
		if x >= 0 and y >= 0 and x < ART_W and y < ART_H and img.get_pixel(x, y).a > 0.5:
			img.set_pixel(x, y, col)

static func _outline(img: Image) -> void:
	var mark: Array[Vector2i] = []
	for y: int in ART_H:
		for x: int in ART_W:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var rim: bool = x == 0 or y == 0 or x == ART_W - 1 or y == ART_H - 1
			if not rim:
				rim = img.get_pixel(x - 1, y).a < 0.5 or img.get_pixel(x + 1, y).a < 0.5 or img.get_pixel(x, y - 1).a < 0.5 or img.get_pixel(x, y + 1).a < 0.5
			if rim:
				mark.append(Vector2i(x, y))
	for p: Vector2i in mark:
		img.set_pixel(p.x, p.y, EDGE)

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= ART_W or y >= ART_H:
		return
	img.set_pixel(x, y, col)

static func _near(px: Color, col: Color) -> bool:
	return absf(px.r - col.r) < 0.02 and absf(px.g - col.g) < 0.02 and absf(px.b - col.b) < 0.02
