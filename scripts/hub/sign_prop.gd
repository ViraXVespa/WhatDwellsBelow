class_name SignProp
extends Interactable

var title := ""
var body := ""
var popup: Control


func setup(p_title: String, p_body: String) -> void:
	title = p_title
	body = p_body
	prompt = p_title


func _ready() -> void:
	super._ready()
	var spr := Sprite2D.new()
	spr.texture = Art.solid(Vector2i(40, 40), Color(0.55, 0.4, 0.25))
	add_child(spr)
	prompt = title if title != "" else prompt


func interact(_player: Node) -> void:
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
	lab.size = Vector2(960, 80)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	get_tree().create_timer(3.2).timeout.connect(layer.queue_free)
