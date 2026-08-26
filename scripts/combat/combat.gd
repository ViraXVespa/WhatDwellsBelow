extends Object


static func xz(n: Node3D) -> Vector2:
	var p := n.global_position
	return Vector2(p.x, p.z)


static func los(from: Vector3, to: Vector3, world: World3D) -> bool:
	if world == null:
		return true
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.45, 0), to + Vector3(0, 0.45, 0))
	q.collision_mask = 1
	q.exclude = []
	var hit := space.intersect_ray(q)
	return hit.is_empty()


static func on_screen(n: Node3D, cam: Camera3D) -> bool:
	if cam == null or n == null:
		return false
	if cam.is_position_behind(n.global_position):
		return false
	var vp := cam.get_viewport().get_visible_rect()
	var s := cam.unproject_position(n.global_position)
	return vp.grow(40.0).has_point(s)


static func enemies() -> Array:
	var tree := Engine.get_main_loop()
	if tree == null:
		return []
	return (tree as SceneTree).get_nodes_in_group("enemies")


static func in_arc(origin: Vector3, dir: Vector2, dist: float, arc_deg: float, pos: Vector3) -> bool:
	var d := Vector2(pos.x - origin.x, pos.z - origin.z)
	var L := d.length()
	if L > dist or L < 0.001:
		return L <= 0.2
	if dir.length_squared() < 0.0001:
		return true
	var ang := absf(dir.normalized().angle_to(d / L))
	return ang <= deg_to_rad(arc_deg * 0.5)


static func in_circle(origin: Vector3, radius: float, pos: Vector3) -> bool:
	return Vector2(pos.x - origin.x, pos.z - origin.z).length() <= radius


static func roll_crit(chance: float) -> bool:
	return randf() < chance
