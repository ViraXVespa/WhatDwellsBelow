class_name Interactable
extends Area2D

@export var prompt: String = "Interact"
@export var is_safe: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 0
	add_to_group("interactable")
	if get_child_count() == 0:
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 40
		cs.shape = sh
		add_child(cs)


func get_prompt() -> String:
	return prompt


func interact(_player: Node) -> void:
	pass
