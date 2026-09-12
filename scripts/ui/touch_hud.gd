extends CanvasLayer

const Draw := preload("res://scripts/ui/touch_hud_draw.gd")
const PadInput := preload("res://scripts/ui/touch_hud_input.gd")

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
var _park: Dictionary = {}


func _ready() -> void:
	Draw.ready(self)


func _process(_delta: float) -> void:
	Draw.tick(self, _delta)


func _input(event: InputEvent) -> void:
	PadInput.handle_input(self, event)


func _layout() -> void:
	Draw.layout(self)


func _draw_pad() -> void:
	Draw.draw_pad(self)


func _well(c: Vector2, r: float, on := false, dim := false) -> void:
	Draw.well(self, c, r, on, dim)


func _knob(c: Vector2, r: float) -> void:
	Draw.knob(self, c, r)


func _glyph(action: String, c: Vector2, r: float, dim := false) -> void:
	Draw.glyph(self, action, c, r, dim)


func _down(idx: int, pos: Vector2) -> void:
	PadInput.down(self, idx, pos)


func _drag(idx: int, pos: Vector2) -> void:
	PadInput.drag(self, idx, pos)


func _up(idx: int) -> void:
	PadInput.up(self, idx)


func _claim_move(idx: int, origin: Vector2, pos: Vector2) -> void:
	PadInput.claim_move(self, idx, origin, pos)


func _begin_pinch() -> void:
	PadInput.begin_pinch(self)


func _tick_pinch(apply := true) -> void:
	PadInput.tick_pinch(self, apply)


func _can_pan() -> bool:
	return PadInput.can_pan(self)


func _in_move_zone(pos: Vector2) -> bool:
	return PadInput.in_move_zone(self, pos)


func _dungeon() -> Node:
	return PadInput.dungeon()


func _release_all() -> void:
	PadInput.release_all(self)


func _now() -> float:
	return PadInput.now()
