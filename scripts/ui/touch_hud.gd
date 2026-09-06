extends CanvasLayer

const Touch := preload("res://scripts/input/touch_pad.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const MapAct := preload("res://scripts/world/dungeon_map_act.gd")

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

const INK := Color(0.92, 0.84, 0.62, 0.95)
const INK_DIM := Color(0.92, 0.84, 0.62, 0.32)
const WELL := Color(0.22, 0.16, 0.12, 0.58)
const WELL_DIM := Color(0.16, 0.12, 0.10, 0.38)
const RING := Color(0.5, 0.38, 0.2, 0.92)
const RING_DIM := Color(0.4, 0.3, 0.16, 0.4)
const KNOB := Color(0.9, 0.7, 0.3, 0.95)
const PRESS := Color(0.16, 0.12, 0.08, 0.82)
const LATCH := Color(0.95, 0.78, 0.35, 0.95)

var root: Control
var _tex: Dictionary = {}
var _move_i := -1
var _btn_i: Dictionary = {}
var _move_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _move_live := false
var _move_r := 96.0
var _btns: Array = []
var _pinch_a := -1
var _pinch_b := -1
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _pan_i := -1
var _pan_at := Vector2.ZERO
var _free: Dictionary = {}


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_pad)
	add_child(root)
	for action in GLYPH.keys():
		var p := str(GLYPH[action])
		if ResourceLoader.exists(p):
			_tex[action] = load(p)


func _process(_delta: float) -> void:
	var show := Touch.wants_show()
	visible = show
	root.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	if not show:
		_release_all()
		return
	_layout()
	root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_down(t.index, t.position)
		else:
			_up(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var sc: float = clampf(minf(vp.x, vp.y) / 1080.0, 0.7, 1.35)
	_move_r = 98.0 * sc
	var pad := 26.0 * sc
	var gap := 22.0 * sc
	var br := 36.0 * sc
	var ar := 46.0 * sc
	var mini_h := 250.0 * App.hud_scale
	var top := 16.0 + mini_h + pad + br
	var bot := vp.y - pad - br
	if bot < top + 8.0:
		top = maxf(16.0 + mini_h + 8.0, vp.y * 0.28)
		bot = vp.y - pad - br
	var step := (bot - top) / 3.0
	var rx := vp.x - pad - ar
	var lx := rx - ar - br - gap
	_btns = [
		{"action": "food", "pos": Vector2(lx, bot), "r": br},
		{"action": "potion", "pos": Vector2(rx, bot), "r": br},
		{"action": "interact", "pos": Vector2(lx, bot - step), "r": br},
		{"action": "attack", "pos": Vector2(rx, bot - step), "r": ar},
		{"action": "dash", "pos": Vector2(lx, bot - step * 2.0), "r": br},
		{"action": "special", "pos": Vector2(rx, bot - step * 2.0), "r": br},
		{"action": "map_view", "pos": Vector2(lx, top), "r": br},
		{"action": "pause", "pos": Vector2(rx, top), "r": br},
	]


func _draw_pad() -> void:
	if _move_live:
		_well(_move_origin, _move_r)
		_knob(_move_knob, _move_r * 0.38)
	for row in _btns:
		var action := str(row["action"])
		var pos: Vector2 = row["pos"]
		var r: float = float(row["r"])
		var dim := action == "map_view" and Touch.in_camp()
		var on := Touch.held(action) and not dim
		if action == "attack" and Touch.attack_latch:
			on = true
		_well(pos, r, on, dim)
		_glyph(action, pos, r, dim)


func _well(c: Vector2, r: float, on := false, dim := false) -> void:
	var fill := WELL_DIM if dim else (PRESS if on else WELL)
	var ring := RING_DIM if dim else (LATCH if on else RING)
	root.draw_circle(c, r, fill)
	root.draw_arc(c, r, 0.0, TAU, 48, ring, 2.4, true)


func _knob(c: Vector2, r: float) -> void:
	root.draw_circle(c, r, KNOB)
	root.draw_arc(c, r, 0.0, TAU, 32, RING, 2.0, true)


func _glyph(action: String, c: Vector2, r: float, dim := false) -> void:
	if not _tex.has(action):
		return
	var tex: Texture2D = _tex[action]
	var s := r * 1.15
	var dest := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	root.draw_texture_rect(tex, dest, false, INK_DIM if dim else INK)


func _down(idx: int, pos: Vector2) -> void:
	for row in _btns:
		if pos.distance_to(row["pos"]) <= float(row["r"]) + 8.0:
			var action := str(row["action"])
			if action == "map_view" and Touch.in_camp():
				return
			_btn_i[idx] = action
			if action == "attack":
				Touch.attack_press(_now())
			else:
				Touch.set_held(action, true)
			return
	if _move_live:
		return
	_free[idx] = pos
	if _free.size() >= 2 and _pinch_a < 0:
		_begin_pinch()
		return
	if _can_pan() and _pan_i < 0:
		_free.erase(idx)
		_pan_i = idx
		_pan_at = pos
		return
	if _in_move_zone(pos) and _move_i < 0 and _pinch_a < 0:
		_free.erase(idx)
		_move_i = idx
		_move_origin = pos
		_move_knob = pos
		_move_live = true
		Touch.move_live = true
		Touch.set_move(Vector2.ZERO)


func _drag(idx: int, pos: Vector2) -> void:
	if idx == _move_i:
		var d := pos - _move_origin
		if d.length() > _move_r:
			d = d.normalized() * _move_r
		_move_knob = _move_origin + d
		Touch.set_move(d / _move_r)
		return
	if idx == _pan_i:
		MapAct.pan_by(_dungeon(), pos - _pan_at)
		_pan_at = pos
		return
	if _free.has(idx):
		_free[idx] = pos
	if _pinch_a >= 0 and (idx == _pinch_a or idx == _pinch_b):
		_tick_pinch()


func _up(idx: int) -> void:
	_free.erase(idx)
	if _btn_i.has(idx):
		var action := str(_btn_i[idx])
		_btn_i.erase(idx)
		if action == "attack":
			Touch.attack_release(_now())
		else:
			Touch.set_held(action, false)
		return
	if idx == _move_i:
		_move_i = -1
		_move_live = false
		Touch.move_live = false
		Touch.set_move(Vector2.ZERO)
		return
	if idx == _pan_i:
		_pan_i = -1
		return
	if idx == _pinch_a or idx == _pinch_b:
		_pinch_a = -1
		_pinch_b = -1
		_pinch_dist = 0.0


func _begin_pinch() -> void:
	var keys := _free.keys()
	if keys.size() < 2:
		return
	_pinch_a = int(keys[0])
	_pinch_b = int(keys[1])
	_tick_pinch(false)


func _tick_pinch(apply := true) -> void:
	if not _free.has(_pinch_a) or not _free.has(_pinch_b):
		return
	var a: Vector2 = _free[_pinch_a]
	var b: Vector2 = _free[_pinch_b]
	var dist := a.distance_to(b)
	var mid := (a + b) * 0.5
	if apply and _pinch_dist > 8.0 and dist > 8.0:
		Look.pinch(dist / _pinch_dist, mid)
	_pinch_dist = dist
	_pinch_mid = mid


func _can_pan() -> bool:
	if _move_live or _pinch_a >= 0:
		return false
	var host := _dungeon()
	return MapAct.is_open(host) and float(host.get_meta("map_zoom", 1.0)) > 1.001


func _in_move_zone(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	return pos.x <= vp.x * 0.48 and pos.y >= vp.y * 0.22


func _dungeon() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var tree := loop as SceneTree
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene == null:
		return null
	if str(scene.scene_file_path).ends_with("dungeon.tscn"):
		return scene
	return null


func _release_all() -> void:
	_move_i = -1
	_btn_i.clear()
	_move_live = false
	_pinch_a = -1
	_pinch_b = -1
	_pinch_dist = 0.0
	_pan_i = -1
	_free.clear()
	Touch.move_live = false
	Touch.set_move(Vector2.ZERO)
	Touch.set_aim(Vector2.ZERO)
	for action in Touch.ACTIONS:
		if action != "attack":
			Touch.set_held(action, false)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001
