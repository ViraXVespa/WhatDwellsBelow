extends StaticBody3D

const T := preload("res://scripts/data/tunables.gd")

var vis: MeshInstance3D
var shape: CollisionShape3D
var open := false
var label: Label3D


func setup(pos: Vector3) -> void:
	position = pos
	collision_layer = 1
	collision_mask = 0
	add_to_group("boss_door")
	add_to_group("interact")
	shape = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.15, T.WALL_H + 0.4, 1.15)
	shape.shape = sh
	shape.position.y = (T.WALL_H + 0.4) * 0.5
	add_child(shape)
	vis = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.15, T.WALL_H + 0.4, 1.15)
	vis.mesh = box
	vis.position.y = (T.WALL_H + 0.4) * 0.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.12, 0.1)
	vis.material_override = m
	add_child(vis)
	label = Label3D.new()
	label.text = "PREPARE"
	label.position = Vector3(0.0, T.WALL_H + 0.55, 0.0)
	label.font_size = 48
	label.outline_size = 10
	label.modulate = Color(1.0, 0.45, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	add_child(label)


func interact(_who: Node) -> String:
	if open:
		return "The way is open."
	return "The guardian still holds this door."


func refresh() -> void:
	pass


func open_door() -> void:
	if open:
		return
	open = true
	collision_layer = 0
	if shape:
		shape.disabled = true
	label.text = "OPEN"
	label.modulate = Color(0.6, 0.95, 0.55)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 1.8, 0.35)
