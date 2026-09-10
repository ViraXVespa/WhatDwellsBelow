extends Object

## Debug menu stick + page input. Host is scripts/combat/debug_menu.gd.

const Pad := preload("res://scripts/input/pad.gd")
const DebugMenuVal := preload("res://scripts/combat/debug_menu_val.gd")


static func tick(host, delta: float) -> void:
	if not host.open or host._busy_anim():
		return
	host.stick_cool = maxf(0.0, host.stick_cool - delta)
	if host.stick_cool > 0.0:
		return
	var s: Vector2 = Pad.stick(JOY_AXIS_LEFT_X as JoyAxis, JOY_AXIS_LEFT_Y as JoyAxis)
	if s.y <= -0.55:
		host._nudge_focus(-1)
		host.stick_cool = 0.18
		return
	if s.y >= 0.55:
		host._nudge_focus(1)
		host.stick_cool = 0.18
		return
	if str(host.page) == "values":
		if absf(s.x) >= 0.55:
			DebugMenuVal.val_nudge_col(host, 1 if s.x > 0.0 else -1)
			host.stick_cool = 0.18
		return
	var focus_ctrl: Control = host.get_viewport().gui_get_focus_owner() if host.get_viewport() else null
	if focus_ctrl == null or not host.is_ancestor_of(focus_ctrl):
		var items: Array[Control] = host._focusables()
		if not items.is_empty():
			items[0].grab_focus()


static func shift_page(host, delta_i: int) -> void:
	if host.val_edit:
		DebugMenuVal.val_cancel(host)
	var pages: PackedStringArray = host.PAGES
	var i: int = pages.find(str(host.page))
	if i < 0:
		i = 0
	host.page = pages[(i + delta_i + pages.size()) % pages.size()]
	host._rebuild()


static func accept_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return true
	return false


static func handle_input(host, event: InputEvent) -> void:
	if not host.open or host._busy_anim():
		return
	if event.is_action_pressed("tab_right"):
		shift_page(host, 1)
		host.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("tab_left"):
		shift_page(host, -1)
		host.get_viewport().set_input_as_handled()
		return
	if str(host.page) == "values":
		if event.is_action_pressed("ui_down"):
			DebugMenuVal.val_nudge(host, 1)
			host.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			DebugMenuVal.val_nudge(host, -1)
			host.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left"):
			DebugMenuVal.val_nudge_col(host, -1)
			host.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			DebugMenuVal.val_nudge_col(host, 1)
			host.get_viewport().set_input_as_handled()
			return
		if accept_pressed(event):
			DebugMenuVal.val_accept(host)
			host.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
			if DebugMenuVal.val_cancel(host):
				host.get_viewport().set_input_as_handled()
				return
	elif event.is_action_pressed("ui_down"):
		host._nudge_focus(1)
		host.get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_up"):
		host._nudge_focus(-1)
		host.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if str(host.page) != "values":
			host.page = "values"
			host._rebuild()
		else:
			host.hide_menu()
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
		host.get_viewport().set_input_as_handled()
