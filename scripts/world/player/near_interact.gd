extends Object

## Nearest `interact` node in XZ range of the player (design/interactables.md). `nearest` walks the group;
## `cached` reuses the last answer while the player has not moved, the group size is unchanged and the
## answer is under REFRESH physics frames old (the per-tick prompt path).

const REFRESH := 8

static var _host_id: int = 0
static var _pos: Vector2 = Vector2.INF
static var _count: int = -1
static var _frame: int = -1000
static var _best: Node = null
static var _radius: float = 0.0

static func nearest(host: Node3D, radius: float) -> Node:
	var best: Node = null
	var best_d := radius
	var hx: float = host.global_position.x
	var hz: float = host.global_position.z
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var p: Vector3 = (n as Node3D).global_position
			var d := Vector2(p.x - hx, p.z - hz).length()
			if d < best_d:
				best_d = d
				best = n
	return best

static func cached(host: Node3D, radius: float) -> Node:
	var tree: SceneTree = host.get_tree()
	var pos := Vector2(host.global_position.x, host.global_position.z)
	var f: int = Engine.get_physics_frames()
	var count: int = tree.get_node_count_in_group("interact")
	var hid: int = host.get_instance_id()
	var fresh: bool = hid == _host_id and pos == _pos and count == _count and radius == _radius and f - _frame < REFRESH and f >= _frame
	if fresh and (_best == null or is_instance_valid(_best)):
		return _best
	_best = nearest(host, radius)
	_host_id = hid
	_pos = pos
	_count = count
	_radius = radius
	_frame = f
	return _best
