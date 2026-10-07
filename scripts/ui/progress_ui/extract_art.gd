extends Object

## The open extraction gate, drawn for the menu. The world sprite stays on the prop.
## One page: stone, a riveted iron frame, lit lanterns, and the cyan mouth.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")

const ART_W: int = 420
const ART_H: int = 340
## Pale field inside the portal. Wide enough for the inventory slot row and a 7-cell bag.
const PAGE: Rect2i = Rect2i(90, 68, 240, 220)

const STONE: Color = Color(0.34, 0.37, 0.34, 1)
const STONE_DK: Color = Color(0.24, 0.26, 0.24, 1)
const MORTAR: Color = Color(0.15, 0.16, 0.15, 1)
const MOSS: Color = Color(0.30, 0.46, 0.28, 1)
const IRON: Color = Color(0.36, 0.31, 0.27, 1)
const IRON_LT: Color = Color(0.62, 0.55, 0.46, 1)
const IRON_DK: Color = Color(0.16, 0.13, 0.11, 1)
const RIVET: Color = Color(0.78, 0.72, 0.60, 1)
const BRASS: Color = Color(0.66, 0.44, 0.16, 1)
const GLOW: Color = Color(1.0, 0.78, 0.28, 1)
const PORTAL: Color = Color(0.05, 0.42, 0.50, 1)
const PORTAL_LT: Color = Color(0.48, 0.92, 0.90, 1)
const PAGE_COL: Color = Color(0.74, 0.93, 0.91, 1)

static var _images: Dictionary = {}

static func body() -> Texture2D:
	if _images.has("body"):
		return _images["body"]
	var img := Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	_bricks(img)
	_portal(img)
	_fill(img, PAGE, PAGE_COL)
	_iron(img)
	_brackets(img)
	_lantern(img, 8, 130)
	_lantern(img, 386, 130)
	return UiBuild.keep(_images, "body", img)

## Iron bar for a send button. `warm` is the Send All plate.
static func bar(warm: bool) -> Texture2D:
	var key := "bar_warm" if warm else "bar_iron"
	if _images.has(key):
		return _images[key]
	var w := 96
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var face: Color = BRASS if warm else IRON
	var edge: Color = GLOW.lerp(BRASS, 0.4) if warm else IRON_LT
	_fill(img, Rect2i(0, 0, w, h), IRON_DK)
	_fill(img, Rect2i(3, 3, w - 6, h - 6), face)
	_fill(img, Rect2i(3, 3, w - 6, 3), edge)
	return UiBuild.keep(_images, key, img)

static func _bricks(img: Image) -> void:
	var bw := 18
	var bh := 10
	for y: int in ART_H:
		for x: int in ART_W:
			var row: int = int(y / bh)
			var shift: int = bw / 2 if row % 2 == 1 else 0
			var lx: int = (x + shift) % bw
			var ly: int = y % bh
			var px: Color = STONE
			if lx < 1 or ly < 1:
				px = MORTAR
			elif (x + y) % 7 == 0:
				px = STONE_DK
			if ly < 2 and (x * 3 + row * 5) % 17 == 0:
				px = MOSS
			img.set_pixel(x, y, px)

static func _portal(img: Image) -> void:
	var mouth := Rect2i(78, 54, 264, 248)
	var cx := float(mouth.position.x) + float(mouth.size.x) * 0.5
	var cy := float(mouth.position.y) + float(mouth.size.y) * 0.5
	for y: int in range(mouth.position.y, mouth.position.y + mouth.size.y):
		for x: int in range(mouth.position.x, mouth.position.x + mouth.size.x):
			var dx := (float(x) - cx) / (float(mouth.size.x) * 0.5)
			var dy := (float(y) - cy) / (float(mouth.size.y) * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var wave := 0.5 + 0.5 * sin(ang * 3.0 + d * 9.0)
			var px := PORTAL.lerp(PORTAL_LT, wave * (1.0 - clampf(d, 0.0, 1.0)))
			img.set_pixel(x, y, px)

static func _iron(img: Image) -> void:
	var outer := Rect2i(56, 32, 308, 284)
	var inner := Rect2i(78, 54, 264, 248)
	for y: int in range(outer.position.y, outer.position.y + outer.size.y):
		for x: int in range(outer.position.x, outer.position.x + outer.size.x):
			if x >= inner.position.x and x < inner.position.x + inner.size.x and y >= inner.position.y and y < inner.position.y + inner.size.y:
				continue
			var on_edge := x < outer.position.x + 3 or y < outer.position.y + 3 or x >= outer.position.x + outer.size.x - 3 or y >= outer.position.y + outer.size.y - 3
			img.set_pixel(x, y, IRON_LT if on_edge else IRON)
	var span_x := outer.size.x
	var span_y := outer.size.y
	for i: int in 8:
		var rx := outer.position.x + 16 + int(float(span_x - 32) * float(i) / 7.0)
		UiBuild.dot(img, rx, outer.position.y + 12, 3, RIVET)
		UiBuild.dot(img, rx, outer.position.y + span_y - 13, 3, RIVET)
	for i: int in 6:
		var ry := outer.position.y + 28 + int(float(span_y - 56) * float(i) / 5.0)
		UiBuild.dot(img, outer.position.x + 12, ry, 3, RIVET)
		UiBuild.dot(img, outer.position.x + span_x - 13, ry, 3, RIVET)

static func _brackets(img: Image) -> void:
	var spots: Array[Vector2i] = [Vector2i(46, 22), Vector2i(346, 22), Vector2i(46, 286), Vector2i(346, 286)]
	for spot: Vector2i in spots:
		_fill(img, Rect2i(spot.x, spot.y, 28, 28), IRON_DK)
		_fill(img, Rect2i(spot.x + 3, spot.y + 3, 22, 22), IRON_LT)
		UiBuild.dot(img, spot.x + 14, spot.y + 14, 5, RIVET)
		UiBuild.dot(img, spot.x + 14, spot.y + 14, 2, IRON_DK)

static func _lantern(img: Image, x: int, y: int) -> void:
	_fill(img, Rect2i(x + 8, y, 12, 6), IRON_DK)
	_fill(img, Rect2i(x + 4, y + 8, 20, 28), BRASS)
	_fill(img, Rect2i(x + 8, y + 12, 12, 16), GLOW)
	_fill(img, Rect2i(x + 6, y + 36, 16, 5), IRON_DK)
	UiBuild.dot(img, x + 14, y + 20, 4, Color(1, 0.95, 0.7, 1))

static func _fill(img: Image, rect: Rect2i, col: Color) -> void:
	var x0 := clampi(rect.position.x, 0, img.get_width())
	var y0 := clampi(rect.position.y, 0, img.get_height())
	var x1 := clampi(rect.position.x + rect.size.x, 0, img.get_width())
	var y1 := clampi(rect.position.y + rect.size.y, 0, img.get_height())
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			img.set_pixel(x, y, col)
