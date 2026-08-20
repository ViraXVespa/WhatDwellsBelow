class_name Campfire
extends Interactable

var used := false


func _ready() -> void:
	super._ready()
	prompt = "Warm up"
	add_child(Art.make_sprite(Art.solid(Vector2i(34, 24), Color(0.78, 0.32, 0.1)), 0.85))


func get_prompt() -> String:
	return "Embers (spent)" if used else "Campfire — sit a second"


func interact(_player: Node) -> void:
	if used or Game.run == null:
		return
	used = true
	Game.heal_player(28.0)
	Game.restore_mana(18.0)
	Sfx.play("pickup")
	modulate = Color(0.5, 0.5, 0.52)
	prompt = "Embers (spent)"
