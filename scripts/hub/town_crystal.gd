class_name TownCrystal
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Enter the dungeon"
	var spr := Sprite2D.new()
	spr.texture = Art.solid(Vector2i(56, 80), Color(0.3, 0.85, 0.92))
	add_child(spr)


func interact(_player: Node) -> void:
	var uis := get_tree().get_nodes_in_group("loadout_ui")
	if uis.is_empty():
		Game.begin_run(ItemData.make_starter_axe(), ItemData.make_starter_pickaxe(), 1)
		return
	(uis[0] as LoadoutUI).open()
