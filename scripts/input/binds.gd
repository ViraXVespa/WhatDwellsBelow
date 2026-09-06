extends RefCounted

const BIND_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"attack", "special", "dash", "target_lock", "interact", "pause",
	"tab_left", "tab_right",
	"map_view", "potion", "food", "look_mode",
	"gear_tip", "gear_drop", "crystal_zoom",
	"anim_model_prev", "anim_model_next", "anim_idle", "anim_play",
	"anim_list_up", "anim_list_down", "anim_back",
]


static func collect() -> Array:
	var out: Array = []
	for a in BIND_ACTIONS:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			var row := {"action": a}
			if e is InputEventKey:
				var k := e as InputEventKey
				row["type"] = "key"
				row["code"] = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			elif e is InputEventJoypadButton:
				row["type"] = "joy"
				row["code"] = (e as InputEventJoypadButton).button_index
			elif e is InputEventJoypadMotion:
				var m := e as InputEventJoypadMotion
				row["type"] = "axis"
				row["code"] = m.axis
				row["value"] = m.axis_value
			elif e is InputEventMouseButton:
				row["type"] = "mouse"
				row["code"] = (e as InputEventMouseButton).button_index
			else:
				continue
			out.append(row)
	return out


static func apply(rows: Array) -> void:
	if rows.is_empty():
		return
	var seen := {}
	for row in rows:
		if not (row is Dictionary):
			continue
		var a := str(row.get("action", ""))
		if a == "" or BIND_ACTIONS.find(a) < 0:
			continue
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
		if not seen.has(a):
			InputMap.action_erase_events(a)
			seen[a] = true
		var ev := bind_event(row)
		if ev:
			InputMap.action_add_event(a, ev)
	apply_pc_defaults()


static func bind_event(row: Dictionary) -> InputEvent:
	var t := str(row.get("type", ""))
	if t == "key":
		var e := InputEventKey.new()
		e.physical_keycode = int(row.get("code", 0))
		return e
	if t == "joy":
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(row.get("code", 0))
		return jb
	if t == "axis":
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(row.get("code", 0))
		jm.axis_value = float(row.get("value", 1.0))
		return jm
	if t == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(row.get("code", 1))
		return mb
	return null


static func reset() -> void:
	for a in BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
	register()


static func register() -> void:
	for extra in ["weapon_1", "weapon_2", "weapon_3"]:
		if InputMap.has_action(extra):
			InputMap.erase_action(extra)
	for a in BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
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
		rt.button_index = 7
		InputMap.action_add_event("attack", rt)
		var lt := InputEventJoypadButton.new()
		lt.button_index = 6
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


static func ensure_key(name: String, keycode: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for e in InputMap.action_get_events(name):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				return
	key(name, keycode)


static func ensure_mouse(name: String, btn: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for e in InputMap.action_get_events(name):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == btn:
			return
	mouse(name, btn)


static func strip_key(name: String, keycode: int) -> void:
	if not InputMap.has_action(name):
		return
	for e in InputMap.action_get_events(name):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				InputMap.action_erase_event(name, e)


static func act(name: String, keys: Array, button: int = -1, axis: int = -1, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	if button >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(name, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_value
		InputMap.action_add_event(name, jm)


static func mouse(name: String, btn: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	InputMap.action_add_event(name, e)


static func ensure(name: String) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.5)


static func joy(name: String, button: int) -> void:
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	InputMap.action_add_event(name, jb)


static func key(name: String, keycode: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(name, e)
