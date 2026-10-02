extends Object

static var _enemy_frame: int = -1
static var _enemy_cache: Array = []

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
	var frame: int = Engine.get_process_frames()
	if frame == _enemy_frame:
		return _enemy_cache
	var tree := Engine.get_main_loop()
	if tree == null:
		_enemy_cache = []
		_enemy_frame = frame
		return _enemy_cache
	_enemy_cache = (tree as SceneTree).get_nodes_in_group("enemies")
	_enemy_frame = frame
	return _enemy_cache

static func roll_crit(chance: float) -> bool:
	return randf() < chance
