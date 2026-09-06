extends RefCounted

## World camera / HUD look mode and map stick/wheel/pinch apply.
## Pad.aim() must treat eats_aim() as "right stick is not aim."

const T := preload("res://scripts/data/tunables.gd")
const MapAct := preload("res://scripts/world/dungeon_map_act.gd")

static var mode := false
static var wheel_step := 0.08
static var pinch_gain := 1.15
static var stick_zoom := 0.9
static var stick_hud := 0.35
static var stick_pan := 520.0

static var _was_toggle := false
static var _was_blocked := false


static func reset_defaults() -> void:
	wheel_step = 0.08
	pinch_gain = 1.15
	stick_zoom = 0.9
	stick_hud = 0.35
	stick_pan = 520.0


static func clear() -> void:
	mode = false
	_was_toggle = false


static func blocked() -> bool:
	if App.ui_open:
		return true
	if App.debug != null and bool(App.debug.get("visible")):
		return true
	if App.recap != null and bool(App.recap.get("visible")):
		return true
	if App.anim_browser != null and bool(App.anim_browser.get("visible")):
		return true
	return false


static func map_open() -> bool:
	return MapAct.is_open(_dungeon())


static func eats_aim() -> bool:
	if blocked():
		return false
	return mode or map_open()


static func tick(delta: float) -> void:
	var lock := blocked()
	if lock:
		if not _was_blocked:
			clear()
		_was_blocked = true
		_was_toggle = _toggle_held()
		return
	_was_blocked = false
	var down := _toggle_held()
	if down and not _was_toggle:
		mode = not mode
	_was_toggle = down
	_stick(delta)


static func note_event(event: InputEvent) -> void:
	if blocked():
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var btn := event as InputEventMouseButton
	var step := wheel_step
	if btn.button_index == MOUSE_BUTTON_WHEEL_UP:
		_wheel(step, btn.position)
	elif btn.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_wheel(-step, btn.position)


static func pinch(factor: float, focus: Vector2) -> void:
	if blocked() or factor <= 0.0:
		return
	var gain := pow(factor, pinch_gain)
	if map_open():
		MapAct.zoom_at(_dungeon(), gain, focus)
		return
	var z := App.cam_zoom
	if gain > 1.0:
		z += (gain - 1.0) * 1.6
	else:
		z -= (1.0 - gain) * 1.6
	App.set_zoom(z)


static func _wheel(delta_z: float, focus: Vector2) -> void:
	if map_open():
		var gain := 1.0 + delta_z
		if gain < 0.2:
			gain = 0.2
		MapAct.zoom_at(_dungeon(), gain, focus)
		return
	App.set_zoom(App.cam_zoom + delta_z)


static func _stick(delta: float) -> void:
	var v := _rs()
	if v.length() < 0.24:
		return
	var host := _dungeon()
	if MapAct.is_open(host):
		if mode:
			MapAct.zoom_player(host, -v.y * stick_zoom * delta)
		else:
			MapAct.pan_by(host, v * stick_pan * delta)
		return
	if not mode:
		return
	App.set_hud_scale(App.hud_scale + v.x * stick_hud * delta)
	App.set_zoom(App.cam_zoom + (-v.y) * stick_zoom * delta)


static func _toggle_held() -> bool:
	if Input.is_action_pressed("look_mode"):
		return true
	var pid := _pad_id()
	if pid < 0:
		return false
	return Input.is_joy_button_pressed(pid, JOY_BUTTON_DPAD_DOWN)


static func _rs() -> Vector2:
	var pid := _pad_id()
	if pid < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(pid, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pid, JOY_AXIS_RIGHT_Y))
	return v if v.length() >= 0.24 else Vector2.ZERO


static func _pad_id() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


static func _dungeon() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var tree := loop as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var path := str(tree.current_scene.scene_file_path)
	if path.ends_with("dungeon.tscn"):
		return tree.current_scene
	return null
