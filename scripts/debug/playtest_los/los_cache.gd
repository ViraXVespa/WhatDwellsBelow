extends Object

## Per-physics-frame snapshot of the world facts the playtester asks about dozens of times per think
## (grid, closed boss doors, gate/breakable cells, prop cells, A* answers). Rebuilt at most once per physics frame, so
## answers are identical to scanning the groups on every call, just without the repeated group walks.

static var _frame: int = -1
static var _dims: Dictionary = {}
static var _doors: Array = []
static var _obst: Dictionary = {}
static var _prop: Dictionary = {}
static var _paths: Dictionary = {}
static var _dirs: Dictionary = {}
static var _foe_f: int = -1
static var _foe_p: int = 0
static var foe_n: Array = []
static var foe_d: PackedFloat32Array = PackedFloat32Array()
static var foe_boss: PackedByteArray = PackedByteArray()

static func fresh(pt: Node) -> void:
	var f: int = Engine.get_physics_frames()
	if f == _frame:
		return
	_frame = f
	_dims = {}
	_doors = []
	_obst = {}
	_prop = {}
	_paths = {}
	_dirs = {}
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return
	var dung: Node = pt._dungeon()
	if dung != null and dung.get("data") is Dictionary:
		var data: Dictionary = dung.data
		_dims = {"grid": data.grid, "w": int(data.w), "h": int(data.h)}
	for d: Node in tree.get_nodes_in_group("boss_door"):
		if d and is_instance_valid(d) and not (d.get("open") == true):
			_doors.append(d)
	for g: Node in tree.get_nodes_in_group("gates"):
		if g and is_instance_valid(g) and not (g.get("open") == true):
			_obst[pt._cell_of_node(g)] = true
	for b: Node in tree.get_nodes_in_group("breakables"):
		if b and is_instance_valid(b):
			_obst[pt._cell_of_node(b)] = true
	for n: Node in tree.get_nodes_in_group("interact"):
		if n == null or not is_instance_valid(n):
			continue
		var k: String = str(n.get("kind"))
		if k.ends_with("chest") or k == "extract_gate" or k.begins_with("clerk") or k.find("patty") >= 0 or k.find("misc") >= 0:
			_prop[pt._cell_of_node(n)] = true
	for n2: Node in tree.get_nodes_in_group("gather"):
		if n2 and is_instance_valid(n2):
			_prop[pt._cell_of_node(n2)] = true

static func door_blocks(pt: Node, c: Vector2i) -> bool:
	fresh(pt)
	for d: Node in _doors:
		if d.has_method("occupies_cell") and d.occupies_cell(c):
			return true
		for cell: Variant in pt._door_cells(d):
			if cell == c:
				return true
	return false

static func grid_floor(pt: Node, c: Vector2i) -> bool:
	fresh(pt)
	if _dims.is_empty() or c.x < 0 or c.y < 0 or c.x >= int(_dims.w) or c.y >= int(_dims.h):
		return false
	return (_dims.grid as PackedByteArray)[c.y * int(_dims.w) + c.x] == 1

static func steer_floor(pt: Node, c: Vector2i) -> bool:
	return grid_floor(pt, c) and not _obst.has(c) and not door_blocks(pt, c)

static func floor_cell(pt: Node, c: Vector2i) -> bool:
	return steer_floor(pt, c) and not _prop.has(c)

static func dir_get(pt: Node, dir: Vector2) -> Variant:
	fresh(pt)
	return _dirs.get(dir)

static func dir_put(dir: Vector2, ok: bool) -> void:
	_dirs[dir] = ok

static func foes(pt: Node, p: Node) -> void:
	# Alive enemies in group order with their XZ distance to p and boss flag (fills foe_n / foe_d / foe_boss), once per physics frame.
	var f: int = Engine.get_physics_frames()
	var pid: int = p.get_instance_id() if p != null else 0
	if f == _foe_f and pid == _foe_p:
		return
	_foe_f = f
	_foe_p = pid
	foe_n = []
	foe_d = PackedFloat32Array()
	foe_boss = PackedByteArray()
	var tree: SceneTree = pt.get_tree()
	if tree == null or p == null:
		return
	var pa: Vector3 = (p as Node3D).global_position
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(n):
			continue
		var pb: Vector3 = (n as Node3D).global_position
		foe_n.append(n)
		foe_d.append(Vector2(pa.x - pb.x, pa.z - pb.z).length())
		foe_boss.append(1 if pt._is_boss(n) else 0)

static func dims(pt: Node) -> Dictionary:
	fresh(pt)
	return _dims

static func doors(pt: Node) -> Array:
	fresh(pt)
	return _doors

static func prop(pt: Node, c: Vector2i) -> bool:
	fresh(pt)
	return _prop.has(c)

static func path_get(pt: Node, key: Variant) -> Variant:
	fresh(pt)
	return _paths.get(key)

static func path_put(pt: Node, key: Variant, val: Variant) -> void:
	fresh(pt)
	_paths[key] = val
