extends Object

## How-to-Play pamphlet: olive cover, ruled page, a ribbon. Separate from the cream plate and the desk.
## Bake with tools/bake_frame_art.py.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const ArtBake: GDScript = preload("res://scripts/ui/progress_ui/art_bake.gd")

const ART := "guide"
const ART_W: int = 440
const ART_H: int = 300

const COVER := Color(0.16, 0.24, 0.18, 1)
const COVER_LT := Color(0.28, 0.38, 0.28, 1)
const SPINE := Color(0.10, 0.14, 0.11, 1)
const PAGE := Color(0.95, 0.91, 0.80, 1)
const RULE := Color(0.62, 0.50, 0.36, 0.55)
const RIBBON := Color(0.55, 0.24, 0.20, 1)

static var _images: Dictionary = {}

static func body() -> Texture2D:
	if ArtBake.hit(_images, ART, "body"):
		return _images["body"]
	var img: Image = Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	img.fill(COVER)
	img.fill_rect(Rect2i(0, 0, ART_W, 8), COVER_LT)
	img.fill_rect(Rect2i(0, 0, 18, ART_H), SPINE)
	img.fill_rect(Rect2i(28, 22, ART_W - 48, ART_H - 40), PAGE)
	var y: int = 34
	while y < ART_H - 16:
		img.fill_rect(Rect2i(36, y, ART_W - 64, 1), RULE)
		y += 14
	img.fill_rect(Rect2i(40, 34, 340, 250), PAGE)
	img.fill_rect(Rect2i(ART_W - 28, 8, 10, 64), RIBBON)
	img.fill_rect(Rect2i(ART_W - 32, 66, 18, 10), RIBBON)
	return UiBuild.keep(_images, "body", img)
