class_name GhostShop
extends Interactable


func _ready() -> void:
	super._ready()
	is_safe = true
	prompt = "Ghost shopkeep"
	var tex := Art.load_tex("res://assets/sprites/npcs/shopkeep.png")
	if tex == null:
		tex = Art.body(Vector2i(56, 56), Color(0.55, 0.72, 0.78), Color(0.85, 0.95, 1.0))
	var spr := Art.make_sprite(tex, 0.82)
	spr.modulate = Color(0.75, 0.9, 1.0, 0.92)
	add_child(spr)
	Art.add_blocker(self, Vector2(30, 36))


func get_prompt() -> String:
	return "Talk: shopkeep (safe)"


func interact(_player: Node) -> void:
	var uis := get_tree().get_nodes_in_group("shop_ui")
	if uis.is_empty():
		return
	uis[0].open()
