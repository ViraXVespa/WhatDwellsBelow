class_name GroundDrop
extends Area2D

var item: ItemData


func setup(it: ItemData) -> void:
	item = it
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 20
	cs.shape = sh
	add_child(cs)
	var col := Art.rarity_color(it.rarity) if it else Color(0.7, 0.7, 0.7)
	add_child(Art.make_sprite(Art.solid(Vector2i(14, 14), col), 0.9))
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if not (body is Player) or item == null:
		return
	if Game.add_to_bag(item):
		Sfx.play("pickup")
		queue_free()
	else:
		Game.toast("Bag full — make a hole or mail something.", Color(0.95, 0.7, 0.35))
