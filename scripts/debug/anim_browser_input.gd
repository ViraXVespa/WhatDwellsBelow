extends Object

## Animation Browser input routing.

const Review := preload("res://scripts/debug/anim_browser_review.gd")
const Nav := preload("res://scripts/debug/anim_browser_nav.gd")
const Play := preload("res://scripts/debug/anim_browser_play.gd")


static func pad_list_event(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func handle_input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			host.get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			Nav.scroll_anim(host, -1)
			host.get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Nav.scroll_anim(host, 1)
			host.get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var axis: int = (event as InputEventJoypadMotion).axis
		if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
			host.get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back"):
		host.close_browser()
		host.get_viewport().set_input_as_handled()
		return
	if Nav.ui_nav(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if Review.handle_tip(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left") or event.is_action_pressed("anim_model_prev"):
		host._shift_model(-1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tab_right") or event.is_action_pressed("anim_model_next"):
		host._shift_model(1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_lock") or event.is_action_pressed("anim_idle"):
		Nav.set_facing(host, "down")
		host.get_viewport().set_input_as_handled()
	elif pad_list_event(event) and (event.is_action_pressed("special") or event.is_action_pressed("anim_list_up")):
		Nav.scroll_anim(host, -1)
		host.get_viewport().set_input_as_handled()
	elif pad_list_event(event) and (event.is_action_pressed("attack") or event.is_action_pressed("anim_list_down")):
		Nav.scroll_anim(host, 1)
		host.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("anim_play") or event.is_action_pressed("gear_drop"):
		Play.toggle_play(host)
		host.get_viewport().set_input_as_handled()
