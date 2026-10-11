extends Object

## Spatial index over LightRt._casts for nearest_casts. Rebuilt when LightRt._casts_ver moves (publish.gd
## _keep_casts). Each cast is listed in every CELL-sized cell its reach disk's box touches, in _casts order,
## so a point's cell holds every cast that can reach it, ascending.

const CELL := 4.0

static var _ver: int = -1
static var _grid: Dictionary = {}

static func _key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))

static func at(casts: Array[Dictionary], ver: int, world: Vector2) -> PackedInt32Array:
	if ver != _ver:
		_ver = ver
		_grid = {}
		for i in casts.size():
			var xz: Vector2 = casts[i]["xz"]
			var r: float = float(casts[i]["reach"])
			var lo: Vector2i = _key(xz.x - r, xz.y - r)
			var hi: Vector2i = _key(xz.x + r, xz.y + r)
			for cz in range(lo.y, hi.y + 1):
				for cx in range(lo.x, hi.x + 1):
					var k := Vector2i(cx, cz)
					if not _grid.has(k):
						_grid[k] = PackedInt32Array()
					(_grid[k] as PackedInt32Array).append(i)
	var hit: Variant = _grid.get(_key(world.x, world.y))
	return hit if hit != null else PackedInt32Array()
