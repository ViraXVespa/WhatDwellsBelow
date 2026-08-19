extends Control

var _done := false
var fade: ColorRect
var credit: VBoxContainer
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/ui/splash_bg.jpg"):
		bg.texture = load("res://assets/ui/splash_bg.jpg")
	add_child(bg)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.06, 0.42)
	add_child(dim)

	credit = VBoxContainer.new()
	credit.set_anchors_preset(Control.PRESET_CENTER)
	credit.offset_left = -520
	credit.offset_right = 520
	credit.offset_top = 220
	credit.offset_bottom = 420
	credit.alignment = BoxContainer.ALIGNMENT_CENTER
	credit.add_theme_constant_override("separation", 10)
	add_child(credit)

	var game := Label.new()
	game.text = "WHAT DWELLS BELOW"
	game.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.add_theme_font_size_override("font_size", 22)
	game.add_theme_color_override("font_color", Color(0.55, 0.9, 0.95))
	game.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	game.add_theme_constant_override("outline_size", 6)
	credit.add_child(game)

	var line := Label.new()
	line.text = "Proudly Vibecoded with Grok"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 42)
	line.add_theme_color_override("font_color", Color(0.98, 0.86, 0.38))
	line.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	line.add_theme_constant_override("outline_size", 10)
	credit.add_child(line)

	var by := Label.new()
	by.text = "by @ViraXVespa"
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	by.add_theme_font_size_override("font_size", 28)
	by.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	by.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	by.add_theme_constant_override("outline_size", 8)
	credit.add_child(by)

	var skip := Label.new()
	skip.text = "A / Start  to skip"
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.add_theme_font_size_override("font_size", 16)
	skip.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75, 0.8))
	credit.add_child(skip)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	credit.modulate.a = 0.0


func _process(delta: float) -> void:
	t += delta
	if t < 0.7:
		fade.color.a = 1.0 - t / 0.7
		credit.modulate.a = clampf(t / 0.45, 0.0, 1.0)
	elif t < 3.6:
		fade.color.a = 0.0
		credit.modulate.a = 1.0
	elif t < 4.3:
		var u := (t - 3.6) / 0.7
		fade.color.a = u
		credit.modulate.a = 1.0 - u
	else:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		_finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.go_plaza()
