extends Object

## How-to-Play page. One pamphlet for every topic. The cream plate stays hidden while this mode is open.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/guide_art.gd")

const BTN_SKIN := "neutral"
const SCALE: float = 3.0
const FRAME_POS: Vector2 = Vector2(300, 48)
const FRAME_SIZE: Vector2 = Vector2(Art.ART_W * SCALE, Art.ART_H * SCALE)
const ROWS_LOCAL: Vector2 = Vector2(120, 100)
const ROWS_SIZE: Vector2 = Vector2(1020, 680)
const FOOTER_ROOM: float = 0.0

static func spec() -> Dictionary:
	return FrameBase.make_spec("guide", "guide_chrome", FRAME_POS, FRAME_SIZE, FOOTER_ROOM, FRAME_POS + ROWS_LOCAL, ROWS_SIZE, {"blank_rows": true, "sep": 12, "plate_inset": Vector2(100, 0)})

static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "pamphlet", Art.body())

static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "pamphlet", Vector2.ZERO, FRAME_SIZE)
