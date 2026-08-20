class_name FloorShrine
extends Interactable

var used := false


func _ready() -> void:
	super._ready()
	prompt = "Touch shrine"
	add_child(Art.make_sprite(Art.solid(Vector2i(22, 40), Color(0.78, 0.58, 0.18)), 0.78))
	var cap := ColorRect.new()
	cap.size = Vector2(18, 8)
	cap.position = Vector2(-9, -28)
	cap.color = Color(0.95, 0.82, 0.35, 0.95)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)


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
