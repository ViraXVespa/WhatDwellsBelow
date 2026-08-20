class_name FloorShrine
extends Interactable

var used := false


func _ready() -> void:
	super._ready()
	prompt = "Touch shrine"
	var tex := Art.load_tex("res://assets/sprites/props/crystal.png")
	add_child(Art.make_sprite(tex if tex else Art.solid(Vector2i(28, 48), Color(0.85, 0.72, 0.25)), 0.62))


func get_prompt() -> String:
	return "Quiet shrine" if used else "Shrine — a little courage"


func interact(_player: Node) -> void:
	if used or Game.run == null:
		return
	used = true
	Game.run.shrine_buff_t = 45.0
	Sfx.play("level")
	modulate = Color(0.55, 0.55, 0.58)
	prompt = "Quiet shrine"
	Game.toast("Something in the stone likes your odds.", Color(0.95, 0.82, 0.4))
