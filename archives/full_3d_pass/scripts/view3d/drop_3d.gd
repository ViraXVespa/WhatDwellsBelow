extends Area3D

const V3 := preload("res://scripts/view3d/v3.gd")

var item: ItemData


func setup(it: ItemData, pos: Vector3) -> void:
	item = it
	global_position = pos
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.32
	cs.shape = sh
	add_child(cs)
	var col := Art.rarity_color(it.rarity) if it else Color(0.7, 0.7, 0.7)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, 0.22)
	mesh.mesh = box
	mesh.material_override = V3.mat_color(col)
	mesh.position.y = 0.12
	add_child(mesh)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if item == null or not body.is_in_group("player"):
		return
	if Game.add_to_bag(item):
		Sfx.play("pickup")
		queue_free()
	else:
		Game.toast("Bag full — make a hole or mail something.", Color(0.95, 0.7, 0.35))
