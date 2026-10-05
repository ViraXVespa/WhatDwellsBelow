extends Object

## Pictures of the vendor stall front, drawn in code for the vendor menu (no files). The frame script places them.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const WOOD: Color = Color(0.55, 0.40, 0.27, 1)
const OLIVE: Color = Color(0.44, 0.41, 0.25, 1)
const CLAY: Color = Color(0.55, 0.24, 0.20, 1)
const MOUTH: Color = Color(0.11, 0.07, 0.08, 1)
const PAPER: Color = Color(0.94, 0.86, 0.72, 1)

static var _images: Dictionary = {}

static func grain(w: int, h: int, lift: float, foot: int) -> Texture2D:
	var key: String = "g-%d-%d-%d-%d" % [w, h, int(round(lift * 100.0)), foot]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, lift)
	var seam: Color = face.lerp(ThemeS.INK, 0.42)
	var row_h: int = 8
	for y: int in h:
		var band: int = y % row_h
		var row: Color = face
		if band == 0:
			row = seam
		elif band < 3:
			row = face.lerp(Color(1, 1, 1, 1), 0.12)
		for x: int in w:
			var n: int = (x * 17 + y * 5) % 9 - 4
			var px: Color = row
			px.r = clampf(px.r + float(n) * 0.012, 0.0, 1.0)
			px.g = clampf(px.g + float(n) * 0.008, 0.0, 1.0)
			if x < 2 or x >= w - 2 or y < 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	for y: int in foot:
		for x: int in w:
			img.set_pixel(x, h + y, ThemeS.INK)
	return UiBuild.keep(_images, key, img)

static func post(flip: bool) -> Texture2D:
	var key: String = "post-r" if flip else "post-l"
	if _images.has(key):
		return _images[key]
	var w: int = 28
	var h: int = 160
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, 0.18)
	for y: int in h:
		for x: int in w:
			var px: Color = face
			var n: int = (x * 3 + y) % 7 - 3
			px.r = clampf(px.r + float(n) * 0.01, 0.0, 1.0)
			if x < 2 or x >= w - 2:
				px = px.lerp(ThemeS.INK, 0.55)
			if y % 18 == 0:
				px = px.lerp(ThemeS.INK, 0.28)
			img.set_pixel(x, y, px)
	for band_y: int in [18, 124]:
		for y: int in 8:
			for x: int in w:
				var iron: Color = Color(0.45, 0.48, 0.50, 1)
				if y == 0 or y == 7 or x < 1 or x >= w - 1:
					iron = iron.lerp(ThemeS.INK, 0.6)
				img.set_pixel(x, band_y + y, iron)
	return UiBuild.keep(_images, key, img)

static func awning(w: int, h: int) -> Texture2D:
	var key: String = "awning-%d-%d" % [w, h]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hem_base: int = h - 28
	var amp: int = 16
	for y: int in h:
		for x: int in w:
			var wave: float = sin(float(x) / float(w) * 7.0 * TAU)
			var hem: int = hem_base + int((wave * 0.5 + 0.5) * float(amp))
			if y > hem:
				continue
			var px: Color = OLIVE
			if ((x / 4) + (y / 4)) % 2 == 0:
				px = px.lerp(Color(0, 0, 0, 1), 0.08)
			if y < 10:
				px = px.lerp(ThemeS.INK, 0.35)
			if hem - y < 5:
				px = px.lerp(ThemeS.INK, 0.28)
			if hem - y == 7 and (x % 5) < 2:
				px = ThemeS.INK
			img.set_pixel(x, y, px)
	ring(img, 18, 16, 11)
	ring(img, w - 19, 16, 11)
	return UiBuild.keep(_images, key, img)

static func ring(img: Image, cx: int, cy: int, radius: int) -> void:
	var iron: Color = Color(0.62, 0.64, 0.66, 1)
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx: int = x - cx
			var dy: int = y - cy
			var d2: int = dx * dx + dy * dy
			if d2 > radius * radius:
				continue
			if d2 < 16:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d2 > (radius - 2) * (radius - 2):
				img.set_pixel(x, y, iron.lerp(ThemeS.INK, 0.45))
			else:
				img.set_pixel(x, y, iron)

static func bulb() -> Texture2D:
	if _images.has("bulb"):
		return _images["bulb"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cream: Color = Color(0.86, 0.78, 0.62, 1)
	for i: int in 4:
		UiBuild.dot(img, 9, 8 + i * 8, 5, cream.lerp(ThemeS.INK, float(i) * 0.08))
	for y: int in 6:
		img.set_pixel(9, y, Color(0.35, 0.32, 0.22, 1))
	return UiBuild.keep(_images, "bulb", img)

static func herb() -> Texture2D:
	if _images.has("herb"):
		return _images["herb"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leaf: Color = Color(0.28, 0.38, 0.18, 1)
	for y: int in range(8, 38):
		var half: int = 3 + ((y / 6) % 3)
		for x: int in range(9 - half, 9 + half):
			img.set_pixel(x, y, leaf if (x + y) % 3 != 0 else leaf.lerp(Color(0.5, 0.55, 0.28, 1), 0.4))
	for y: int in 8:
		img.set_pixel(9, y, Color(0.35, 0.32, 0.22, 1))
	return UiBuild.keep(_images, "herb", img)

static func tool() -> Texture2D:
	if _images.has("tool"):
		return _images["tool"]
	var img: Image = Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var haft: Color = WOOD.lerp(PAPER, 0.1)
	var head: Color = Color(0.55, 0.58, 0.60, 1)
	for y: int in range(10, 40):
		img.set_pixel(8, y, haft)
		img.set_pixel(9, y, haft.lerp(ThemeS.INK, 0.2))
	for x: int in range(3, 15):
		img.set_pixel(x, 8, head)
		img.set_pixel(x, 9, head.lerp(ThemeS.INK, 0.25))
	return UiBuild.keep(_images, "tool", img)

static func crate() -> Texture2D:
	if _images.has("crate"):
		return _images["crate"]
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var face: Color = WOOD.lerp(PAPER, 0.22)
	img.fill(face.lerp(ThemeS.INK, 0.55))
	for y: int in range(3, 29):
		for x: int in range(3, 29):
			var px: Color = face
			if x == 3 or y == 3 or x == 28 or y == 28 or absi(x - y) < 2 or absi(x - (31 - y)) < 2:
				px = px.lerp(ThemeS.INK, 0.45)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "crate", img)

static func pot() -> Texture2D:
	if _images.has("pot"):
		return _images["pot"]
	var img: Image = Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in 40:
		for x: int in 32:
			var nx: float = (float(x) - 15.5) / 12.0
			var ny: float = (float(y) - 22.0) / 16.0
			var neck: bool = y < 10 and absf(float(x) - 15.5) < 6.0
			if nx * nx + ny * ny > 1.0 and not neck:
				continue
			var px: Color = CLAY
			if x < 12:
				px = px.lerp(Color(1, 1, 1, 1), 0.18)
			if y < 8:
				px = px.lerp(ThemeS.INK, 0.25)
			img.set_pixel(x, y, px)
	return UiBuild.keep(_images, "pot", img)

static func fill(col: Color) -> Texture2D:
	var key: String = "fill-%d-%d-%d" % [int(col.r * 255.0), int(col.g * 255.0), int(col.b * 255.0)]
	if _images.has(key):
		return _images[key]
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return UiBuild.keep(_images, key, img)

