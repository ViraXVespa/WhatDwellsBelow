class_name Receptionist
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Talk: Guild clerk"
	var tex := Art.load_tex("res://assets/sprites/npcs/receptionist.png")
	if tex == null:
		tex = Art.body(Vector2i(48, 64), Color(0.45, 0.32, 0.55), Color(0.9, 0.85, 0.7))
	add_child(Art.make_sprite(tex, 0.78))
	Art.add_blocker(self, Vector2(22, 18), Vector2(0, 12))


func interact(_player: Node) -> void:
	var body := "Welcome to Placeholdia, pop. whoever showed up. Real city's still in permitting. Crystal's open. Dying's a workplace hazard — pack snacks."
	if Game.save and not Game.save.has_dived:
		body = "First time? Eh, I'm sure you'll be able to figure it out.\n\n" + body
	_toast(body)


func _toast(text: String) -> void:
	for c in get_tree().root.get_children():
		if c.name == "ToastLayer":
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.position = Vector2(480, 80)
	lab.size = Vector2(960, 100)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lab.add_theme_constant_override("outline_size", 6)
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	get_tree().create_timer(3.6).timeout.connect(layer.queue_free)
