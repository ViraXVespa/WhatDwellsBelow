extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Util := preload("res://scripts/debug/playtest_los_util.gd")

static func has_wide_los(pt: Node, a: Node, b: Node) -> bool:
	if pt._door_between(a, b):
		return false
	if not pt._has_los(a, b):
		return false
	if not pt._is_bow():
		return true
	var w3: World3D = Util.world3(pt)
	if w3 == null:
		return true
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var d: Vector3 = Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
	if d.length() < 0.001:
		return true
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x).normalized() * 0.32
	if not Combat.los(pa + perp, pb + perp, w3):
		return false
	if not Combat.los(pa - perp, pb - perp, w3):
		return false
	return true

static func dir_open(pt: Node, p: Node, dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return true
	var n: Vector2 = dir.normalized()
	if pt._dir_hits_door(p, n):
		return false
	var pos: Vector3 = (p as Node3D).global_position
	for t: float in [0.18, 0.34, 0.55]:
		var probe: Vector3 = Vector3(pos.x + n.x * t, pos.y, pos.z + n.y * t)
		if not pt._pos_walkable(probe):
			return false
	if p is CharacterBody3D:
		var body: CharacterBody3D = p as CharacterBody3D
		var motion: Vector3 = Vector3(n.x, 0.0, n.y) * 0.42
		if body.test_move(body.global_transform, motion):
			return false
	return true

static func dir_hits_door(pt: Node, p: Node, dir: Vector2) -> bool:
	if dir.length() < 0.05:
		return false
	var from: Vector3 = (p as Node3D).global_position
	var n: Vector2 = dir.normalized()
	var probes: PackedFloat32Array = PackedFloat32Array([0.55, 0.95, 1.25])
	for step: float in probes:
		var nxt: Vector3 = from + Vector3(n.x, 0.0, n.y) * step
		if pt._door_blocks_cell(pt._cell_of_pos(nxt)):
			return true
	return false
