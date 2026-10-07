extends Object

## Dumpster menu built as a bin front: a skin for frame_base.gd. The world dumpster sprite stays on the prop.
## Lid, mouth, bags, and the rusted body are drawn for this menu (dumpster_art.gd). The cream plate
## stays for every other progress panel and only anchors this menu's prompt footer.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/dumpster_art.gd")

const FRAME_POS: Vector2 = Vector2(460, 64)
const FRAME_SIZE: Vector2 = Vector2(1000, 748)
const FOOTER_ROOM: float = 72.0

const LID_POS: Vector2 = Vector2(36, 4)
const LID_SIZE: Vector2 = Vector2(928, 168)
const MOUTH_POS: Vector2 = Vector2(108, 156)
const MOUTH_SIZE: Vector2 = Vector2(784, 220)
const BODY_POS: Vector2 = Vector2(72, 318)
const BODY_SIZE: Vector2 = Vector2(856, 360)
const RIM_POS: Vector2 = Vector2(72, 304)
const RIM_SIZE: Vector2 = Vector2(856, 52)
const LABEL_POS: Vector2 = Vector2(150, 388)
const LABEL_SIZE: Vector2 = Vector2(700, 160)
const TITLE_POS: Vector2 = Vector2(174, 404)
const TITLE_SIZE: Vector2 = Vector2(652, 46)
const LINE_POS: Vector2 = Vector2(174, 452)
const LINE_SIZE: Vector2 = Vector2(652, 84)
const LEAVE_POS: Vector2 = Vector2(186, 564)
const LEAVE_SIZE: Vector2 = Vector2(628, 64)
const WHEEL_SIZE: Vector2 = Vector2(86, 86)
const WHEEL_L: Vector2 = Vector2(96, 648)
const WHEEL_R: Vector2 = Vector2(818, 648)
const BAG_L: Vector2 = Vector2(156, 188)
const BAG_R: Vector2 = Vector2(628, 180)
const BAG_C: Vector2 = Vector2(390, 206)
const SLAT_POS: Vector2 = Vector2(548, 196)

## Skin hook: where the frame sits, which mode shows it, where the button row goes.
static func spec() -> Dictionary:
	return {
		"mode": "flavor", "chrome": "dump_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"rows_pos": FRAME_POS + LEAVE_POS, "rows_size": LEAVE_SIZE, "sep": 0, "blank_rows": true,
	}

## Skin hook: make the pieces and labels once.
static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "dump_lid", Art.lid())
	UiBuild.piece(chrome, "dump_mouth", Art.mouth())
	UiBuild.piece(chrome, "dump_bag_c", Art.bag(2))
	UiBuild.piece(chrome, "dump_bag_l", Art.bag(0))
	UiBuild.piece(chrome, "dump_bag_r", Art.bag(1))
	UiBuild.piece(chrome, "dump_slat", Art.slat())
	UiBuild.piece(chrome, "dump_wheel_l", Art.wheel())
	UiBuild.piece(chrome, "dump_wheel_r", Art.wheel())
	UiBuild.piece(chrome, "dump_body", Art.body())
	UiBuild.piece(chrome, "dump_rim", Art.rim())
	UiBuild.piece(chrome, "dump_label", Art.label())
	chrome.add_child(UiBuild.chrome_label("dump_title", 28, ThemeS.INK, false))
	chrome.add_child(UiBuild.chrome_label("dump_line", 22, ThemeS.INK_SOFT, true))

## Skin hook: position the pieces each time the frame opens.
static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "dump_lid", LID_POS, LID_SIZE)
	UiBuild.place(chrome, "dump_mouth", MOUTH_POS, MOUTH_SIZE)
	UiBuild.place(chrome, "dump_bag_c", BAG_C, Vector2(150, 170))
	UiBuild.place(chrome, "dump_bag_l", BAG_L, Vector2(168, 200))
	UiBuild.place(chrome, "dump_bag_r", BAG_R, Vector2(176, 210))
	UiBuild.place(chrome, "dump_slat", SLAT_POS, Vector2(44, 128))
	var slat: Control = chrome.get_node("dump_slat") as Control
	slat.pivot_offset = Vector2(22, 120)
	slat.rotation = 0.4
	UiBuild.place(chrome, "dump_wheel_l", WHEEL_L, WHEEL_SIZE)
	UiBuild.place(chrome, "dump_wheel_r", WHEEL_R, WHEEL_SIZE)
	UiBuild.place(chrome, "dump_body", BODY_POS, BODY_SIZE)
	UiBuild.place(chrome, "dump_rim", RIM_POS, RIM_SIZE)
	UiBuild.place(chrome, "dump_label", LABEL_POS, LABEL_SIZE)
	UiBuild.place(chrome, "dump_title", TITLE_POS, TITLE_SIZE)
	UiBuild.place(chrome, "dump_line", LINE_POS, LINE_SIZE)

static func prepare(host: CanvasLayer, title: String, body: String) -> void:
	var chrome: Control = host.get_node_or_null("dump_chrome") as Control
	if chrome == null:
		return
	var title_l: Label = chrome.get_node("dump_title") as Label
	var line: Label = chrome.get_node("dump_line") as Label
	title_l.text = title
	line.text = body

static func dress(button: Button) -> void:
	UiBuild.button_base(button)
	UiBuild.ink_text(button)
	UiBuild.states(button, _flap(0.55, 2), _flap(0.72, 3), _flap(0.34, 4), _flap(0.64, 8), _flap(0.4, 1))

static func _flap(lift: float, foot: int) -> StyleBoxTexture:
	return UiBuild.tex_box(Art.flap(lift, foot), 16, 6, foot, false, 18, 6)
