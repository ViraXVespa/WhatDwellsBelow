extends Object

## Vendor menu built as a stall front: a skin for frame_base.gd. The world stall sprite stays on the building.
## Posts, awning, and counter are drawn for this menu (vendor_art.gd). The cream plate stays for every
## other progress panel and only anchors this menu's prompt footer.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/vendor_art.gd")

const FRAME_POS: Vector2 = Vector2(390, 110)
const FRAME_SIZE: Vector2 = Vector2(1140, 680)
const FOOTER_ROOM: float = 72.0
const POST_W: float = 56.0
const BEAM_H: float = 40.0
const AWNING_H: float = 176.0
const COUNTER_H: float = 390.0
const NAME_W: float = 640.0
const NAME_H: float = 92.0

## Skin hook: where the frame sits, which mode shows it, where the button row goes.
static func spec() -> Dictionary:
	var inner_x: float = POST_W + 108.0
	var inner_w: float = FRAME_SIZE.x - POST_W * 2.0 - 216.0
	return {
		"mode": "vendor", "chrome": "stall_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"rows_pos": FRAME_POS + Vector2(inner_x, FRAME_SIZE.y - COUNTER_H + 36.0), "rows_size": Vector2(inner_w, COUNTER_H - 56.0),
		"sep": 8, "blank_rows": false,
	}

## Skin hook: make the pieces and labels once.
static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "stall_mouth", Art.fill(Art.MOUTH))
	UiBuild.piece(chrome, "stall_post_l", Art.post(false))
	UiBuild.piece(chrome, "stall_post_r", Art.post(true))
	UiBuild.piece(chrome, "stall_beam", Art.grain(160, 32, 0.42, 0))
	UiBuild.piece(chrome, "stall_awning", Art.awning(560, 96))
	UiBuild.piece(chrome, "stall_counter", Art.grain(160, 48, 0.12, 0))
	UiBuild.piece(chrome, "stall_crate", Art.crate())
	UiBuild.piece(chrome, "stall_pot", Art.pot())
	for i: int in 7:
		var kind: int = i % 3
		var tex: Texture2D = Art.herb()
		if kind == 0:
			tex = Art.bulb()
		elif kind == 1:
			tex = Art.tool()
		UiBuild.piece(chrome, "stall_hang_%d" % i, tex)
	UiBuild.piece(chrome, "stall_board", Art.grain(160, 40, 0.8, 3))
	chrome.add_child(UiBuild.chrome_label("stall_title", 32, ThemeS.INK, false))
	chrome.add_child(UiBuild.chrome_label("stall_bank", 18, ThemeS.INK, true))
	chrome.add_child(UiBuild.chrome_label("stall_status", 20, Art.PAPER, true))

## Skin hook: position the pieces each time the frame opens.
static func place(chrome: Control) -> void:
	var span: Vector2 = FRAME_SIZE
	UiBuild.place(chrome, "stall_mouth", Vector2(POST_W, BEAM_H), Vector2(span.x - POST_W * 2.0, span.y - BEAM_H - COUNTER_H + 24.0))
	UiBuild.place(chrome, "stall_post_l", Vector2.ZERO, Vector2(POST_W, span.y))
	UiBuild.place(chrome, "stall_post_r", Vector2(span.x - POST_W, 0), Vector2(POST_W, span.y))
	UiBuild.place(chrome, "stall_beam", Vector2.ZERO, Vector2(span.x, BEAM_H))
	UiBuild.place(chrome, "stall_awning", Vector2(POST_W - 18.0, BEAM_H - 8.0), Vector2(span.x - POST_W * 2.0 + 36.0, AWNING_H))
	var counter_y: float = span.y - COUNTER_H
	UiBuild.place(chrome, "stall_counter", Vector2(POST_W - 6.0, counter_y), Vector2(span.x - POST_W * 2.0 + 12.0, COUNTER_H))
	UiBuild.place(chrome, "stall_crate", Vector2(POST_W + 14.0, counter_y + 36.0), Vector2(96, 96))
	UiBuild.place(chrome, "stall_pot", Vector2(span.x - POST_W - 112.0, counter_y + 16.0), Vector2(88, 116))
	var hang_y: float = BEAM_H + NAME_H + 18.0
	var hang_span: float = span.x - POST_W * 2.0 - 160.0
	for i: int in 7:
		var hx: float = POST_W + 80.0 + hang_span * (float(i) + 0.5) / 7.0 - 22.0
		UiBuild.place(chrome, "stall_hang_%d" % i, Vector2(hx, hang_y), Vector2(44, 100))
	var board_x: float = (span.x - NAME_W) * 0.5
	UiBuild.place(chrome, "stall_board", Vector2(board_x, BEAM_H + 6.0), Vector2(NAME_W, NAME_H))
	UiBuild.place(chrome, "stall_title", Vector2(board_x + 16.0, BEAM_H + 12.0), Vector2(NAME_W - 32.0, 42.0))
	UiBuild.place(chrome, "stall_bank", Vector2(board_x + 16.0, BEAM_H + 52.0), Vector2(NAME_W - 32.0, 32.0))
	UiBuild.place(chrome, "stall_status", Vector2(POST_W + 24.0, BEAM_H + AWNING_H - 8.0), Vector2(span.x - POST_W * 2.0 - 48.0, 36.0))

static func prepare(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("stall_chrome") as Control
	if chrome == null:
		return
	var title: Label = chrome.get_node("stall_title") as Label
	var bank: Label = chrome.get_node("stall_bank") as Label
	title.text = App.tr("shop.vendor_stall")
	bank.text = App.tr("shop.bank_g_ore_potions_and") % [App.bank_gold, App.bank_ore]
	host.status = chrome.get_node("stall_status") as Label
	host.status.text = ""

static func dress(button: Button, primary: bool) -> void:
	UiBuild.button_base(button)
	var lift: float = 0.7 if primary else 0.86
	var foot: int = 4 if primary else 1
	UiBuild.states(button, _plank(lift, foot), _plank(minf(lift + 0.1, 0.92), maxi(foot, 3)), _plank(0.42, 6), _plank(0.4, 8), _plank(0.75, 1))

static func refresh_bank(host: CanvasLayer) -> void:
	var chrome: Control = host.get_node_or_null("stall_chrome") as Control
	if chrome == null:
		return
	var bank: Label = chrome.get_node_or_null("stall_bank") as Label
	if bank:
		bank.text = App.tr("shop.bank_g_ore_potions_and") % [App.bank_gold, App.bank_ore]

static func _plank(lift: float, foot: int) -> StyleBoxTexture:
	return UiBuild.tex_box(Art.grain(96, 28, lift, foot), 8, 6, foot, true, 16, 8)
