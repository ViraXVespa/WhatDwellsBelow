extends Object

## Controls menu built as the hub sign: a skin for frame_base.gd. The world sign sprite stays on the prop.
## Wood rails, iron corners, the dark board, and the two posts are drawn for this menu (controls_art.gd).
## The cream plate stays for every other progress panel and only anchors this menu's prompt footer.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/controls_art.gd")

const FRAME_POS: Vector2 = Vector2(650, 16)
const FRAME_SIZE: Vector2 = Vector2(620, 880)
const FOOTER_ROOM: float = 72.0
const BOARD_H: float = 768.0
const RAIL: float = 40.0
const POST_W: float = 48.0
const POST_H: float = 124.0
const BRACKET: float = 68.0
const TEXT_TOP: float = 146.0
const COL_W: float = 220.0

## Skin hook: where the frame sits, which mode shows it, where the binding rows go.
static func spec() -> Dictionary:
	var rows_h: float = BOARD_H - RAIL - 14.0 - TEXT_TOP
	var rows_x: float = (FRAME_SIZE.x - COL_W) * 0.5
	return {
		"mode": "controls", "chrome": "sign_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"rows_pos": FRAME_POS + Vector2(rows_x, TEXT_TOP), "rows_size": Vector2(COL_W, rows_h),
		"sep": 6, "blank_rows": true,
	}

## Skin hook: make the pieces and labels once.
static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "sign_post_l", Art.post())
	UiBuild.piece(chrome, "sign_post_r", Art.post())
	UiBuild.piece(chrome, "sign_face", Art.face())
	UiBuild.piece(chrome, "sign_stile_l", Art.grain(false))
	UiBuild.piece(chrome, "sign_stile_r", Art.grain(false))
	UiBuild.piece(chrome, "sign_rail_t", Art.grain(true))
	UiBuild.piece(chrome, "sign_rail_b", Art.grain(true))
	UiBuild.piece(chrome, "sign_br_tl", Art.bracket())
	UiBuild.piece(chrome, "sign_br_tr", Art.bracket())
	UiBuild.piece(chrome, "sign_br_bl", Art.bracket())
	UiBuild.piece(chrome, "sign_br_br", Art.bracket())
	chrome.add_child(UiBuild.chrome_label("sign_title", 32, ThemeS.PAPER, false))
	chrome.add_child(UiBuild.chrome_label("sign_line", 18, ThemeS.PAPER, true))

## Skin hook: position the pieces each time the frame opens.
static func place(chrome: Control) -> void:
	var span: Vector2 = FRAME_SIZE
	var post_y: float = BOARD_H - 18.0
	UiBuild.place(chrome, "sign_post_l", Vector2(72, post_y), Vector2(POST_W, POST_H))
	UiBuild.place(chrome, "sign_post_r", Vector2(span.x - 72.0 - POST_W, post_y), Vector2(POST_W, POST_H))
	UiBuild.place(chrome, "sign_face", Vector2(RAIL - 4.0, RAIL - 4.0), Vector2(span.x - RAIL * 2.0 + 8.0, BOARD_H - RAIL * 2.0 + 8.0))
	UiBuild.place(chrome, "sign_stile_l", Vector2.ZERO, Vector2(RAIL, BOARD_H))
	UiBuild.place(chrome, "sign_stile_r", Vector2(span.x - RAIL, 0), Vector2(RAIL, BOARD_H))
	UiBuild.place(chrome, "sign_rail_t", Vector2.ZERO, Vector2(span.x, RAIL))
	UiBuild.place(chrome, "sign_rail_b", Vector2(0, BOARD_H - RAIL), Vector2(span.x, RAIL))
	UiBuild.place(chrome, "sign_br_tl", Vector2(6, 6), Vector2(BRACKET, BRACKET))
	UiBuild.place(chrome, "sign_br_tr", Vector2(span.x - 6.0 - BRACKET, 6), Vector2(BRACKET, BRACKET))
	UiBuild.place(chrome, "sign_br_bl", Vector2(6, BOARD_H - 6.0 - BRACKET), Vector2(BRACKET, BRACKET))
	UiBuild.place(chrome, "sign_br_br", Vector2(span.x - 6.0 - BRACKET, BOARD_H - 6.0 - BRACKET), Vector2(BRACKET, BRACKET))
	_flip(chrome, "sign_br_tr", true, false)
	_flip(chrome, "sign_br_bl", false, true)
	_flip(chrome, "sign_br_br", true, true)
	var text_w: float = span.x - 120.0
	UiBuild.place(chrome, "sign_title", Vector2(60, 52), Vector2(text_w, 46))
	UiBuild.place(chrome, "sign_line", Vector2(60, 98), Vector2(text_w, 42))

static func prepare(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("sign_chrome") as Control
	if chrome == null:
		return
	var title: Label = chrome.get_node("sign_title") as Label
	var line: Label = chrome.get_node("sign_line") as Label
	title.text = App.tr("common.controls_billboard")
	line.text = App.tr("ui_hub.what_the_guild_painted_up")

static func dress(button: Button) -> void:
	UiBuild.button_base(button)
	UiBuild.ink_text(button)
	UiBuild.states(button, _plank(0.62, 3), _plank(0.78, 3), _plank(0.34, 5), _plank(0.7, 4), _plank(0.4, 1))

static func _plank(lift: float, foot: int) -> StyleBoxTexture:
	return UiBuild.tex_box(Art.plank(lift, foot), 10, 4, foot, true, 16, 6)

static func _flip(chrome: Control, node_name: String, flip_h: bool, flip_v: bool) -> void:
	var rect: TextureRect = chrome.get_node(node_name) as TextureRect
	rect.flip_h = flip_h
	rect.flip_v = flip_v
