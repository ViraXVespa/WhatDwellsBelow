extends CanvasLayer

const Draw := preload("res://scripts/ui/touch_hud/hud_draw.gd")
const PadInput := preload("res://scripts/ui/touch_hud/hud_input.gd")

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

func _knob(c: Vector2, r: float) -> void:
	Draw.knob(self, c, r)

func _drag(idx: int, pos: Vector2) -> void:
	PadInput.drag(self, idx, pos)

func _dungeon() -> Node:
	return PadInput.dungeon()

func _now() -> float:
	return PadInput.now()
