extends Object

## Shared menu bindings.
## LB / RB  — cycle tabs when the open menu has tabs
## A / Enter — confirm focused control (Godot GUI) or a pending prompt
## B / Esc  — back one layer, or close at root
## Q / LT   — previous stats page on a gear board
## E / RT   — next stats page on a gear board
## Debug Animation Browser keeps its own LB/RB and LT/RT meaning.


static func pressed(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventMouseButton:
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event.is_pressed():
		return true
	return false


static func is_confirm(event: InputEvent) -> bool:
	if not pressed(event):
		return false
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")


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
