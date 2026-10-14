extends Object

## Breakables hit walk shared by player melee (player_hit.gd arc / circle) and arrows (projectile.gd).
## The group list is fetched once per physics frame (again if the group size changes); each walk only tests breakables whose XZ position is within
## reach + PAD of the centre (PAD covers sprite width and the screen-space height the Cover tests project).
## `test(b) -> bool` is the existing Cover/LOS check; a true hit calls b.take_hit(dmg, dir, false).

const PAD := 8.0

static var _frame: int = -1
static var _count: int = -1
static var _list: Array[Node] = []

static func _all(tree: SceneTree) -> Array[Node]:
	var f: int = Engine.get_physics_frames()
	var n: int = tree.get_node_count_in_group("breakables")
	if f != _frame or n != _count:
		_frame = f
		_count = n
		_list = tree.get_nodes_in_group("breakables")
	return _list

static func smash(tree: SceneTree, center: Vector3, reach: float, dmg: float, dir: Vector2, test: Callable) -> void:
	if tree == null:
		return
	var lim: float = reach + PAD
	var lim2: float = lim * lim
	for b in _all(tree):
		if b == null or not is_instance_valid(b) or not (b is Node3D) or not b.is_inside_tree():
			continue
		var p: Vector3 = (b as Node3D).global_position
		var dx: float = p.x - center.x
		var dz: float = p.z - center.z
		if dx * dx + dz * dz > lim2:
			continue
		if not test.call(b):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, dir, false)
