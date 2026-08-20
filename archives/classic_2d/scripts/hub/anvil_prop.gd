class_name AnvilProp
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Anvil"
	var tex := Art.load_tex("res://assets/sprites/props/anvil.png")
	if tex == null:
		tex = Art.solid(Vector2i(52, 36), Color(0.35, 0.36, 0.4))
	add_child(Art.make_sprite(tex, 0.8))
	Art.add_blocker(self, Vector2(72, 40), Vector2(0, 24))


func interact(_player: Node) -> void:
	var uis := get_tree().get_nodes_in_group("anvil_ui")
	if uis.is_empty():
		return
	uis[0].open()
