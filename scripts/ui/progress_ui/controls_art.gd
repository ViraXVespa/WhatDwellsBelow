extends Object

## Pictures of the controls billboard, drawn in code for the controls menu (no files).
## The frame script places them. The world sign sprite stays on the hub prop.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const WOOD: Color = Color(0.45, 0.30, 0.16, 1)
const WOOD_DARK: Color = Color(0.26, 0.16, 0.08, 1)
const BOARD: Color = Color(0.09, 0.08, 0.07, 1)
const BOARD_RIM: Color = Color(0.16, 0.13, 0.10, 1)
const IRON: Color = Color(0.24, 0.22, 0.20, 1)
const IRON_LIT: Color = Color(0.46, 0.43, 0.38, 1)

static var _images: Dictionary = {}

static func grain(horizontal: bool) -> Texture2D:
	var key: String = "grain-h" if horizontal else "grain-v"
	if _images.has(key):
		return _images[key]
	var w: int = 64 if horizontal else 16
	var h: int = 16 if horizontal else 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var span: int = h if horizontal else w
	for y: int in h:
		for x: int in w:
			var along: int = x if horizontal else y
			var across: int = y if horizontal else x
			var band: int = along % 8
			var px: Color = WOOD
			if band == 0:
				px = WOOD_DARK
			elif band < 3:
				px = WOOD.lerp(Color(0.72, 0.56, 0.36, 1), 0.16)
			var n: int = (x * 13 + y * 5) % 7 - 3
			px.r = clampf(px.r + float(n) * 0.014, 0.0, 1.0)
			px.g = clampf(px.g + float(n) * 0.009, 0.0, 1.0)
			if across < 1 or across >= span - 1:
				px = px.lerp(ThemeS.INK, 0.55)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, key, img)

static func face() -> Texture2D:
	if _images.has("face"):
		return _images["face"]
	var w: int = 32
	var h: int = 32
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var px: Color = BOARD
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				px = BOARD_RIM
			if x < 1 or y < 1 or x == w - 1 or y == h - 1:
				px = px.lerp(ThemeS.INK, 0.4)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "face", img)

static func post() -> Texture2D:
	if _images.has("post"):
		return _images["post"]
	var w: int = 16
	var h: int = 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var band: int = y % 8
			var px: Color = WOOD.lerp(WOOD_DARK, 0.18)
			if band == 0:
				px = WOOD_DARK
			if x < 1 or x >= w - 1:
				px = px.lerp(ThemeS.INK, 0.55)
			img.set_pixel(x, y, px)
	for y: int in 7:
		for x: int in w:
			var iron: Color = IRON_LIT if y == 1 or y == 2 else IRON
			if x < 1 or x >= w - 1 or y == 0 or y == 6:
				iron = iron.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, iron)
	return UiBuild.keep(_images, "post", img)

## Top-left iron corner. The frame flips it for the other three corners.
static func bracket() -> Texture2D:
	if _images.has("bracket"):
		return _images["bracket"]
	var s: int = 32
	var arm: int = 11
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in s:
		for x: int in s:
			if x >= arm and y >= arm:
				continue
			var px: Color = IRON
			if x == 0 or y == 0:
				px = IRON_LIT
			elif x == arm - 1 or y == arm - 1:
				px = IRON.lerp(ThemeS.INK, 0.5)
			img.set_pixel(x, y, px)
	_rivet(img, 5, 5)
	_rivet(img, 5, 22)
	_rivet(img, 22, 5)
	return UiBuild.keep(_images, "bracket", img)

static func plank(lift: float, foot: int) -> Texture2D:
	var key: String = "plank-%d-%d" % [int(round(lift * 100.0)), foot]
	if _images.has(key):
		return _images[key]
	var w: int = 96
	var h: int = 24
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face_col: Color = WOOD.lerp(ThemeS.PAPER, lift)
	for y: int in h:
		for x: int in w:
			var band: int = x % 8
			var px: Color = face_col
			if band == 0:
				px = face_col.lerp(ThemeS.INK, 0.28)
			if y < 2 or y >= h - 2 or x < 2 or x >= w - 2:
				px = px.lerp(ThemeS.INK, 0.4)
			img.set_pixel(x, y, px)
	_rivet(img, 8, 12)
	_rivet(img, w - 9, 12)
	for y: int in foot:
		for x: int in w:
			img.set_pixel(x, h + y, ThemeS.INK)
	return UiBuild.keep(_images, key, img)

static func _rivet(img: Image, cx: int, cy: int) -> void:
	UiBuild.dot(img, cx, cy, 2, IRON)
	if cx >= 0 and cy >= 0 and cx < img.get_width() and cy < img.get_height():
		img.set_pixel(cx, cy, IRON_LIT)
