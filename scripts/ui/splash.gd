extends Control

## Credit splash. Locked graffiti: Shamelessly Vibecoded with Grok.

const T := preload("res://scripts/data/tunables.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

var graffiti: Control
var _t := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/splash_bg.jpg"):
		bg.texture = load("res://assets/ui/splash_bg.jpg")
	else:
		var fill := ColorRect.new()
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill.color = Color(0.05, 0.04, 0.035, 1)
		add_child(fill)
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.42)
	add_child(dim)
	_row_logos()
	_graffiti()
	var hint := ThemeS.lab("A / Start  —  continue", 18, Color(0.85, 0.78, 0.62))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -240
	hint.offset_right = 240
	hint.offset_top = -80
	hint.offset_bottom = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	call_deferred("_focus")
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase9-smoke" in args:
		printerr("P9: splash_graffiti=Shamelessly Vibecoded with Grok")


func _focus() -> void:
	for n in find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


func _row_logos() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -420
	row.offset_right = 420
	row.offset_top = 48
	row.offset_bottom = 180
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	add_child(row)
	for p in ["res://assets/ui/logo_grok.png", "res://assets/ui/logo_xai.png", "res://assets/ui/vira_profile.jpg"]:
		if not ResourceLoader.exists(p):
			continue
		var t := TextureRect.new()
		t.texture = load(p)
		t.custom_minimum_size = Vector2(120, 120)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if p.ends_with(".png") else CanvasItem.TEXTURE_FILTER_LINEAR
		row.add_child(t)


func _graffiti() -> void:
	graffiti = Control.new()
	graffiti.set_anchors_preset(Control.PRESET_CENTER)
	graffiti.offset_left = -520
	graffiti.offset_right = 520
	graffiti.offset_top = -80
	graffiti.offset_bottom = 220
	add_child(graffiti)
	var proudly := Label.new()
	proudly.text = "Proudly"
	proudly.position = Vector2(80, 24)
	proudly.size = Vector2(360, 56)
	proudly.add_theme_font_size_override("font_size", 42)
	proudly.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	proudly.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02))
	proudly.add_theme_constant_override("outline_size", 6)
	graffiti.add_child(proudly)
	var strike := ColorRect.new()
	strike.color = Color(0.85, 0.12, 0.1, 0.92)
	strike.position = Vector2(70, 50)
	strike.size = Vector2(250, 8)
	strike.rotation_degrees = -4.0
	graffiti.add_child(strike)
	var shameless := Label.new()
	shameless.text = "Shamelessly"
	shameless.position = Vector2(40, -8)
	shameless.size = Vector2(520, 70)
	shameless.rotation_degrees = -8.5
	shameless.add_theme_font_size_override("font_size", 48)
	shameless.add_theme_color_override("font_color", Color(0.35, 0.95, 0.42))
	shameless.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.03))
	shameless.add_theme_constant_override("outline_size", 10)
	graffiti.add_child(shameless)
	var rest := Label.new()
	rest.text = "Vibecoded with Grok."
	rest.position = Vector2(40, 96)
	rest.size = Vector2(900, 70)
	rest.add_theme_font_size_override("font_size", 40)
	rest.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	rest.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02))
	rest.add_theme_constant_override("outline_size", 8)
	graffiti.add_child(rest)
	var bitter := Label.new()
	bitter.text = "Bitter — ViraXVespa"
	bitter.position = Vector2(40, 170)
	bitter.size = Vector2(700, 36)
	bitter.add_theme_font_size_override("font_size", 20)
	bitter.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
	graffiti.add_child(bitter)
	var go := ThemeS.btn("Continue  (A)", _advance)
	go.position = Vector2(40, 210)
	go.custom_minimum_size = Vector2(280, 52)
	graffiti.add_child(go)


func _advance() -> void:
	if _done:
		return
	_done = true
	get_tree().call_deferred("change_scene_to_file", "res://scenes/title.tscn")


func _process(delta: float) -> void:
	_t += delta
	if _t >= 4.2:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		_advance()
		get_viewport().set_input_as_handled()
