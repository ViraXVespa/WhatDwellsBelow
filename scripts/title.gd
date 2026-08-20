extends Control

# Game title screen. Credit splash is a separate scene.
var _done := false
var fade: ColorRect
var card: VBoxContainer
var t := 0.0
var ready_in := false


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
	dim.color = Color(0.02, 0.03, 0.07, 0.38)
	add_child(dim)

	card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -560
	card.offset_right = 560
	card.offset_top = -160
	card.offset_bottom = 200
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 12)
	add_child(card)

	var game := _lab("WHAT DWELLS BELOW", 56, Color(0.55, 0.92, 0.96))
	card.add_child(game)

	var sub := _lab("A playable demo", 22, Color(0.86, 0.82, 0.72))
	card.add_child(sub)

	var prompt := _lab("A / Start  ·  click  to enter %s" % Game.DEMO_TOWN, 20, Color(0.95, 0.86, 0.4))
	prompt.name = "Prompt"
	card.add_child(prompt)

	var patreon := LinkButton.new()
	patreon.text = "Support on Patreon"
	patreon.uri = Game.PATREON_URL
	patreon.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	patreon.add_theme_font_size_override("font_size", 18)
	patreon.add_theme_color_override("font_color", Color(0.95, 0.55, 0.42))
	patreon.add_theme_color_override("font_hover_color", Color(1.0, 0.72, 0.55))
	patreon.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	patreon.add_theme_constant_override("outline_size", 6)
	card.add_child(patreon)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	card.modulate.a = 0.0


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08))
	l.add_theme_constant_override("outline_size", 10 if size >= 40 else 6)
	return l


func _process(delta: float) -> void:
	t += delta
	if t < 0.65:
		fade.color.a = 1.0 - t / 0.65
		card.modulate.a = clampf(t / 0.4, 0.0, 1.0)
	else:
		fade.color.a = 0.0
		card.modulate.a = 1.0
		ready_in = true
		var prompt := card.get_node_or_null("Prompt") as Label
		if prompt:
			var pulse := 0.72 + 0.28 * sin(t * 3.2)
			prompt.modulate.a = pulse


func _unhandled_input(event: InputEvent) -> void:
	if _done or not ready_in:
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
