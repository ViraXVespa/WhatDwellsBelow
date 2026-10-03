extends Object

const InputPad := preload("res://scripts/input/pad.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

static var _axis_down: Dictionary = {}
static var _axis_key: Array = []
static var _axis_res := false

static func _axis_edge(m: InputEventJoypadMotion) -> bool:
	var key: Array = [Engine.get_process_frames(), m.device, m.axis, m.axis_value]
	if key == _axis_key:
		return _axis_res
	var id: int = m.device * 64 + m.axis * 2 + (1 if m.axis_value > 0.0 else 0)
	var down: bool = absf(m.axis_value) >= 0.5
	_axis_res = down and not bool(_axis_down.get(id, false))
	_axis_down[id] = down
	_axis_key = key
	return _axis_res

static func pressed(event: InputEvent) -> bool:
	InputPad.note_event(event)
	if Prompts.dirty():
		PromptView.pulse()
	if event is InputEventMouse or event is InputEventMouseButton:
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return _axis_edge(event as InputEventJoypadMotion)
	if event.is_pressed():
		return true
	return false

static func is_back(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("dash") or event.is_action_pressed("pause"):
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			return true
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false

static func is_tab_prev(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	if event.is_action_pressed("tab_left"):
		return true
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER
	return false

static func is_tab_next(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	if event.is_action_pressed("tab_right"):
		return true
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	return false

static func tab_delta(event: InputEvent) -> int:
	if is_tab_prev(event):
		return -1
	if is_tab_next(event):
		return 1
	return 0

static func is_page_prev(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_Q or k.keycode == KEY_Q:
			return true
	return event.is_action_pressed("special")

static func is_page_next(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_E or k.keycode == KEY_E:
			return true
	return event.is_action_pressed("attack")

static func page_delta(event: InputEvent) -> int:
	if is_page_prev(event):
		return -1
	if is_page_next(event):
		return 1
	return 0
