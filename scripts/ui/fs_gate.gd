extends Control

## Web pre-splash: platform copy + a gesture that can request fullscreen / PWA install.

const Disp := preload("res://scripts/display_mode.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

var _kind: String = "web"
var _action: Button
var _continue: Button
var _hint: Label
var _leaving := false


func _ready() -> void:
	_kind = Disp.web_kind()
	if _kind == "":
		_kind = "web"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fill(self)

	var bg := ColorRect.new()
	_fill(bg)
	bg.color = Color(0.06, 0.05, 0.045, 1)
	add_child(bg)

	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -420.0
	card.offset_right = 420.0
	card.offset_top = -320.0
	card.offset_bottom = 340.0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 16)
	add_child(card)

	card.add_child(_lab("What Dwells Below", 40, Color(0.92, 0.78, 0.48)))
	card.add_child(_lab(_headline(), 26, Color(0.95, 0.86, 0.4)))
	card.add_child(_lab(_body(), 18, Color(0.78, 0.72, 0.62)))

	_hint = _lab(_rotate_line(), 16, Color(0.7, 0.62, 0.48))
	card.add_child(_hint)

	_action = ThemeS.btn(_action_label(), _on_action)
	_size_btn(_action)
	card.add_child(_action)

	_continue = ThemeS.btn("Continue", _on_continue)
	_size_btn(_continue)
	card.add_child(_continue)

	_action.focus_neighbor_bottom = _continue.get_path()
	_action.focus_neighbor_top = _continue.get_path()
	_continue.focus_neighbor_top = _action.get_path()
	_continue.focus_neighbor_bottom = _action.get_path()
	_action.grab_focus()

	if App and App.has_method("wake_web_pad"):
		call_deferred("_wake")


func _wake() -> void:
	App.wake_web_pad()


func _process(_dt: float) -> void:
	if _hint == null:
		return
	_hint.text = _rotate_line()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_continue()
		get_viewport().set_input_as_handled()


func _on_action() -> void:
	if _leaving:
		return
	var ok: bool = Disp.try_fullscreen_gesture()
	if _kind == "ios":
		if _hint:
			_hint.text = "Safari cannot open Add to Home Screen for you. Use Share → Add to Home Screen, then Continue."
		return
	if ok:
		_leave()


func _on_continue() -> void:
	_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Disp.mark_gate_seen()
	get_tree().change_scene_to_file("res://scenes/splash.tscn")


func _headline() -> String:
	if _kind == "ios":
		return "Fullscreen on iPhone"
	if _kind == "android":
		return "Play fullscreen"
	return "Enter fullscreen"


func _body() -> String:
	if _kind == "ios":
		return "iPhone Safari cannot hide the browser chrome from a button. Add the game to your Home Screen for a chrome-less launch: tap Share (square with arrow) → Add to Home Screen → Add. Leave Open as Web App on. Then open the icon. You can Continue in this tab without that."
	if _kind == "android":
		return "Tap Fullscreen to hide the browser bars. If the tap also offers Install, accept it for a Home Screen icon that launches landscape and chrome-less. Pause → System can toggle fullscreen later. Rotate the phone sideways."
	return "Click Fullscreen to hide browser chrome. Chromium may also offer an Install prompt — that adds a standalone window. Pause → System toggles fullscreen later. Alt+Enter is desktop-only and does not apply in the browser."


func _action_label() -> String:
	if _kind == "ios":
		return "Try fullscreen"
	if _kind == "android":
		return "Fullscreen / Install"
	return "Fullscreen"


func _rotate_line() -> String:
	if Disp.viewport_portrait():
		return "Rotate the device to landscape."
	return "A confirms the focused button. B / Esc continues."


func _lab(t: String, size: int, col: Color) -> Label:
	var l: Label = ThemeS.lab(t, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _size_btn(b: Button) -> void:
	var sc: float = ThemeS.text_scale()
	b.custom_minimum_size = Vector2(280.0 * sc, 56.0 * sc)
	b.focus_mode = Control.FOCUS_ALL


func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
