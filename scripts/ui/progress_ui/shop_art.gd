extends Object

## Ghost shop counter: a pale cloth hood and a cold page. The shopkeep sprite stays on the prop.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const ART_W: int = 400
const ART_H: int = 320
const PAGE: Rect2i = Rect2i(28, 56, 344, 236)

const NIGHT: Color = Color(0.08, 0.10, 0.16, 1)
const CLOTH: Color = Color(0.73, 0.82, 0.88, 1)
const CLOTH_LT: Color = Color(0.88, 0.93, 0.95, 1)
const CLOTH_DK: Color = Color(0.42, 0.52, 0.62, 1)
const PAGE_COL: Color = Color(0.84, 0.90, 0.93, 1)
const STITCH: Color = Color(0.28, 0.38, 0.48, 1)
const FLAME: Color = Color(0.78, 0.92, 0.96, 1)
const FLAME_CORE: Color = Color(0.96, 0.97, 0.92, 1)

const ArtBake: GDScript = preload("res://scripts/ui/progress_ui/art_bake.gd")
const ART := "shop"
static var _images: Dictionary = {}

static func body() -> Texture2D:
	if ArtBake.hit(_images, ART, "body"):
		return _images["body"]
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	_fill(img, Rect2i(0, 0, ART_W, ART_H), NIGHT)
	_fill(img, Rect2i(10, 10, ART_W - 20, 40), CLOTH)
	_fill(img, Rect2i(10, 10, ART_W - 20, 6), CLOTH_LT)
	_fill(img, Rect2i(10, 46, 16, ART_H - 58), CLOTH_DK)
	_fill(img, Rect2i(ART_W - 26, 46, 16, ART_H - 58), CLOTH_DK)
	_fill(img, Rect2i(10, ART_H - 18, ART_W - 20, 10), CLOTH_DK)
	_fill(img, PAGE, PAGE_COL)
	_stitches(img, 18, 42, ART_W - 36)
	_folds(img)
	_flame(img, 200, 22)
	return UiBuild.keep(_images, "body", img)

## Pale cloth row. `lift` lightens the face; `foot` is the shadow under it.
static func shelf(lift: float, foot: int) -> Texture2D:
	var key: String = "shelf-%d-%d" % [int(round(lift * 100.0)), foot]
	if ArtBake.hit(_images, ART, key):
		return _images[key]
	var w: int = 96
	var h: int = 32
	var img: Image = Image.create(w, h + foot, false, Image.FORMAT_RGBA8)
	var face: Color = PAGE_COL.lerp(Color(1, 1, 1, 1), clampf(lift - 0.7, 0.0, 0.3))
	if lift < 0.75:
		face = CLOTH_DK.lerp(PAGE_COL, 0.35)
	for y: int in h:
		for x: int in w:
			var px: Color = face
			if x < 8:
				px = CLOTH
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				px = STITCH
			img.set_pixel(x, y, px)
	if foot > 0:
		_fill(img, Rect2i(4, h, w - 8, foot), Color(NIGHT, 0.45))
	return UiBuild.keep(_images, key, img)

## Dark hem for Leave.
static func bar() -> Texture2D:
	if ArtBake.hit(_images, ART, "bar"):
		return _images["bar"]
	var w: int = 96
	var h: int = 28
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fill(img, Rect2i(0, 0, w, h), NIGHT)
	_fill(img, Rect2i(3, 3, w - 6, h - 6), CLOTH_DK)
	_fill(img, Rect2i(3, 3, w - 6, 3), CLOTH)
	return UiBuild.keep(_images, "bar", img)

static func _folds(img: Image) -> void:
	_fill(img, Rect2i(14, 52, 3, ART_H - 74), CLOTH)
	_fill(img, Rect2i(ART_W - 17, 52, 3, ART_H - 74), CLOTH)
	_fill(img, Rect2i(PAGE.position.x - 3, PAGE.position.y, 3, PAGE.size.y), STITCH)
	_fill(img, Rect2i(PAGE.position.x + PAGE.size.x, PAGE.position.y, 3, PAGE.size.y), STITCH)

static func _stitches(img: Image, x0: int, y: int, span: int) -> void:
	var x: int = x0
	while x < x0 + span:
		img.set_pixel(x, y, STITCH)
		img.set_pixel(x, y + 1, STITCH)
		x += 6

static func _flame(img: Image, cx: int, cy: int) -> void:
	_fill(img, Rect2i(cx - 7, cy + 6, 14, 4), CLOTH_DK)
	_fill(img, Rect2i(cx - 3, cy - 2, 6, 8), FLAME)
	_fill(img, Rect2i(cx - 1, cy - 6, 2, 6), FLAME_CORE)

static func _fill(img: Image, rect: Rect2i, col: Color) -> void:
	img.fill_rect(rect, col)
