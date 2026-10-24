extends Object

## Notice-board frame. The cork rect is where quest_board.gd pins posters. The cream plate stays for every other mode.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
## Fixed board art: text scales up to this on small screens (ui_text.gd cap), then the board would overflow.
const TEXT_CAP := 1.4
const Art: GDScript = preload("res://scripts/ui/progress_ui/poster_art.gd")

const BTN_SKIN := "neutral"
const FRAME_POS: Vector2 = Vector2(360, 100)
const FRAME_SIZE: Vector2 = Vector2(1200, 700)
const CORK_POS: Vector2 = Vector2(90, 155)
const CORK_SIZE: Vector2 = Vector2(1020, 480)
const FOOTER_ROOM: float = 88.0

static func spec() -> Dictionary:
	var rows_pos: Vector2 = FRAME_POS + CORK_POS
	return FrameBase.make_spec("quest", "quest_chrome", FRAME_POS, FRAME_SIZE, FOOTER_ROOM, rows_pos, CORK_SIZE, {"plate_inset": Vector2(48, 0), "blank_rows": true, "sep": 0})

static func build(chrome: Control) -> void:
	var body: TextureRect = UiBuild.piece(chrome, "board_body", Art.tex("board.png"))
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var title: Label = ThemeS.lab(App.tr("ui_hub.guild_tasks"), 28, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER, false, false)
	title.name = "board_title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(title)

static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "board_body", Vector2.ZERO, FRAME_SIZE)
	var title: Label = chrome.get_node("board_title") as Label
	title.position = Vector2(300, 46)
	title.size = Vector2(600, 56)
