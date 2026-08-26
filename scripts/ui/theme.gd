extends Object


static func lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func btn(t: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
	b.add_theme_stylebox_override("normal", sb(Color(0.22, 0.16, 0.12), Color(0.5, 0.38, 0.2)))
	b.add_theme_stylebox_override("hover", sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", sb(Color(0.16, 0.12, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", sb(Color(0.12, 0.1, 0.09), Color(0.28, 0.24, 0.2)))
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(cb)
	return b


static func bind_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "(unbound)"
	var joy := ""
	var key := ""
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			joy = _joy_btn((e as InputEventJoypadButton).button_index)
		elif e is InputEventJoypadMotion:
			joy = _joy_axis((e as InputEventJoypadMotion).axis, (e as InputEventJoypadMotion).axis_value)
		elif e is InputEventKey:
			var k := e as InputEventKey
			key = OS.get_keycode_string(k.physical_keycode) if k.physical_keycode != 0 else OS.get_keycode_string(k.keycode)
		elif e is InputEventMouseButton:
			var mb := (e as InputEventMouseButton).button_index
			if mb == MOUSE_BUTTON_LEFT:
				key = "LMB"
			elif mb == MOUSE_BUTTON_RIGHT:
				key = "RMB"
			else:
				key = "Mouse " + str(mb)
	if joy == "" and key == "":
		return "(unbound)"
	if joy != "" and key != "":
		return joy + "  /  " + key
	return joy if joy != "" else key


static func _joy_btn(i: int) -> String:
	match i:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "View"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
	return "Pad " + str(i)


static func _joy_axis(axis: int, val: float) -> String:
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		return "RT"
	if axis == JOY_AXIS_TRIGGER_LEFT:
		return "LT"
	if axis == JOY_AXIS_LEFT_X:
		return "Left Stick X"
	if axis == JOY_AXIS_LEFT_Y:
		return "Left Stick Y"
	if axis == JOY_AXIS_RIGHT_X:
		return "Right Stick X"
	if axis == JOY_AXIS_RIGHT_Y:
		return "Right Stick Y"
	return "Axis %d%s" % [axis, "+" if val >= 0.0 else "-"]


static func sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
