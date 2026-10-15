extends Object

## Reception desk for Talk: a wood and felt body, a 9-slice speech sheet (96, 24 px margins), and a 256 bust.
## The world sprite stays on the guild prop. Bake with tools/bake_frame_art.py.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const ArtBake: GDScript = preload("res://scripts/ui/progress_ui/art_bake.gd")

const ART := "receptionist"
const ART_W: int = 480
const ART_H: int = 280

const WOOD := Color(0.38, 0.24, 0.13, 1)
const WOOD_LT := Color(0.55, 0.38, 0.20, 1)
const FELT := Color(0.20, 0.33, 0.24, 1)
const FELT_DK := Color(0.12, 0.20, 0.15, 1)
const PAPER := Color(0.95, 0.89, 0.76, 1)
const EDGE := Color(0.28, 0.18, 0.10, 1)
const SKIN := Color(0.93, 0.76, 0.62, 1)
const SKIN_SH := Color(0.78, 0.58, 0.46, 1)
const HAIR := Color(0.62, 0.64, 0.66, 1)
const HAIR_DK := Color(0.40, 0.42, 0.46, 1)
const COAT := Color(0.30, 0.48, 0.30, 1)
const COAT_DK := Color(0.18, 0.32, 0.20, 1)
const STRAP := Color(0.42, 0.26, 0.14, 1)
const GLASS := Color(0.16, 0.17, 0.20, 1)
const GOLD := Color(0.76, 0.62, 0.28, 1)
const INK := Color(0.16, 0.12, 0.08, 1)

static var _images: Dictionary = {}

static func body() -> Texture2D:
	if ArtBake.hit(_images, ART, "body"):
		return _images["body"]
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	img.fill(WOOD)
	img.fill_rect(Rect2i(0, 0, ART_W, 8), WOOD_LT)
	img.fill_rect(Rect2i(10, 10, ART_W - 20, ART_H - 20), FELT)
	img.fill_rect(Rect2i(10, 10, ART_W - 20, 6), Color(FELT.r + 0.06, FELT.g + 0.06, FELT.b + 0.04, 1))
	_well(img)
	return UiBuild.keep(_images, "body", img)

## 96×96 sheet. The center 48×48 is flat paper so the nine-patch stretch stays clean. Margins are 24.
static func speech() -> Texture2D:
	if ArtBake.hit(_images, ART, "speech"):
		return _images["speech"]
	var img: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	img.fill_rect(Rect2i(0, 0, 96, 10), EDGE)
	img.fill_rect(Rect2i(0, 86, 96, 10), EDGE)
	img.fill_rect(Rect2i(0, 0, 10, 96), EDGE)
	img.fill_rect(Rect2i(86, 0, 10, 96), EDGE)
	img.fill_rect(Rect2i(4, 4, 88, 4), WOOD_LT)
	img.fill_rect(Rect2i(4, 88, 88, 4), WOOD)
	img.fill_rect(Rect2i(0, 0, 22, 22), WOOD)
	img.fill_rect(Rect2i(74, 0, 22, 22), WOOD)
	img.fill_rect(Rect2i(0, 74, 22, 22), WOOD)
	img.fill_rect(Rect2i(74, 74, 22, 22), WOOD)
	img.fill_rect(Rect2i(6, 6, 10, 10), GOLD)
	img.fill_rect(Rect2i(80, 6, 10, 10), GOLD)
	img.fill_rect(Rect2i(6, 80, 10, 10), GOLD)
	img.fill_rect(Rect2i(80, 80, 10, 10), GOLD)
	img.fill_rect(Rect2i(24, 24, 48, 48), PAPER)
	return UiBuild.keep(_images, "speech", img)

## Head-and-shoulders bust, transparent outside the figure.
static func bust() -> Texture2D:
	if ArtBake.hit(_images, ART, "bust"):
		return _images["bust"]
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(70, 158, 116, 90), COAT)
	img.fill_rect(Rect2i(70, 158, 14, 90), COAT_DK)
	img.fill_rect(Rect2i(172, 158, 14, 90), COAT_DK)
	img.fill_rect(Rect2i(108, 150, 40, 18), HAIR)
	_disc(img, 128, 118, 50, 54, SKIN)
	_disc(img, 128, 58, 36, 28, HAIR)
	_disc(img, 96, 78, 14, 22, HAIR_DK)
	_disc(img, 160, 78, 14, 22, HAIR_DK)
	_disc(img, 108, 128, 10, 6, SKIN_SH)
	_disc(img, 148, 128, 10, 6, SKIN_SH)
	_ring(img, 108, 116, 16, GLASS)
	_ring(img, 148, 116, 16, GLASS)
	img.fill_rect(Rect2i(122, 114, 12, 3), GLASS)
	_disc(img, 108, 116, 3, 3, INK)
	_disc(img, 148, 116, 3, 3, INK)
	img.fill_rect(Rect2i(118, 148, 20, 3), Color(0.62, 0.36, 0.34, 1))
	img.fill_rect(Rect2i(96, 168, 64, 8), STRAP)
	img.fill_rect(Rect2i(122, 186, 8, 8), GOLD)
	img.fill_rect(Rect2i(122, 210, 8, 8), GOLD)
	return UiBuild.keep(_images, "bust", img)

static func _well(img: Image) -> void:
	_disc(img, 64, 128, 52, 58, FELT_DK)
	_ring(img, 64, 128, 52, GOLD)

static func _disc(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	var y: int = cy - ry
	while y <= cy + ry:
		var x: int = cx - rx
		while x <= cx + rx:
			var nx: float = float(x - cx) / float(maxi(rx, 1))
			var ny: float = float(y - cy) / float(maxi(ry, 1))
			if nx * nx + ny * ny <= 1.0:
				_px(img, x, y, col)
			x += 1
		y += 1

static func _ring(img: Image, cx: int, cy: int, radius: int, col: Color) -> void:
	var inner: float = float(radius - 3)
	var y: int = cy - radius
	while y <= cy + radius:
		var x: int = cx - radius
		while x <= cx + radius:
			var d: float = Vector2(x - cx, y - cy).length()
			if d <= float(radius) and d >= inner:
				_px(img, x, y, col)
			x += 1
		y += 1

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)
