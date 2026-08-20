class_name TownCrystal
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Enter the dungeon"
	var tex := Art.load_tex("res://assets/sprites/props/crystal.png")
	if tex == null:
		tex = Art.solid(Vector2i(56, 80), Color(0.3, 0.85, 0.92))
	add_child(Art.make_sprite(tex, 0.95))
	# Plinth sits below the texture center.
	Art.add_blocker(self, Vector2(54, 28), Vector2(0, 38))


func interact(_player: Node) -> void:
	var uis := get_tree().get_nodes_in_group("loadout_ui")
	if uis.is_empty():
		Game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)
		return
	(uis[0] as LoadoutUI).open()
