extends Object

## Default InputMap fill. Host module is scripts/input/binds.gd.


static func register() -> void:
	for extra in ["weapon_1", "weapon_2", "weapon_3"]:
		if InputMap.has_action(extra):
			InputMap.erase_action(extra)
	for a in load("res://scripts/input/binds.gd").BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
		else:
			InputMap.add_action(a, 0.25)
	act("move_left", [KEY_A, KEY_LEFT], -1, JOY_AXIS_LEFT_X, -1.0)
	act("move_right", [KEY_D, KEY_RIGHT], -1, JOY_AXIS_LEFT_X, 1.0)
	act("move_up", [KEY_W, KEY_UP], -1, JOY_AXIS_LEFT_Y, -1.0)
	act("move_down", [KEY_S, KEY_DOWN], -1, JOY_AXIS_LEFT_Y, 1.0)
	act("aim_left", [], -1, JOY_AXIS_RIGHT_X, -1.0)
	act("aim_right", [], -1, JOY_AXIS_RIGHT_X, 1.0)
	act("aim_up", [], -1, JOY_AXIS_RIGHT_Y, -1.0)
	act("aim_down", [], -1, JOY_AXIS_RIGHT_Y, 1.0)
	act("attack", [], -1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	mouse("attack", MOUSE_BUTTON_LEFT)
	act("special", [], -1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	mouse("special", MOUSE_BUTTON_RIGHT)
	act("dash", [KEY_SPACE], JOY_BUTTON_B)
	act("target_lock", [KEY_Q], JOY_BUTTON_RIGHT_STICK)
	act("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER], JOY_BUTTON_A)
	act("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	act("tab_left", [KEY_BRACKETLEFT], JOY_BUTTON_LEFT_SHOULDER)
	act("tab_right", [KEY_BRACKETRIGHT], JOY_BUTTON_RIGHT_SHOULDER)
	act("map_view", [KEY_M], JOY_BUTTON_BACK)
	act("potion", [KEY_F], JOY_BUTTON_DPAD_UP)
	act("food", [KEY_C], JOY_BUTTON_DPAD_LEFT)
	act("look_mode", [], JOY_BUTTON_DPAD_DOWN)
	act("inventory", [KEY_I], JOY_BUTTON_DPAD_RIGHT)
	act("gear_tip", [KEY_Y], JOY_BUTTON_Y)
	act("gear_drop", [KEY_X], JOY_BUTTON_X)
	act("crystal_zoom", [KEY_TAB], JOY_BUTTON_Y)
	act("anim_model_prev", [KEY_COMMA], JOY_BUTTON_LEFT_SHOULDER)
	act("anim_model_next", [KEY_PERIOD], JOY_BUTTON_RIGHT_SHOULDER)
	act("anim_idle", [KEY_I], JOY_BUTTON_RIGHT_STICK)
	act("anim_play", [KEY_P])
	act("anim_list_up", [KEY_PAGEUP], -1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	act("anim_list_down", [KEY_PAGEDOWN], -1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	act("anim_back", [KEY_BACKSPACE, KEY_ESCAPE], JOY_BUTTON_B)
	ensure("ui_accept")
	ensure("ui_cancel")
	ensure("ui_left")
	ensure("ui_right")
	ensure("ui_up")
	ensure("ui_down")
	joy("ui_accept", JOY_BUTTON_A)
	joy("ui_cancel", JOY_BUTTON_B)
	key("ui_accept", KEY_ENTER)
	key("ui_accept", KEY_KP_ENTER)
	key("ui_cancel", KEY_ESCAPE)
	joy("ui_left", JOY_BUTTON_DPAD_LEFT)
	joy("ui_right", JOY_BUTTON_DPAD_RIGHT)
	joy("ui_up", JOY_BUTTON_DPAD_UP)
	joy("ui_down", JOY_BUTTON_DPAD_DOWN)
	key("ui_left", KEY_LEFT)
	key("ui_left", KEY_A)
	key("ui_right", KEY_RIGHT)
	key("ui_right", KEY_D)
	key("ui_up", KEY_UP)
	key("ui_up", KEY_W)
	key("ui_down", KEY_DOWN)
	key("ui_down", KEY_S)
	if OS.has_feature("web"):
		var rt := InputEventJoypadButton.new()
		rt.button_index = 7 as JoyButton
		InputMap.action_add_event("attack", rt)
		var lt := InputEventJoypadButton.new()
		lt.button_index = 6 as JoyButton
		InputMap.action_add_event("special", lt)
	apply_pc_defaults()


static func apply_pc_defaults() -> void:
	ensure_key("move_left", KEY_A)
	ensure_key("move_left", KEY_LEFT)
	ensure_key("move_right", KEY_D)
	ensure_key("move_right", KEY_RIGHT)
	ensure_key("move_up", KEY_W)
	ensure_key("move_up", KEY_UP)
	ensure_key("move_down", KEY_S)
	ensure_key("move_down", KEY_DOWN)
	ensure_key("interact", KEY_E)
	ensure_key("interact", KEY_ENTER)
	ensure_key("interact", KEY_KP_ENTER)
	ensure_key("inventory", KEY_I)
	strip_key("special", KEY_R)
	ensure_mouse("special", MOUSE_BUTTON_RIGHT)
	ensure_key("pause", KEY_ESCAPE)
	ensure_key("gear_tip", KEY_Y)
	ensure_key("gear_drop", KEY_X)
	ensure_key("crystal_zoom", KEY_TAB)
	ensure_key("anim_back", KEY_ESCAPE)
	ensure_key("anim_back", KEY_BACKSPACE)
	ensure_key("ui_accept", KEY_ENTER)
	ensure_key("ui_accept", KEY_KP_ENTER)
	ensure_key("ui_cancel", KEY_ESCAPE)
	ensure_key("ui_left", KEY_LEFT)
	ensure_key("ui_left", KEY_A)
	ensure_key("ui_right", KEY_RIGHT)
	ensure_key("ui_right", KEY_D)
	ensure_key("ui_up", KEY_UP)
	ensure_key("ui_up", KEY_W)
	ensure_key("ui_down", KEY_DOWN)
	ensure_key("ui_down", KEY_S)


static func ensure_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: InputEventKey = e as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				return
	key(action, keycode)


static func ensure_mouse(action: String, btn: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == btn:
			return
	mouse(action, btn)


static func ensure_joy(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	joy(action, button)


static func ensure_axis(action: String, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			var m: InputEventJoypadMotion = e as InputEventJoypadMotion
			if m.axis == axis and signf(m.axis_value) == signf(axis_value):
				return
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis as JoyAxis
	jm.axis_value = axis_value
	InputMap.action_add_event(action, jm)


static func strip_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: InputEventKey = e as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				InputMap.action_erase_event(action, e)


static func act(action: String, keys: Array, button: int = -1, axis: int = -1, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(action, e)
	if button >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button as JoyButton
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis as JoyAxis
		jm.axis_value = axis_value
		InputMap.action_add_event(action, jm)


static func mouse(action: String, btn: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn as MouseButton
	InputMap.action_add_event(action, e)


static func ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)


static func joy(action: String, button: int) -> void:
	var jb := InputEventJoypadButton.new()
	jb.button_index = button as JoyButton
	InputMap.action_add_event(action, jb)


static func key(action: String, keycode: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode as Key
	InputMap.action_add_event(action, e)
