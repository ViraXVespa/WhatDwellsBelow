class_name PressurePlate
extends Area2D

var plate_id := 0
var latched := false
var spr: Sprite2D


func setup(id: int) -> void:
	plate_id = id
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(48, 48)
	cs.shape = sh
	add_child(cs)
	spr = Art.make_sprite(Art.solid(Vector2i(44, 44), Color(0.55, 0.48, 0.32)), 0.5)
	add_child(spr)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if latched:
		return
	if body is Player:
		latched = true
		if spr:
			spr.modulate = Color(0.85, 0.72, 0.35)
		_open_gates()


func _open_gates() -> void:
	for g in get_tree().get_nodes_in_group("gates"):
		if g.has_method("open_gate") and int(g.get("gate_id")) == plate_id:
			g.open_gate()
