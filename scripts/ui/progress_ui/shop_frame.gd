extends Object

## Ghost shop as a cloth counter. The world shopkeep stays on the prop. The cream plate stays for every other panel.

const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/shop_art.gd")

const BTN_SKIN := "neutral"
const SCALE: float = 3.0
const FRAME_POS: Vector2 = Vector2(360, 24)
const FRAME_SIZE: Vector2 = Vector2(Art.ART_W * SCALE, Art.ART_H * SCALE)
const FOOTER_ROOM: float = 0.0
const PLATE_INSET: Vector2 = Vector2(80, 48)

static func spec() -> Dictionary:
	var page: Rect2i = Art.PAGE
	var pad := 16.0
	var rows_pos: Vector2 = FRAME_POS + Vector2(float(page.position.x) * SCALE + pad, float(page.position.y) * SCALE + pad)
	var rows_size: Vector2 = Vector2(float(page.size.x) * SCALE - pad * 2.0, float(page.size.y) * SCALE - pad * 2.0 - 72.0)
	return FrameBase.make_spec("shop", "shop_chrome", FRAME_POS, FRAME_SIZE, FOOTER_ROOM, rows_pos, rows_size, {"plate_inset": PLATE_INSET, "blank_rows": false})

static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "shop_body", Art.body())
	Art.shelf(0.92, 2)
	Art.shelf(0.98, 2)
	Art.shelf(0.62, 4)
	Art.shelf(0.5, 2)
	Art.bar()

static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "shop_body", Vector2.ZERO, FRAME_SIZE)

static func dress(button: Button) -> void:
	UiBuild.button_base(button)
	var face: Texture2D = Art.bar()
	var box: StyleBoxTexture = UiBuild.tex_box(face, 6, 4, 2, false, 12, 6)
	UiBuild.states(button, box, box, box, box, box)
	var ink := Color(0.93, 0.96, 0.97, 1)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(ink, 0.45))
	button.add_theme_font_override("font", ThemeS.ink_font())

static func dress_shelf(button: Button) -> void:
	UiBuild.button_base(button)
	UiBuild.ink_text(button)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiBuild.states(button, _shelf(0.92, 2), _shelf(0.98, 2), _shelf(0.62, 4), ThemeS.BtnSkin.ring(ThemeS.BtnSkin.palette(BTN_SKIN)), _shelf(0.5, 2))

static func _shelf(lift: float, foot: int) -> StyleBoxTexture:
	return UiBuild.tex_box(Art.shelf(lift, foot), 8, 6, foot, false, 12, 6)
