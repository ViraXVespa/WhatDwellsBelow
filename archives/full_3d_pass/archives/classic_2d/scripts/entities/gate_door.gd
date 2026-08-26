class_name GateDoor
extends StaticBody2D

var gate_id := 0
var open := false
var spr: Sprite2D
var col: CollisionShape2D


func setup(id: int) -> void:
	gate_id = id
	add_to_group("gates")
	collision_layer = 1
	collision_mask = 0
	col = CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(64, 64)
	col.shape = sh
	add_child(col)
	spr = Art.make_sprite(Art.solid(Vector2i(58, 58), Color(0.42, 0.38, 0.34)), 0.85)
	add_child(spr)


func open_gate() -> void:
	if open:
		return
	open = true
	if col:
		col.disabled = true
	if spr:
		spr.modulate = Color(1, 1, 1, 0.15)
	Sfx.play("ui")
