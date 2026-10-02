extends Object

const T := preload("res://scripts/data/tunables.gd")
const CampMesh := preload("res://scripts/world/camp_build/mesh.gd")

static func box(host: Node3D, pos: Vector3, _box_size: Vector3, _col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	host.add_child(body)
	return body
