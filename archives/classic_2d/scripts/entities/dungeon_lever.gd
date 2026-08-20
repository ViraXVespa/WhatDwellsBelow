class_name DungeonLever
extends Interactable

var lever_id := 0
var flipped := false


func setup(id: int) -> void:
	lever_id = id
	prompt = "Pull lever"


func _ready() -> void:
	super._ready()
	add_child(Art.make_sprite(Art.solid(Vector2i(18, 40), Color(0.62, 0.5, 0.28)), 0.7))


func get_prompt() -> String:
	return "Lever (flipped)" if flipped else "Pull lever"


func interact(_player: Node) -> void:
	if flipped:
		return
	flipped = true
	modulate = Color(0.85, 0.75, 0.4)
	prompt = "Lever (flipped)"
	Sfx.play("ui")
	for g in get_tree().get_nodes_in_group("gates"):
		if g.has_method("open_gate") and int(g.get("gate_id")) == lever_id:
			g.open_gate()
