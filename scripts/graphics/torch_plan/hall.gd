extends Object

## Split from torch_plan.gd: _hall_rhythm, _near_grid, _mark_near....

const Spans := preload("res://scripts/graphics/torch_plan/spans.gd")

## Hall cadence only fills dark stretches: no rhythm torch within HALL_GAP cells of another torch. Run order is a
## flood fill, so index steps alone stacked torches beside the mouth and spur ones (742 vs 399 sites on floor 1 seed 42;
## 44 lights in the 96x96 ring against the 24 cap, so the extra torches popped in as the ring moved).
const HALL_GAP := 12

static func _hall_rhythm(_host: Node, hall: PackedByteArray, hall_ix: PackedInt32Array, map_w: int, map_h: int, per: int, used: Dictionary, out: Array[Dictionary]) -> void:
	var seed_n := 1
	if App != null:
		seed_n = int(App.run_seed) * 17 + int(App.floor_n) * 31
	var seen := PackedByteArray()
	seen.resize(map_w * map_h)
	seen.fill(0)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var near: Dictionary = _near_grid(used)
	var hi := 0
	while hi < hall_ix.size():
		var start_i: int = hall_ix[hi]
		hi += 1
		if start_i < 0 or start_i >= hall.size() or hall[start_i] == 0 or seen[start_i] != 0:
			continue
		var run: Array[Vector2i] = []
		var stack: Array[int] = [start_i]
		seen[start_i] = 1
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			var cy := int(float(cur) / float(map_w))
			var cx := cur - cy * map_w
			run.append(Vector2i(cx, cy))
			for d in dirs:
				var nx := cx + d.x
				var ny := cy + d.y
				if nx < 1 or ny < 1 or nx >= map_w - 1 or ny >= map_h - 1:
					continue
				var ni := ny * map_w + nx
				if hall[ni] == 0 or seen[ni] != 0:
					continue
				seen[ni] = 1
				stack.append(ni)
		if run.size() < 8:
			continue
		var step := 7 + int(abs(seed_n + run[0].x * 13 + run[0].y * 29)) % 5
		var phase := int(abs(seed_n + run[0].y * 7)) % step
		var i2 := phase
		while i2 < run.size():
			var spot: Vector2i = run[i2]
			i2 += step
			if _taken(used, spot) or _lit_near(near, spot):
				continue
			var site: Dictionary = Spans._span_at(per, spot)
			if site.is_empty():
				continue
			var mounted := Vector2i(int(site["fx"]), int(site["fz"]))
			if _taken(used, mounted):
				continue
			used[mounted] = true
			_mark_near(near, mounted)
			out.append(site)

static func _near_grid(used: Dictionary) -> Dictionary:
	var g: Dictionary = {}
	for c: Vector2i in used:
		_mark_near(g, c)
	return g

static func _mark_near(g: Dictionary, c: Vector2i) -> void:
	var k := Vector2i(floori(float(c.x) / HALL_GAP), floori(float(c.y) / HALL_GAP))
	if not g.has(k):
		g[k] = []
	(g[k] as Array).append(c)

static func _lit_near(g: Dictionary, c: Vector2i) -> bool:
	var k := Vector2i(floori(float(c.x) / HALL_GAP), floori(float(c.y) / HALL_GAP))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for o: Vector2i in g.get(k + Vector2i(dx, dy), []):
				if absi(o.x - c.x) + absi(o.y - c.y) <= HALL_GAP:
					return true
	return false

static func _taken(used: Dictionary, cell: Vector2i) -> bool:
	for z in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) + absi(z) > 2:
				continue
			if used.has(cell + Vector2i(x, z)):
				return true
	return false
