class_name AnvilProp
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Anvil"
	var spr := Sprite2D.new()
	spr.texture = Art.solid(Vector2i(52, 36), Color(0.35, 0.36, 0.4))
	add_child(spr)


func interact(_player: Node) -> void:
	var uis := get_tree().get_nodes_in_group("anvil_ui")
	if uis.is_empty():
		return
	uis[0].open()
