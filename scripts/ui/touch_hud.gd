extends CanvasLayer

const Touch := preload("res://scripts/input/touch_pad.gd")

const GLYPH := {
	"attack": "res://assets/ui/prompts/pad/rt.png",
	"special": "res://assets/ui/prompts/pad/lt.png",
	"dash": "res://assets/ui/prompts/pad/b.png",
	"interact": "res://assets/ui/prompts/pad/a.png",
	"pause": "res://assets/ui/prompts/pad/menu.png",
	"map_view": "res://assets/ui/prompts/pad/view.png",
	"potion": "res://assets/ui/prompts/pad/dpad_up.png",
	"food": "res://assets/ui/prompts/pad/dpad_left.png",
	"target_lock": "res://assets/ui/prompts/pad/rs.png",
}

const INK := Color(0.92, 0.84, 0.62, 0.95)
const WELL := Color(0.22, 0.16, 0.12, 0.58)
const RING := Color(0.5, 0.38, 0.2, 0.92)
const KNOB := Color(0.9, 0.7, 0.3, 0.95)
const PRESS := Color(0.16, 0.12, 0.08, 0.82)
const LATCH := Color(0.95, 0.78, 0.35, 0.95)

var root: Control
var _tex: Dictionary = {}
var _move_i := -1
var _aim_i := -1
var _btn_i: Dictionary = {}
var _move_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _move_live := false
var _aim_center := Vector2.ZERO
var _aim_knob := Vector2.ZERO
var _aim_r := 96.0
var _move_r := 96.0
var _btns: Array = []


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
	_aim_r = 98.0 * sc
	var br := 38.0 * sc
	var ar := 46.0 * sc
	_aim_center = Vector2(vp.x - 168.0 * sc, vp.y - 168.0 * sc)
	if _aim_i < 0:
		_aim_knob = _aim_center
	var ax := _aim_center.x
	var ay := _aim_center.y
	_btns = [
		{"action": "attack", "pos": Vector2(ax + 118.0 * sc, ay - 36.0 * sc), "r": ar},
		{"action": "special", "pos": Vector2(ax + 42.0 * sc, ay - 128.0 * sc), "r": br},
		{"action": "dash", "pos": Vector2(ax - 36.0 * sc, ay - 128.0 * sc), "r": br},
		{"action": "interact", "pos": Vector2(ax - 118.0 * sc, ay - 36.0 * sc), "r": br},
		{"action": "target_lock", "pos": Vector2(ax + 118.0 * sc, ay + 72.0 * sc), "r": br},
		{"action": "pause", "pos": Vector2(48.0 * sc, 52.0 * sc), "r": br},
		{"action": "map_view", "pos": Vector2(48.0 * sc + 84.0 * sc, 52.0 * sc), "r": br},
		{"action": "potion", "pos": Vector2(vp.x * 0.5 - 46.0 * sc, vp.y - 52.0 * sc), "r": br},
		{"action": "food", "pos": Vector2(vp.x * 0.5 + 46.0 * sc, vp.y - 52.0 * sc), "r": br},
	]


func _draw_pad() -> void:
	if _move_live:
		_well(_move_origin, _move_r)
		_knob(_move_knob, _move_r * 0.38, false)
	_well(_aim_center, _aim_r)
	_knob(_aim_knob, _aim_r * 0.38, false)
	for row in _btns:
		var action := str(row["action"])
		var pos: Vector2 = row["pos"]
		var r: float = float(row["r"])
		var on := Touch.held(action)
		if action == "attack" and Touch.attack_latch:
			on = true
		_well(pos, r, on)
		_glyph(action, pos, r)


func _well(c: Vector2, r: float, on := false) -> void:
	root.draw_circle(c, r, PRESS if on else WELL)
	root.draw_arc(c, r, 0.0, TAU, 48, LATCH if on else RING, 2.4, true)


func _knob(c: Vector2, r: float, on: bool) -> void:
	root.draw_circle(c, r, LATCH if on else KNOB)
	root.draw_arc(c, r, 0.0, TAU, 32, RING, 2.0, true)


func _glyph(action: String, c: Vector2, r: float) -> void:
	if not _tex.has(action):
		return
	var tex: Texture2D = _tex[action]
	var s := r * 1.15
	var dest := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	root.draw_texture_rect(tex, dest, false, INK)


func _down(idx: int, pos: Vector2) -> void:
	for row in _btns:
		if pos.distance_to(row["pos"]) <= float(row["r"]) + 8.0:
			var action := str(row["action"])
			_btn_i[idx] = action
			if action == "attack":
				Touch.attack_press(_now())
			else:
				Touch.set_held(action, true)
			return
	if _in_aim(pos) and _aim_i < 0:
		_aim_i = idx
		_drag_aim(pos)
		return
	if _in_move_zone(pos) and _move_i < 0:
		_move_i = idx
		_move_origin = pos
		_move_knob = pos
		_move_live = true
		Touch.set_move(Vector2.ZERO)


func _drag(idx: int, pos: Vector2) -> void:
	if idx == _move_i:
		var d := pos - _move_origin
		if d.length() > _move_r:
			d = d.normalized() * _move_r
		_move_knob = _move_origin + d
		Touch.set_move(d / _move_r)
	elif idx == _aim_i:
		_drag_aim(pos)


func _up(idx: int) -> void:
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
		Touch.set_move(Vector2.ZERO)
		return
	if idx == _aim_i:
		_aim_i = -1
		_aim_knob = _aim_center
		Touch.set_aim(Vector2.ZERO)


func _drag_aim(pos: Vector2) -> void:
	var d := pos - _aim_center
	if d.length() > _aim_r:
		d = d.normalized() * _aim_r
	_aim_knob = _aim_center + d
	Touch.set_aim(d / _aim_r)


func _in_aim(pos: Vector2) -> bool:
	return pos.distance_to(_aim_center) <= _aim_r * 1.2


func _in_move_zone(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	return pos.x <= vp.x * 0.48 and pos.y >= vp.y * 0.22


func _release_all() -> void:
	_move_i = -1
	_aim_i = -1
	_btn_i.clear()
	_move_live = false
	_aim_knob = _aim_center
	Touch.set_move(Vector2.ZERO)
	Touch.set_aim(Vector2.ZERO)
	for action in Touch.ACTIONS:
		if action != "attack":
			Touch.set_held(action, false)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001
