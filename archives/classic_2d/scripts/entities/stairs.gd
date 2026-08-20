class_name Stairs
extends Interactable

var locked := false


func _ready() -> void:
	super._ready()
	prompt = "Descend"
	var tex := Art.load_tex("res://assets/sprites/props/stairs.png")
	if tex == null:
		tex = Art.stairs(Vector2i(64, 64))
	add_child(Art.make_sprite(tex, 0.9))
	var lab := Label.new()
	lab.text = "STAIRS"
	lab.position = Vector2(-34, -50)
	lab.size = Vector2(68, 20)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.45, 0.92, 0.95))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.1))
	lab.add_theme_constant_override("outline_size", 4)
	add_child(lab)


func setup(is_locked: bool) -> void:
	locked = is_locked
	prompt = "That's as deep as this expedition maps" if locked else "Descend stairs"


func get_prompt() -> String:
	if _guardian_up():
		return "The guardian blocks the stairs"
	if locked:
		return "That's as deep as this expedition maps"
	return "Descend stairs"


func interact(_player: Node) -> void:
	if _guardian_up() or locked:
		return
	Game.next_floor()


func _guardian_up() -> bool:
	return not get_tree().get_nodes_in_group("boss").is_empty()
