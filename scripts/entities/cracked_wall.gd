class_name CrackedWall
extends StaticBody2D

var hp := 8.0
var spr: Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("hittable")
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(64, 64)
	cs.shape = sh
	add_child(cs)
	spr = Art.make_sprite(Art.solid(Vector2i(62, 62), Color(0.38, 0.34, 0.32)), 0.92)
	add_child(spr)
	var crack := ColorRect.new()
	crack.size = Vector2(8, 40)
	crack.position = Vector2(-4, -20)
	crack.color = Color(0.12, 0.1, 0.1, 0.9)
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crack)


func take_damage(amount: float, _from: Node = null) -> void:
	hp -= amount
	if spr:
		spr.modulate = Color(0.7, 0.55, 0.5)
	if hp <= 0.0:
		Sfx.play("smash")
		queue_free()
