extends CanvasLayer

## Enter (consciousness-transfer) and wake-up presentation beats.

var overlay: ColorRect
var caption: Label
var playing := false
var _mode := ""
var _t := 0.0
var _done: Callable = Callable()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_physics_process(true)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.05, 0.12, 0.18, 0.0)
	add_child(overlay)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_CENTER)
	caption.offset_left = -480
	caption.offset_right = 480
	caption.offset_top = -40
	caption.offset_bottom = 40
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 32)
	caption.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06))
	caption.add_theme_constant_override("outline_size", 8)
	add_child(caption)


func play_enter(done: Callable) -> void:
	playing = true
	visible = true
	_mode = "enter"
	_t = 0.0
	_done = done
	caption.text = "Consciousness slips the body…"
	overlay.color = Color(0.2, 0.75, 0.95, 0.0)
	App.sfx("enter")
	get_tree().create_timer(1.05, true, false, true).timeout.connect(_finish_enter)


func play_wake() -> void:
	playing = true
	visible = true
	_mode = "wake"
	_t = 0.0
	_done = Callable()
	caption.text = "You wake in Placeholdia."
	overlay.color = Color(0.95, 0.88, 0.7, 1.0)
	App.sfx("wake")


func hide_overlay() -> void:
	playing = false
	_mode = ""
	visible = false
	caption.text = ""
	_done = Callable()


func _physics_process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	if _mode == "enter":
		if _t < 0.45:
			overlay.color.a = lerpf(0.0, 0.92, _t / 0.45)
		elif _t < 0.8:
			overlay.color.a = 0.92
		else:
			overlay.color.a = lerpf(0.92, 1.0, clampf((_t - 0.8) / 0.2, 0.0, 1.0))
		if _t >= 1.0:
			_finish_enter()
	elif _mode == "wake":
		overlay.color.a = lerpf(1.0, 0.0, clampf(_t / 1.1, 0.0, 1.0))
		if _t >= 1.1:
			_finish_wake()


func _finish_enter() -> void:
	if _mode != "enter":
		return
	playing = false
	_mode = ""
	var cb := _done
	_done = Callable()
	if cb.is_valid():
		cb.call()


func _finish_wake() -> void:
	if _mode != "wake":
		return
	playing = false
	_mode = ""
	visible = false
	caption.text = ""
