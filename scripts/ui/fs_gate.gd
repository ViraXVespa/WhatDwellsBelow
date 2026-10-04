extends Control

## Web pre-splash: platform copy + a gesture that can request fullscreen / PWA install.

const Disp := preload("res://scripts/display_mode.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const SplitView := preload("res://scripts/ui/split_menu/split_menu_view.gd")

var _kind: String = "web"
var _action: Button
var _continue: Button
var _hint: Label
var _leaving := false
var _was_a := false
var _was_b := false
var _was_start := false
var _was_back := false

func _ready() -> void:
	_kind = Disp.web_kind()
	if _kind == "":
		_kind = "web"
	mouse_filter = Control.MOUSE_FILTER_STOP
	ThemeS.fill(self)

	var bg := ColorRect.new()
	ThemeS.fill(bg)
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

	card.add_child(_lab(tr("fs_gate.what_dwells_below"), 40, Color(0.92, 0.78, 0.48)))
	card.add_child(_lab(_headline(), 26, Color(0.95, 0.86, 0.4)))
	card.add_child(_lab(_body(), 18, Color(0.78, 0.72, 0.62)))

	_hint = _lab(_rotate_line(), 16, Color(0.7, 0.62, 0.48))
	card.add_child(_hint)

	_action = ThemeS.btn(_action_label(), _on_action)
	_size_btn(_action)
	card.add_child(_action)

	_continue = ThemeS.btn(tr("common.continue"), _on_continue)
	_size_btn(_continue)
	card.add_child(_continue)

	SplitView.wire_vert([_action, _continue])
	_action.grab_focus()

	call_deferred("_wake")

func _wake() -> void:
	if App and App.has_method("wake_web_pad"):
		App.wake_web_pad()
	call_deferred("_refocus")

func _refocus() -> void:
	if _leaving or _action == null:
		return
	_action.grab_focus()

func _process(_dt: float) -> void:
	if _leaving:
		return
	if _hint:
		_hint.text = _rotate_line()
	_keep_focus()
	if Disp.is_fullscreen_now() or Disp.is_standalone():
		_leave()
		return
	_poll_web_pad()

func _keep_focus() -> void:
	if _action == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused == _action or focused == _continue:
		return
	_action.grab_focus()

func _poll_web_pad() -> void:
	var wp: Node = App.web_pad if App else null
	var a_now := false
	var b_now := false
	var start_now := false
	var back_now := false
	if wp:
		a_now = bool(wp.get("a"))
		b_now = bool(wp.get("b"))
		start_now = bool(wp.get("start"))
		back_now = bool(wp.get("back"))
	if (a_now and not _was_a) or (start_now and not _was_start):
		_activate_focused()
	elif (b_now and not _was_b) or (back_now and not _was_back):
		_on_continue()
	_was_a = a_now
	_was_b = b_now
	_was_start = start_now
	_was_back = back_now

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_activate_focused()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_continue()
		get_viewport().set_input_as_handled()

func _activate_focused() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused == _continue:
		_on_continue()
		return
	_on_action()

func _on_action() -> void:
	if _leaving:
		return
	Disp.try_fullscreen_gesture()
	if Disp.is_fullscreen_now() or Disp.is_standalone():
		_leave()
		return
	if _kind == "ios" and _hint:
		_hint.text = tr("fs_gate.safari_cannot_open_add_to")

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
		return tr("fs_gate.fullscreen_on_iphone")
	if _kind == "android":
		return tr("fs_gate.play_fullscreen")
	return tr("fs_gate.enter_fullscreen")

func _body() -> String:
	if _kind == "ios":
		return App.tr("fs_gate.iphone_safari_cannot_hide")
	if _kind == "android":
		return tr("fs_gate.tap_fullscreen_to_hide_the")
	return tr("fs_gate.click_fullscreen_to_hide_browser")

func _action_label() -> String:
	if _kind == "ios":
		return tr("fs_gate.try_fullscreen")
	if _kind == "android":
		return tr("fs_gate.fullscreen_install")
	return App.tr("fs_gate.fullscreen")

func _rotate_line() -> String:
	if Disp.viewport_portrait():
		return tr("fs_gate.rotate_the_device_to_landscape")
	return Prompts.fmt(tr("fs_gate.a_confirms_the_focused_button"))

func _lab(t: String, font_px: int, col: Color) -> Label:
	var l: Label = ThemeS.lab(t, font_px, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _size_btn(b: Button) -> void:
	var sc: float = ThemeS.text_scale()
	b.custom_minimum_size = Vector2(280.0 * sc, 56.0 * sc)
	b.focus_mode = Control.FOCUS_ALL
