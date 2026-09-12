extends Object

## Touch HUD layout and pad drawing.

const Touch := preload("res://scripts/input/touch_pad.gd")
const PadInput := preload("res://scripts/ui/touch_hud_input.gd")

const GLYPH := {
	"attack": "res://assets/ui/prompts/pad/rt.png",
	"special": "res://assets/ui/prompts/pad/lt.png",
	"dash": "res://assets/ui/prompts/pad/b.png",
	"interact": "res://assets/ui/prompts/pad/a.png",
	"pause": "res://assets/ui/prompts/pad/menu.png",
	"map_view": "res://assets/ui/prompts/pad/view.png",
	"potion": "res://assets/ui/prompts/pad/dpad_up.png",
	"food": "res://assets/ui/prompts/pad/dpad_left.png",
}

const INK := Color(0.92, 0.84, 0.62, 0.78)
const INK_DIM := Color(0.92, 0.84, 0.62, 0.28)
const WELL := Color(0.22, 0.16, 0.12, 0.32)
const WELL_DIM := Color(0.16, 0.12, 0.10, 0.20)
const RING := Color(0.5, 0.38, 0.2, 0.52)
const RING_DIM := Color(0.4, 0.3, 0.16, 0.26)
const KNOB := Color(0.9, 0.7, 0.3, 0.82)
const PRESS := Color(0.16, 0.12, 0.08, 0.48)
const LATCH := Color(0.95, 0.78, 0.35, 0.78)


static func ready(host: CanvasLayer) -> void:
	host.layer = 28
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.root = Control.new()
	host.root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.root.draw.connect(host._draw_pad)
	host.add_child(host.root)
	for action in GLYPH.keys():
		var p := str(GLYPH[action])
		if ResourceLoader.exists(p):
			host._tex[action] = load(p)

static func tick(host: CanvasLayer, _delta: float) -> void:
	var pad_on := Touch.wants_show()
	host.visible = pad_on
	host.root.mouse_filter = Control.MOUSE_FILTER_STOP if pad_on else Control.MOUSE_FILTER_IGNORE
	if not pad_on:
		PadInput.release_all(host)
		return
	layout(host)
	host.root.queue_redraw()

static func layout(host: CanvasLayer) -> void:
	var vp := host.get_viewport().get_visible_rect().size
	var sc: float = clampf(minf(vp.x, vp.y) / 1080.0, 0.7, 1.35)
	host._move_r = 98.0 * sc
	var sr0 := 28.0 * sc
	var gap0 := 6.0 * sc
	var br0 := sr0 * 2.0
	var span0 := br0 * 2.0 + gap0
	var cx0 := vp.x * 0.86
	var cy0 := vp.y * 0.78
	var pad := 18.0 * sc
	var half_w0 := span0 * 0.5 + br0
	var half_h0 := span0 * 0.5 + br0
	var row_h0 := sr0 * 2.0 + gap0
	cx0 = clampf(cx0, vp.x * 0.52 + half_w0, vp.x - pad - half_w0)
	cy0 = clampf(cy0, pad + row_h0 + half_h0, vp.y - pad - half_h0)
	var rx := cx0 + span0 * 0.5
	var by := cy0 + span0 * 0.5
	var sr := sr0 * 1.25
	var gap := gap0 * 1.25
	var br := sr * 2.0
	var span := br * 2.0 + gap
	var lx := rx - span
	var ty := by - span
	var cx := (lx + rx) * 0.5
	var small_span := sr * 2.0 + gap
	var row_y := ty - br - gap - sr
	var row_w := small_span * 3.0
	var s0 := cx - row_w * 0.5
	host._btns = [
		{"action": "map_view", "pos": Vector2(s0, row_y), "r": sr},
		{"action": "food", "pos": Vector2(s0 + small_span, row_y), "r": sr},
		{"action": "potion", "pos": Vector2(s0 + small_span * 2.0, row_y), "r": sr},
		{"action": "pause", "pos": Vector2(s0 + small_span * 3.0, row_y), "r": sr},
		{"action": "attack", "pos": Vector2(lx, ty), "r": br},
		{"action": "special", "pos": Vector2(rx, ty), "r": br},
		{"action": "interact", "pos": Vector2(lx, by), "r": br},
		{"action": "dash", "pos": Vector2(rx, by), "r": br},
	]

static func draw_pad(host: CanvasLayer) -> void:
	if host._move_live:
		well(host, host._move_origin, host._move_r)
		knob(host, host._move_knob, host._move_r * 0.38)
	for row in host._btns:
		var action := str(row["action"])
		var pos: Vector2 = row["pos"]
		var r: float = float(row["r"])
		var dim := action == "map_view" and Touch.in_camp()
		var on := Touch.held(action) and not dim
		if action == "attack" and Touch.attack_latch:
			on = true
		well(host, pos, r, on, dim)
		glyph(host, action, pos, r, dim)

static func well(host: CanvasLayer, c: Vector2, r: float, on := false, dim := false) -> void:
	var fill := WELL_DIM if dim else (PRESS if on else WELL)
	var ring := RING_DIM if dim else (LATCH if on else RING)
	host.root.draw_circle(c, r, fill)
	host.root.draw_arc(c, r, 0.0, TAU, 48, ring, 2.4, true)

static func knob(host: CanvasLayer, c: Vector2, r: float) -> void:
	host.root.draw_circle(c, r, KNOB)
	host.root.draw_arc(c, r, 0.0, TAU, 32, RING, 2.0, true)

static func glyph(host: CanvasLayer, action: String, c: Vector2, r: float, dim := false) -> void:
	if not host._tex.has(action):
		return
	var tex: Texture2D = host._tex[action]
	var s := r * 1.15
	var dest := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	host.root.draw_texture_rect(tex, dest, false, INK_DIM if dim else INK)