extends Object

## Anvil menu built as the hub anvil on its stump: a skin for frame_base.gd.
## The world anvil sprite stays on the prop. The gear board stays in the rows; this frame is only the chrome around it.
## The cream plate stays for every other progress panel.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/anvil_art.gd")

const FRAME_POS: Vector2 = Vector2(340, 24)
const FRAME_SIZE: Vector2 = Vector2(1240, 980)
const FOOTER_ROOM: float = 0.0
## Pulls the prompt anchor inside the bark so the words sit on the light face.
const PLATE_INSET: Vector2 = Vector2(76, 96)
const ANVIL_POS: Vector2 = Vector2(400, 18)
const ANVIL_SIZE: Vector2 = Vector2(440, 269)

## Skin hook: where the frame sits, which mode shows it, where the gear board goes.
static func spec() -> Dictionary:
	var rows_pos: Vector2 = Vector2(96, 300)
	var rows_size: Vector2 = Vector2(FRAME_SIZE.x - 192.0, FRAME_SIZE.y - 300.0 - 72.0)
	return {
		"mode": "anvil", "chrome": "anvil_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"plate_inset": PLATE_INSET,
		"rows_pos": FRAME_POS + rows_pos, "rows_size": rows_size,
		"sep": 8, "blank_rows": true,
	}

## Skin hook: make the pieces once.
static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "anvil_stump", Art.stump())
	UiBuild.piece(chrome, "anvil_shadow", Art.shadow())
	UiBuild.piece(chrome, "anvil_iron", Art.anvil())

## Skin hook: position the pieces each time the frame opens.
static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "anvil_stump", Vector2.ZERO, FRAME_SIZE)
	UiBuild.place(chrome, "anvil_shadow", ANVIL_POS + Vector2(40, ANVIL_SIZE.y - 18.0), Vector2(ANVIL_SIZE.x - 40.0, 28))
	UiBuild.place(chrome, "anvil_iron", ANVIL_POS, ANVIL_SIZE)
