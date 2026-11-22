extends CanvasLayer

const Draw := preload("res://scripts/ui/touch_hud/hud_draw.gd")
const PadInput := preload("res://scripts/ui/touch_hud/hud_input.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")

var root: Control
var _tex: Dictionary = {}
var _move_i := -1
var _btn_i: Dictionary = {}
var _move_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _move_live := false
var _move_r := 96.0
var _move_home := Vector2.ZERO
var _bow_i := -1
var _bow_origin := Vector2.ZERO
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
	get_viewport().size_changed.connect(request_refresh)
	get_tree().scene_changed.connect(request_refresh)
	Input.joy_connection_changed.connect(_on_joy_connection)
	App.input_changed.connect(request_refresh)
	request_refresh()

var _refresh_queued := false

func request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh")

func _refresh() -> void:
	_refresh_queued = false
	Draw.tick(self, 0.0)

## Live state the overlay draws (lock glow, item counts, the Bow mode stick, camp dimming, menus hiding it) changes
## without a signal, so a touch device redraws each frame; elsewhere this stays idle.
func _process(_delta: float) -> void:
	if visible or Touch.wants_device():
		request_refresh()

func _on_joy_connection(_device: int, _connected: bool) -> void:
	request_refresh()

func _input(event: InputEvent) -> void:
	PadInput.handle_input(self, event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		request_refresh()

func _layout() -> void:
	Draw.layout(self)

func _draw_pad() -> void:
	Draw.draw_pad(self)

func _dungeon() -> Node:
	return PadInput.dungeon()
