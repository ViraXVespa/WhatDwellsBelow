extends Object

## Spatial subset for enemy separation (enemy_ai.gd sep). Once per physics frame the Combat.enemies() list is
## bucketed into square cells of side (enemy_sep + SLACK) by position; a query returns the list indices from the
## 3x3 cells around a point in ascending list order, so sep() visits candidates in the same order as the full
## walk. SLACK covers enemies that move later in the same frame (sep still reads live positions).

const Combat := preload("res://scripts/combat/combat.gd")
const SLACK := 2.0

static var _frame: int = -1
static var _list: Array = []
static var _cell: float = 1.0
static var _grid: Dictionary = {}

static func _key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / _cell), floori(z / _cell))

static func _build(lim: float) -> void:
	var f: int = Engine.get_physics_frames()
	var list: Array = Combat.enemies()
	var cell: float = maxf(0.5, lim + SLACK)
	if f == _frame and is_same(list, _list) and cell == _cell:
		return
	_frame = f
	_list = list
	_cell = cell
	_grid = {}
	for i in list.size():
		var e: Variant = list[i]
		if e == null or not is_instance_valid(e):
			continue
		var p: Vector3 = (e as Node3D).global_position
		var k: Vector2i = _key(p.x, p.z)
		if not _grid.has(k):
			_grid[k] = PackedInt32Array()
		(_grid[k] as PackedInt32Array).append(i)

## Candidate indices into near_list() around `at`, ascending.
static func near(at: Vector3, lim: float) -> PackedInt32Array:
	_build(lim)
	var out := PackedInt32Array()
	var c: Vector2i = _key(at.x, at.z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _grid.has(k):
				out.append_array(_grid[k])
	out.sort()
	return out

static func near_list() -> Array:
	return _list
