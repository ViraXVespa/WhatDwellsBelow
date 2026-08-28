extends StaticBody3D

const T := preload("res://scripts/data/tunables.gd")

var vis: MeshInstance3D
var shape: CollisionShape3D
var open := false
var label: Label3D
var prompt := "A: Open the guardian door"
var kind := "boss_door"
var reach := 1.85
var cells: Array = []
var side := "s"


func setup(pos: Vector3) -> void:
	setup_opening({
		"cells": [Vector2i(int(pos.x), int(pos.z))],
		"side": "s",
		"cx": pos.x,
		"cz": pos.z,
		"sx": 1.15,
		"sz": 1.15,
		"reach": 1.85,
	})


func setup_opening(opening: Dictionary) -> void:
	side = str(opening.get("side", "s"))
	var raw_cells: Array = opening.get("cells", [])
	cells.clear()
	for c in raw_cells:
		cells.append(Vector2i(c))
	var cx := float(opening.get("cx", 0.5))
	var cz := float(opening.get("cz", 0.5))
	position = Vector3(cx, 0.0, cz)
	var sx := maxf(0.8, float(opening.get("sx", 1.15)))
	var sz := maxf(0.8, float(opening.get("sz", 1.15)))
	reach = maxf(1.85, float(opening.get("reach", 1.85)))
	collision_layer = 1
	collision_mask = 0
	add_to_group("boss_door")
	add_to_group("interact")
	var tall := T.WALL_H + 0.4
	shape = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(sx, tall, sz)
	shape.shape = sh
	shape.position.y = tall * 0.5
	add_child(shape)
	vis = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(sx, tall, sz)
	vis.mesh = box
	vis.position.y = tall * 0.5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.12, 0.1)
	vis.material_override = m
	add_child(vis)
	label = Label3D.new()
	label.text = "PREPARE"
	label.position = Vector3(0.0, tall + 0.55, 0.0)
	label.font_size = 48
	label.outline_size = 10
	label.modulate = Color(1.0, 0.45, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	add_child(label)
	_add_hotspots()
	refresh()


func _add_hotspots() -> void:
	for c in cells:
		var local := Vector3(float(c.x) + 0.5 - position.x, 0.0, float(c.y) + 0.5 - position.z)
		if local.length() < 0.12:
			continue
		var h := Hotspot.new()
		h.host = self
		h.position = local
		add_child(h)
		h.refresh_prompt()


func interact(_who: Node) -> String:
	if open:
		refresh()
		return prompt
	_open_all()
	if App.has_method("sfx"):
		App.sfx("ui")
	if App.has_method("toast"):
		App.toast("The door yields. The guardian waits.")
	return "The door yields. The guardian waits."


func refresh() -> void:
	if open:
		prompt = "The way is open."
	else:
		prompt = "A: Open the guardian door"
	if label:
		label.text = "OPEN" if open else "PREPARE"
		label.modulate = Color(0.6, 0.95, 0.55) if open else Color(1.0, 0.45, 0.35)
	for child in get_children():
		if child is Hotspot:
			child.refresh_prompt()


func _open_all() -> void:
	open_door()
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("boss_door"):
		if n != self and n.has_method("open_door"):
			n.open_door()


func open_door() -> void:
	if open:
		return
	open = true
	collision_layer = 0
	if shape:
		shape.disabled = true
	refresh()
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 1.8, 0.35)


func occupies_cell(c: Vector2i) -> bool:
	if open:
		return false
	for cell in cells:
		if Vector2i(cell) == c:
			return true
	return false


class Hotspot extends Node3D:
	var host: Node
	var prompt := "A: Open the guardian door"
	var kind := "boss_door"

	func _ready() -> void:
		add_to_group("interact")

	func refresh_prompt() -> void:
		if host and host.get("prompt") != null:
			prompt = str(host.prompt)

	func interact(who: Node) -> String:
		if host and host.has_method("interact"):
			return str(host.interact(who))
		return ""