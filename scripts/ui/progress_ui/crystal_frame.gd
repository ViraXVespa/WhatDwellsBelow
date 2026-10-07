extends Object

## Loadout menu built as the hub floor crystal: a skin for frame_base.gd.
## The world crystal sprite stays on the prop. The gear board stays in the rows; this frame is only the chrome around it.
## The cream plate stays for every other progress panel and only anchors this menu's prompt.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/crystal_art.gd")

const SCALE: float = 3.0
const FRAME_POS: Vector2 = Vector2(300, 12)
const FRAME_SIZE: Vector2 = Vector2(Art.ART_W * SCALE, Art.ART_H * SCALE)
const FOOTER_ROOM: float = 0.0
## Pulls the prompt anchor up off the stone so the words sit on the pale facet.
const PLATE_INSET: Vector2 = Vector2(90, 226)

## Skin hook: where the frame sits, which mode shows it, where the gear board goes.
static func spec() -> Dictionary:
	var top: float = float(Art.PALE.position.y) * SCALE + 12.0
	var left: float = float(Art.PALE.position.x) * SCALE + 16.0
	var width: float = float(Art.PALE.size.x) * SCALE - 32.0
	return {
		"mode": "loadout", "chrome": "crystal_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"plate_inset": PLATE_INSET,
		"rows_pos": FRAME_POS + Vector2(left, top), "rows_size": Vector2(width, 574.0),
		"sep": 8, "blank_rows": true,
	}

## Skin hook: make the pieces once.
static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "crystal_body", Art.body())

## Skin hook: position the picture each time the frame opens.
static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "crystal_body", Vector2.ZERO, FRAME_SIZE)
