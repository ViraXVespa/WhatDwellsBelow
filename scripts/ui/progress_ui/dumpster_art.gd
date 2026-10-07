extends Object

## Pictures of the dumpster bin front, drawn in code for the flavor menu (no files). The frame script places them.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const STEEL: Color = Color(0.45, 0.52, 0.56, 1)
const STEEL_DARK: Color = Color(0.26, 0.31, 0.35, 1)
const RUST: Color = Color(0.62, 0.34, 0.16, 1)
const MOUTH: Color = Color(0.07, 0.08, 0.09, 1)
const BAG: Color = Color(0.18, 0.20, 0.14, 1)
const BAG_DEEP: Color = Color(0.11, 0.12, 0.10, 1)
const STICKER: Color = Color(0.76, 0.72, 0.62, 1)
const TAPE: Color = Color(0.55, 0.48, 0.32, 1)
const RUBBER: Color = Color(0.10, 0.10, 0.11, 1)
const HUB: Color = Color(0.55, 0.58, 0.60, 1)

static var _images: Dictionary = {}

static func flap(lift: float, foot: int) -> Texture2D:
	var key: String = "flap-%d-%d" % [int(round(lift * 100.0)), foot]
	if _images.has(key):
		return _images[key]
	var w: int = 96
	var h: int = 28
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face: Color = STEEL.lerp(Color(0.82, 0.84, 0.82, 1), lift)
	for y: int in h:
		for x: int in w:
			var px: Color = face
			if y % 4 == 0:
				px = px.lerp(STEEL_DARK, 0.18)
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	_bolt(img, 10, 13)
	_bolt(img, w - 11, 13)
	for y: int in foot:
		for x: int in w:
			img.set_pixel(x, h + y, ThemeS.INK)
	return UiBuild.keep(_images, key, img)

static func lid() -> Texture2D:
	if _images.has("lid"):
		return _images["lid"]
	var w: int = 120
	var h: int = 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inset: int = 26
	for y: int in h:
		var t: float = float(y) / float(h - 1)
		var cut: int = int(float(inset) * (1.0 - t))
		for x: int in range(cut, w - cut):
			var px: Color = STEEL.lerp(Color(0.78, 0.84, 0.86, 1), 0.28)
			if y < 3 or x == cut or x == w - cut - 1:
				px = px.lerp(ThemeS.INK, 0.4)
			if y >= h - 5:
				px = STEEL_DARK
			if (x * 13 + y * 5) % 47 < 2:
				px = px.lerp(RUST, 0.65)
			img.set_pixel(x, y, px)
	for x: int in range(48, 72):
		img.set_pixel(x, 8, STEEL_DARK)
		img.set_pixel(x, 9, HUB)
		img.set_pixel(x, 10, STEEL_DARK)
	img.set_pixel(50, 11, STEEL_DARK)
	img.set_pixel(51, 12, STEEL_DARK)
	img.set_pixel(68, 11, STEEL_DARK)
	img.set_pixel(69, 12, STEEL_DARK)
	return UiBuild.keep(_images, "lid", img)

static func mouth() -> Texture2D:
	if _images.has("mouth"):
		return _images["mouth"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var px: Color = MOUTH
			if y < 6:
				px = px.lerp(Color(0, 0, 0, 1), 0.45)
			if x < 2 or x > 29:
				px = px.lerp(STEEL_DARK, 0.35)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "mouth", img)

static func body() -> Texture2D:
	if _images.has("body"):
		return _images["body"]
	var w: int = 96
	var h: int = 72
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var px: Color = STEEL
			if x < 4 or x >= w - 4:
				px = STEEL_DARK
			var rib: int = y % 18
			if rib == 0:
				px = px.lerp(STEEL_DARK, 0.55)
			elif rib == 1:
				px = px.lerp(Color(0.85, 0.90, 0.92, 1), 0.35)
			var stripe: int = (x * 7) % 23
			if (stripe == 0 or stripe == 1) and y > 10 and (y + x) % 11 < 7:
				px = px.lerp(RUST, 0.62)
			if (x - 28) * (x - 28) + (y - 44) * (y - 44) < 28:
				px = px.lerp(RUST, 0.5)
			if x < 2 or y < 2 or x >= w - 2:
				px = px.lerp(ThemeS.INK, 0.35)
			img.set_pixel(x, y, px)
	_bolt(img, 8, 8)
	_bolt(img, w - 9, 8)
	_bolt(img, 8, h - 10)
	_bolt(img, w - 9, h - 10)
	return UiBuild.keep(_images, "body", img)

static func rim() -> Texture2D:
	if _images.has("rim"):
		return _images["rim"]
	var w: int = 96
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var px: Color = STEEL_DARK.lerp(STEEL, 0.35)
			if y < 3:
				px = px.lerp(Color(0.80, 0.86, 0.88, 1), 0.45)
			if y > h - 4:
				px = px.lerp(Color(0, 0, 0, 1), 0.35)
			img.set_pixel(x, y, px)
	for x: int in [12, 48, 84]:
		_bolt(img, x, 8)
	return UiBuild.keep(_images, "rim", img)

static func label() -> Texture2D:
	if _images.has("label"):
		return _images["label"]
	var w: int = 80
	var h: int = 36
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dirt: Color = Color(0.42, 0.32, 0.22, 1)
	for y: int in h:
		for x: int in w:
			var px: Color = STICKER
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				px = px.lerp(dirt, 0.55)
			elif (x * 17 + y * 13) % 97 == 0:
				px = px.lerp(dirt, 0.35)
			img.set_pixel(x, y, px)
	for y: int in range(1, 7):
		for x: int in range(2, 16):
			img.set_pixel(x, y, TAPE)
		for x: int in range(w - 16, w - 2):
			img.set_pixel(x, y, TAPE)
	return UiBuild.keep(_images, "label", img)

static func bag(kind: int) -> Texture2D:
	var key: String = "bag-%d" % kind
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(48, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = BAG
	if kind == 1:
		col = BAG.lerp(Color(0.30, 0.32, 0.22, 1), 0.4)
	elif kind == 2:
		col = BAG_DEEP
	var mid: float = 24.0
	for y: int in 56:
		var half: float = 18.0
		if y < 7:
			half = 3.0
		elif y < 16:
			half = 3.0 + float(y - 7) * 1.7
		else:
			half = 16.0 + sin(float(y) * 0.55 + float(kind) * 1.4) * 2.5
		for x: int in 48:
			if absf(float(x) - mid) > half:
				continue
			var px: Color = col
			if float(x) < mid - 4.0:
				px = px.lerp(Color(0.40, 0.44, 0.32, 1), 0.28)
			if y < 7:
				px = px.lerp(TAPE, 0.45)
			if absi(x - int(mid)) <= 1 and y > 14 and y < 48:
				px = px.lerp(Color(0, 0, 0, 1), 0.28)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, key, img)

static func slat() -> Texture2D:
	if _images.has("slat"):
		return _images["slat"]
	var img: Image = Image.create(10, 36, false, Image.FORMAT_RGBA8)
	var wood: Color = Color(0.62, 0.52, 0.36, 1)
	for y: int in 36:
		for x: int in 10:
			var px: Color = wood
			if x == 0 or x == 9:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "slat", img)

static func wheel() -> Texture2D:
	if _images.has("wheel"):
		return _images["wheel"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in range(0, 16):
		img.set_pixel(8, y, STEEL_DARK)
		img.set_pixel(9, y, STEEL)
		img.set_pixel(22, y, STEEL)
		img.set_pixel(23, y, STEEL_DARK)
	for y: int in 32:
		for x: int in 32:
			var dx: int = x - 16
			var dy: int = y - 18
			var d2: int = dx * dx + dy * dy
			if d2 > 13 * 13:
				continue
			if d2 >= 7 * 7:
				img.set_pixel(x, y, RUBBER)
			elif d2 >= 3 * 3:
				img.set_pixel(x, y, HUB.lerp(STEEL_DARK, 0.25))
			else:
				img.set_pixel(x, y, STEEL_DARK)
	return UiBuild.keep(_images, "wheel", img)

static func _bolt(img: Image, cx: int, cy: int) -> void:
	UiBuild.dot(img, cx, cy, 2, HUB.lerp(STEEL_DARK, 0.2))
	if cx >= 0 and cy >= 0 and cx < img.get_width() and cy < img.get_height():
		img.set_pixel(cx, cy, STEEL_DARK)

