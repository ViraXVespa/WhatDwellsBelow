# Pathfinding utilities for PlaytestPath

const REACH := 36
const ASTAR_GUARD := 720


static func _manh(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _toward(pt: Node, start: Vector2i, goal: Vector2i) -> Vector2i:
	var md: int = _manh(start, goal)
	if md <= REACH:
		return goal
	var cur: Vector2i = start
	var i: int = 0
	while i < REACH:
		i += 1
		var step: Vector2i = Vector2i.ZERO
		if absi(goal.x - cur.x) >= absi(goal.y - cur.y):
			step.x = signi(goal.x - cur.x)
		else:
			step.y = signi(goal.y - cur.y)
		var nxt: Vector2i = cur + step
		if pt._steer_floor(nxt) and not pt._prop_cell(nxt):
			cur = nxt
			continue
		var alt: Vector2i = Vector2i(step.y, step.x)
		if alt == Vector2i.ZERO:
			alt = Vector2i(signi(goal.x - cur.x), 0)
		if pt._steer_floor(cur + alt) and not pt._prop_cell(cur + alt):
			cur = cur + alt
			continue
		alt = Vector2i(-alt.x, -alt.y)
		if pt._steer_floor(cur + alt) and not pt._prop_cell(cur + alt):
			cur = cur + alt
			continue
		break
	return cur


static func astar(pt: Node, p: Node, dest: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty() or dest == null:
		return out
	var grid: PackedByteArray = dim.grid
	var w: int = dim.w
	var h: int = dim.h
	var start: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	var raw_goal: Vector2i = pt._stand_cell(p, dest)
	if not pt._steer_floor(start) or pt._prop_cell(start):
		for n: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if pt._steer_floor(start + n) and not pt._prop_cell(start + n):
				start += n
				break
	var goal: Vector2i = _toward(pt, start, raw_goal)
	if not pt._steer_floor(goal) or pt._prop_cell(goal):
		return out
	if start == goal:
		out.append(goal)
		return out
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var gscore: Dictionary = {}
	var fscore: Dictionary = {}
	gscore[start] = 0
	fscore[start] = start.distance_to(goal)
	var closed: Dictionary = {}
	var guard: int = 0
	var min_x: int = start.x - REACH - 1
	var max_x: int = start.x + REACH + 1
	var min_y: int = start.y - REACH - 1
	var max_y: int = start.y + REACH + 1
	while not open.is_empty() and guard < ASTAR_GUARD:
		guard += 1
		var best_i: int = 0
		var best_f: float = float(fscore.get(open[0], 1e9))
		for i: int in open.size():
			var f: float = float(fscore.get(open[i], 1e9))
			if f < best_f:
				best_f = f
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		if cur == goal:
			var step: Vector2i = cur
			var rev: Array[Vector2i] = []
			while step != start:
				rev.append(step)
				if not came.has(step):
					break
				step = came[step]
			rev.reverse()
			return rev
		closed[cur] = true
		for n2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + n2
			if nxt.x < min_x or nxt.x > max_x or nxt.y < min_y or nxt.y > max_y:
				continue
			if closed.has(nxt) or not pt._floor_cell(grid, w, h, nxt):
				continue
			var tg: int = int(gscore.get(cur, 0)) + 1
			if tg < int(gscore.get(nxt, 1 << 30)):
				came[nxt] = cur
				gscore[nxt] = tg
				fscore[nxt] = float(tg) + nxt.distance_to(goal)
				if open.find(nxt) < 0:
					open.append(nxt)
	return out
