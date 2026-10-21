extends Object

## Talk frame. Bust on the felt, speech sheet over the rows. The cream plate stays hidden while this mode is open.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/receptionist_art.gd")

const BTN_SKIN := "neutral"
const FRAME_POS: Vector2 = Vector2(240, 90)
const FRAME_SIZE: Vector2 = Vector2(1440, 840)
const SPEECH_POS: Vector2 = Vector2(340, 36)
const SPEECH_SIZE: Vector2 = Vector2(1060, 790)
const BUST_POS: Vector2 = Vector2(64, 250)
const BUST_SIZE: Vector2 = Vector2(256, 256)
const ROWS_LOCAL: Vector2 = Vector2(380, 100)
const ROWS_SIZE: Vector2 = Vector2(980, 640)
const FOOTER_ROOM: float = 0.0

static func spec() -> Dictionary:
	return FrameBase.make_spec("receptionist", "receptionist_chrome", FRAME_POS, FRAME_SIZE, FOOTER_ROOM, FRAME_POS + ROWS_LOCAL, ROWS_SIZE, {"blank_rows": true, "sep": 6, "plate_inset": Vector2(80, 0)})

static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "desk", Art.body())
	var bubble := NinePatchRect.new()
	bubble.name = "speech"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.texture = Art.speech()
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.patch_margin_left = 24
	bubble.patch_margin_top = 24
	bubble.patch_margin_right = 24
	bubble.patch_margin_bottom = 24
	chrome.add_child(bubble)
	UiBuild.piece(chrome, "bust", Art.bust())

static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "desk", Vector2.ZERO, FRAME_SIZE)
	UiBuild.place(chrome, "speech", SPEECH_POS, SPEECH_SIZE)
	UiBuild.place(chrome, "bust", BUST_POS, BUST_SIZE)
