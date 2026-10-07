extends Object

## Extraction gate as one page on the open gate: stone, iron, lanterns, cyan mouth.
## The world gate sprite stays on the prop. The cream plate stays for every other panel.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const Art: GDScript = preload("res://scripts/ui/progress_ui/extract_art.gd")

const SCALE: float = 3.0
const FRAME_POS: Vector2 = Vector2(330, 24)
const FRAME_SIZE: Vector2 = Vector2(Art.ART_W * SCALE, Art.ART_H * SCALE)
const FOOTER_ROOM: float = 0.0
## Pulls the prompt onto the pale page, clear of the iron.
const PLATE_INSET: Vector2 = Vector2(250, 150)

## Skin hook: where the gate sits, and where the one page of rows goes.
static func spec() -> Dictionary:
	var page := Art.PAGE
	var pad := 18.0
	var rows_pos := FRAME_POS + Vector2(float(page.position.x) * SCALE + pad, float(page.position.y) * SCALE + pad)
	var rows_size := Vector2(float(page.size.x) * SCALE - pad * 2.0, float(page.size.y) * SCALE - pad * 2.0 - 36.0)
	return {
		"mode": "extract", "chrome": "extract_chrome", "pos": FRAME_POS, "size": FRAME_SIZE, "footer": FOOTER_ROOM,
		"plate_inset": PLATE_INSET,
		"rows_pos": rows_pos, "rows_size": rows_size,
		"sep": 8, "blank_rows": true,
	}

static func build(chrome: Control) -> void:
	UiBuild.piece(chrome, "gate_body", Art.body())

static func place(chrome: Control) -> void:
	UiBuild.place(chrome, "gate_body", Vector2.ZERO, FRAME_SIZE)

static func dress(button: Button, primary: bool) -> void:
	UiBuild.button_base(button)
	var face: Texture2D = Art.bar(primary)
	var focus: Texture2D = Art.bar(true)
	UiBuild.states(button, UiBuild.tex_box(face, 6, 4, 2, false, 12, 6), UiBuild.tex_box(focus, 6, 4, 3, false, 12, 6), UiBuild.tex_box(Art.bar(false), 6, 6, 4, false, 12, 6), UiBuild.tex_box(focus, 6, 4, 4, false, 12, 6), UiBuild.tex_box(face, 6, 4, 1, false, 12, 6))
	var ink := Color(0.93, 0.95, 0.90, 1)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.90, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 0.97, 0.86, 1))
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(ink, 0.45))
	button.add_theme_font_override("font", ThemeS.ink_font())
