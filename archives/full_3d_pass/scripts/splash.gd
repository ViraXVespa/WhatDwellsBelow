extends Control

# Studio credit card — not the game title. Portrait + Grok / xAI marks.
var _done := false
var fade: ColorRect
var card: Control
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var void_bg := ColorRect.new()
	void_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	void_bg.color = Color(0.03, 0.01, 0.05, 1)
	add_child(void_bg)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_right = 0.46
	portrait.offset_right = 0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists("res://assets/ui/vira_profile.jpg"):
		portrait.texture = load("res://assets/ui/vira_profile.jpg")
	add_child(portrait)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_left = 0.46
	shade.offset_left = 0
	shade.color = Color(0.03, 0.01, 0.05, 0.82)
	add_child(shade)

	var edge := ColorRect.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.anchor_left = 0.46
	edge.anchor_right = 0.46
	edge.offset_left = -2
	edge.offset_right = 2
	edge.color = Color(0.72, 0.18, 0.62, 0.55)
	add_child(edge)

	card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	card.anchor_left = 0.50
	card.anchor_right = 0.96
	card.anchor_top = 0.22
	card.anchor_bottom = 0.82
	card.offset_left = 0
	card.offset_right = 0
	card.offset_top = 0
	card.offset_bottom = 0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 14)
	add_child(card)

	var kicker := _lab("A  @ViraXVespa  production", 20, Color(0.78, 0.62, 0.86))
	card.add_child(kicker)

	var line := _lab("Proudly Vibecoded with Grok", 40, Color(0.98, 0.86, 0.38))
	card.add_child(line)

	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 56)
	marks.custom_minimum_size = Vector2(0, 110)
	card.add_child(marks)
	marks.add_child(_mark("res://assets/ui/logo_grok.png", "GROK"))
	marks.add_child(_mark("res://assets/ui/logo_xai.png", "xAI"))

	var skip := _lab("A / Start  to continue", 16, Color(0.7, 0.68, 0.74, 0.8))
	card.add_child(skip)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	card.modulate.a = 0.0


func _mark(path: String, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	box.add_child(icon)
	box.add_child(_lab(caption, 16, Color(0.86, 0.82, 0.9)))
	return box


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", 8 if size >= 28 else 5)
	return l


func _process(delta: float) -> void:
	t += delta
	if t < 0.7:
		fade.color.a = 1.0 - t / 0.7
		card.modulate.a = clampf(t / 0.45, 0.0, 1.0)
	elif t < 4.0:
		fade.color.a = 0.0
		card.modulate.a = 1.0
	elif t < 4.7:
		var u := (t - 4.0) / 0.7
		fade.color.a = u
		card.modulate.a = 1.0 - u
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
	Game.go_title()
