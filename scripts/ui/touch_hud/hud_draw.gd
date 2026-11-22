extends Object

## Touch HUD drawing. Geometry comes from hud_layout.gd; wells are translucent dark discs with light ink so the
## world stays readable under them. Buttons say what they do (Attack, Special, Dash, Use), not pad glyphs.

const Touch := preload("res://scripts/input/touch_pad.gd")
const PadInput := preload("res://scripts/ui/touch_hud/hud_input.gd")
const TouchLayout := preload("res://scripts/ui/touch_hud/hud_layout.gd")
const BowMode := preload("res://scripts/world/player/bow_mode.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")

const INK := Color(0.98, 0.95, 0.88, 0.97)
const INK_DIM := Color(0.80, 0.76, 0.70, 0.40)
const WELL := Color(0.07, 0.05, 0.04, 0.42)
const WELL_DIM := Color(0.07, 0.05, 0.04, 0.20)
const PRESS := Color(Tok.PAPER, 0.55)
const RING := Color(0.98, 0.93, 0.82, 0.62)
const RING_DIM := Color(0.98, 0.93, 0.82, 0.22)
const LIVE := Color(0.98, 0.78, 0.38, 0.95)
const LABELS := {"attack": "hud_draw.attack", "special": "hud_draw.special", "dash": "hud_draw.dash",
	"interact": "hud_draw.use", "map_view": "hud_draw.map", "pause": "hud_draw.pause"}
const CAMP_OFF: PackedStringArray = ["map_view", "food", "potion", "target_lock"]

static func ready(host: CanvasLayer) -> void:
	host.layer = 28
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.root = Control.new()
	host.root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.root.draw.connect(host._draw_pad)
	host.add_child(host.root)

static func tick(host: CanvasLayer, _delta: float) -> void:
	var pad_on := Touch.wants_show()
	if pad_on != bool(host.get_meta("prompt_touch", false)):
		# World prompt chips swap pad glyphs for touch button words (prompts.gd touch_word) when the overlay comes or goes.
		host.set_meta("prompt_touch", pad_on)
		if load("res://scripts/input/prompts.gd").dirty():
			load("res://scripts/ui/prompt_view.gd").pulse()
	host.visible = pad_on
	host.root.mouse_filter = Control.MOUSE_FILTER_STOP if pad_on else Control.MOUSE_FILTER_IGNORE
	if not pad_on:
		PadInput.release_all(host)
		return
	layout(host)
	host.root.queue_redraw()

static func layout(host: CanvasLayer) -> void:
	var vp := host.get_viewport().get_visible_rect().size
	var ins := Touch.safe_insets(vp)
	host._move_r = TouchLayout.move_radius(vp)
	host._move_home = TouchLayout.move_home(vp, ins)
	host._btns = TouchLayout.compute(vp, ins, BowMode.active())

static func dimmed(action: String) -> bool:
	return Touch.in_camp() and CAMP_OFF.has(action)

static func draw_pad(host: CanvasLayer) -> void:
	if host._move_live:
		well(host, host._move_origin, host._move_r, false, false)
		knob(host, host._move_knob, host._move_r * 0.4)
	else:
		host.root.draw_arc(host._move_home, host._move_r, 0.0, TAU, 48, RING_DIM, 2.0, true)
		knob(host, host._move_home, host._move_r * 0.4, true)
	for row: Dictionary in host._btns:
		var action := str(row["action"])
		var pos: Vector2 = row["pos"]
		var r: float = float(row["r"])
		var dim := dimmed(action)
		var on := Touch.held(action) and not dim
		if str(row["kind"]) == "stick":
			on = Touch.held("aim")
		well(host, pos, r, on, dim, action == "target_lock" and PadInput.lock_on())
		face(host, row, pos, r, dim)

static func well(host: CanvasLayer, c: Vector2, r: float, on := false, dim := false, live := false) -> void:
	host.root.draw_circle(c, r, PRESS if on else (WELL_DIM if dim else WELL))
	host.root.draw_arc(c, r, 0.0, TAU, 48, LIVE if live else (RING_DIM if dim else RING), 3.0 if live else 2.2, true)

static func knob(host: CanvasLayer, c: Vector2, r: float, idle := false) -> void:
	host.root.draw_circle(c, r, Color(INK, 0.18) if idle else Color(INK, 0.55))
	host.root.draw_arc(c, r, 0.0, TAU, 32, RING_DIM if idle else RING, 2.0, true)

static func face(host: CanvasLayer, row: Dictionary, c: Vector2, r: float, dim: bool) -> void:
	var action := str(row["action"])
	var ink := INK_DIM if dim else INK
	if str(row["kind"]) == "stick":
		var k: Vector2 = c + Touch.aim * r * 0.6
		knob(host, k, r * 0.34)
		text(host, App.tr("hud_draw.aim"), c + Vector2(0.0, r * 0.62), r * 0.26, ink)
		return
	if action == "potion" or action == "food":
		var hud: Object = _hud()
		var icon: TextureRect = hud.get("pot_icon" if action == "potion" else "food_icon") as TextureRect if hud else null
		var tex: Texture2D = icon.texture if icon else Icons.tex_for_slot(action, {})
		if tex:
			var s := r * 1.1
			var tint: Color = icon.modulate if icon else Color.WHITE
			tint.a *= 0.4 if dim else 1.0
			host.root.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
		var cnt: Label = hud.get("pot_lab" if action == "potion" else "food_lab") as Label if hud else null
		if cnt and cnt.text != "" and not dim:
			text(host, cnt.text, c + Vector2(r * 0.55, r * 0.62), r * 0.40, ink)
		return
	if action == "target_lock":
		var a := r * 0.5
		host.root.draw_arc(c, a * 0.62, 0.0, TAU, 24, ink, 2.4, true)
		for v: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			host.root.draw_line(c + v * a * 0.35, c + v * a, ink, 2.4, true)
		return
	text(host, App.tr(str(LABELS.get(action, action))), c, r * (0.42 if r < 60.0 else 0.34), ink)

static func text(host: CanvasLayer, s: String, c: Vector2, px: float, ink: Color) -> void:
	var font: Font = ThemeS.ink_font()
	var fs := int(maxf(12.0, px))
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(c.x - w * 0.5, c.y + fs * 0.34)
	host.root.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.55))
	host.root.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

## The in-play HUD (its potion / food icons and counts are the source of truth for the item slots).
static func _hud() -> Object:
	var scene: Node = PadInput.dungeon()
	return scene.get("hud") if scene else null
