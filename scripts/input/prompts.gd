extends Object

const Pad := preload("res://scripts/input/pad.gd")

const DIR := "res://assets/ui/prompts/"
const DEBOUNCE := 0.12

static var _scheme := "kb"
static var _hold := 0.0
static var _shown := "kb"


static func tick(delta: float) -> void:
	var want := "pad" if Pad.mode else "kb"
	if want == _scheme:
		_hold = 0.0
		return
	_hold += delta
	if _hold >= DEBOUNCE:
		_scheme = want
		_hold = 0.0


static func scheme() -> String:
	return "pad" if Pad.mode else "kb"


static func dirty() -> bool:
	var now := scheme()
	if now == _shown:
		return false
	_shown = now
	return true


static func page_prev() -> String:
	return "special" if scheme() == "pad" else "target_lock"


static func page_next() -> String:
	return "attack" if scheme() == "pad" else "interact"


static func event_for(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var pad := scheme() == "pad"
	var events: Array = InputMap.action_get_events(action)
	var best: InputEvent = null
	for e in events:
		if pad:
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				return e
		else:
			if e is InputEventMouseButton:
				if action != "interact" and action != "ui_accept":
					return e
				if best == null:
					best = e
				continue
			if e is InputEventKey:
				var code := int(e.keycode)
				var phys := int(e.physical_keycode)
				if action == "ui_accept":
					if code == KEY_ENTER or phys == KEY_ENTER or code == KEY_KP_ENTER or phys == KEY_KP_ENTER:
						return e
					if best == null:
						best = e
					continue
				if code == KEY_ENTER or phys == KEY_ENTER or code == KEY_KP_ENTER or phys == KEY_KP_ENTER:
					continue
				if action == "interact" or action == page_next():
					if code == KEY_E or phys == KEY_E:
						return e
				if action == "target_lock" or action == page_prev():
					if code == KEY_Q or phys == KEY_Q:
						return e
				if best == null:
					best = e
	return best


static func id_for_event(e: InputEvent) -> String:
	if e == null:
		return ""
	if e is InputEventJoypadButton:
		return _joy_btn(int(e.button_index))
	if e is InputEventJoypadMotion:
		return _joy_axis(int(e.axis), e.axis_value)
	if e is InputEventMouseButton:
		return _mouse(int(e.button_index))
	if e is InputEventKey:
		return _key(e)
	return ""


static func path_for(action: String) -> String:
	var id := id_for_event(event_for(action))
	if id == "":
		return ""
	if id.begins_with("mouse/"):
		return DIR + id + ".png"
	if scheme() == "pad":
		return DIR + "pad/" + id + ".png"
	return DIR + "kb/" + id + ".png"


static func texture_for(action: String) -> Texture2D:
	var p := path_for(action)
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null


static func chip_for(action: String) -> String:
	var id := id_for_event(event_for(action))
	if id == "":
		return action
	if id.begins_with("mouse/"):
		return id.substr(6).to_upper()
	return id.to_upper()


static func verb_line(action: String, verb: String) -> String:
	var chip := chip_for(action)
	if verb == "":
		return chip
	return "%s %s" % [chip, verb]


static func _joy_btn(i: int) -> String:
	match i:
		JOY_BUTTON_A:
			return "a"
		JOY_BUTTON_B:
			return "b"
		JOY_BUTTON_X:
			return "x"
		JOY_BUTTON_Y:
			return "y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "lb"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "rb"
		JOY_BUTTON_BACK:
			return "view"
		JOY_BUTTON_START:
			return "menu"
		JOY_BUTTON_LEFT_STICK:
			return "ls"
		JOY_BUTTON_RIGHT_STICK:
			return "rs"
		JOY_BUTTON_DPAD_UP:
			return "dpad_up"
		JOY_BUTTON_DPAD_DOWN:
			return "dpad_down"
		JOY_BUTTON_DPAD_LEFT:
			return "dpad_left"
		JOY_BUTTON_DPAD_RIGHT:
			return "dpad_right"
	return "a"


static func _joy_axis(axis: int, value: float) -> String:
	if axis == JOY_AXIS_TRIGGER_LEFT:
		return "lt"
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		return "rt"
	return "ls" if value < 0.0 else "rs"


static func _mouse(i: int) -> String:
	if i == MOUSE_BUTTON_LEFT:
		return "mouse/lmb"
	if i == MOUSE_BUTTON_RIGHT:
		return "mouse/rmb"
	return "mouse/mmb"


static func _key(e: InputEventKey) -> String:
	var code := int(e.keycode)
	if code == 0:
		code = int(e.physical_keycode)
	match code:
		KEY_ESCAPE:
			return "esc"
		KEY_TAB:
			return "tab"
		KEY_SHIFT:
			return "shift"
		KEY_CTRL:
			return "ctrl"
		KEY_ALT:
			return "alt"
		KEY_BACKSPACE:
			return "backspace"
		KEY_DELETE:
			return "del"
		KEY_ENTER, KEY_KP_ENTER:
			return "enter"
		KEY_SPACE:
			return "space"
		KEY_PAGEUP:
			return "pageup"
		KEY_PAGEDOWN:
			return "pagedown"
		KEY_MINUS:
			return "minus"
		KEY_EQUAL:
			return "equal"
		KEY_COMMA:
			return "comma"
		KEY_PERIOD:
			return "period"
		KEY_BRACKETLEFT:
			return "lbracket"
		KEY_BRACKETRIGHT:
			return "rbracket"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
	var s := OS.get_keycode_string(code).to_lower()
	s = s.replace(" ", "")
	if s == "bracketleft":
		return "lbracket"
	if s == "bracketright":
		return "rbracket"
	if s == "escape":
		return "esc"
	return s
