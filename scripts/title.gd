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
	card.offset_top = -220
	card.offset_bottom = 260
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 12)
	add_child(card)

	var game := _lab("WHAT DWELLS BELOW", 56, Color(0.55, 0.92, 0.96))
	card.add_child(game)

	var sub := _lab("A playable demo", 22, Color(0.86, 0.82, 0.72))
	card.add_child(sub)
	var line := _lab("Pilot an avatar. Mail it home. Remember a fragment.", 18, Color(0.78, 0.84, 0.86))
	card.add_child(line)
	var cred := _lab("Dungeon: 8-Bit — ViraXVespa", 16, Color(0.62, 0.66, 0.7))
	card.add_child(cred)

	var prompt := _lab("A / Start  ·  click Play", 20, Color(0.95, 0.86, 0.4))
	prompt.name = "Prompt"
	card.add_child(prompt)

	var views := HBoxContainer.new()
	views.alignment = BoxContainer.ALIGNMENT_CENTER
	views.add_theme_constant_override("separation", 18)
	card.add_child(views)
	views.add_child(_view_btn("Play", "live"))
	views.add_child(_view_btn("Archives", ""))

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


func _view_btn(text: String, pres: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 56)
	b.add_theme_font_size_override("font_size", 22)
	if pres == "":
		b.pressed.connect(_open_archives)
	else:
		b.pressed.connect(func(): _enter(pres))
	return b


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
	if get_node_or_null("ArchiveLayer") != null:
		if event.is_action_pressed("ui_cancel"):
			get_node("ArchiveLayer").queue_free()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		_enter("live")
		get_viewport().set_input_as_handled()


func _open_archives() -> void:
	if _done:
		return
	if get_node_or_null("ArchiveLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ArchiveLayer"
	layer.layer = 20
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(560, 180)
	panel.size = Vector2(800, 640)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 24
	v.offset_right = -28
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Archives"
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	v.add_child(t)
	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Frozen looks from earlier builds so you can follow how the demo grew. Your save still applies. Play is the current game."
	blurb.add_theme_font_size_override("font_size", 18)
	blurb.add_theme_color_override("font_color", Color(0.82, 0.8, 0.74))
	v.add_child(blurb)
	v.add_child(_arch_btn("Classic 2D", "Early slice. Flat 2D camera, same Placeholdia and diver.", "classic_2d", layer))
	v.add_child(_arch_btn("Art experiment", "A 3D look-test with a different cast and setting. Not the game — kept as a snapshot.", "art_experiment", layer))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(func(): layer.queue_free())
	v.add_child(back)
	PadUi.wire(panel)
	add_child(layer)
	PadUi.focus_first(panel)


func _arch_btn(title: String, body: String, pres: String, layer: CanvasLayer) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, body]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func():
		layer.queue_free()
		_enter(pres)
	)
	return b


func _enter(pres: String) -> void:
	if _done:
		return
	_done = true
	Game.set_presentation(pres, false)
	Game.go_plaza()
