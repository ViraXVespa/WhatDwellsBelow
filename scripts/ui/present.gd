extends CanvasLayer

## Enter (consciousness-transfer) and wake-up presentation beats.

const ThemeS := preload("res://scripts/ui/theme.gd")

var overlay: ColorRect
var caption: Label
var playing := false
var _mode := ""
var _t := 0.0
var _wake_hold := false
var _enter_load := false
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
	caption.add_theme_font_size_override("font_size", ThemeS.font_px(32))
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


func cover_enter() -> void:
	playing = true
	visible = true
	_mode = "enter_hold"
	_t = 0.0
	_done = Callable()
	caption.text = "Consciousness slips the body…"
	overlay.color = Color(0.2, 0.75, 0.95, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.queue_redraw()


func wait_painted() -> void:
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(0.0, true, false, true).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func release_enter() -> void:
	if _mode != "enter_hold":
		return
	_mode = "enter_fade"
	_t = 0.0


func play_wake() -> void:
	playing = true
	visible = true
	_mode = "wake"
	_t = 0.0
	_wake_hold = false
	_done = Callable()
	caption.text = "You wake in Placeholdia."
	overlay.color = Color(0.95, 0.88, 0.7, 1.0)
	App.sfx("wake")


func cover_wake() -> void:
	play_wake()
	_wake_hold = true
	_t = 0.0
	overlay.color.a = 1.0


func release_wake() -> void:
	if _mode != "wake":
		play_wake()
		return
	_wake_hold = false
	_t = 0.0


func hide_overlay() -> void:
	playing = false
	_mode = ""
	_wake_hold = false
	_enter_load = false
	visible = false
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = ""
	_done = Callable()


func _physics_process(delta: float) -> void:
	if not playing:
		return
	if (_mode == "wake" and _wake_hold) or _mode == "enter_hold":
		overlay.color.a = 1.0
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
	elif _mode == "enter_fade":
		overlay.color.a = lerpf(1.0, 0.0, clampf(_t / 1.05, 0.0, 1.0))
		if _t >= 1.05:
			hide_overlay()
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
	_wake_hold = false
	visible = false
	caption.text = ""
