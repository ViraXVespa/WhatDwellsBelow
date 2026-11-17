# Pathfinding utilities for PlaytestPath

const REACH := 36
const ASTAR_GUARD := 720
const CRUMB_CAP := 400
const SIDE_LEAVE := 4

static var _fog_frame: int = -1
static var _fog_w: int = 0
static var _fog_h: int = 0
static var _fog_v: PackedByteArray = PackedByteArray()
static var _fog_seen: Dictionary = {}

static func _manh(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func seek_unreached(pt: PlayHost, p: Node, dest: Node) -> bool:
	if dest == null or str(dest.name) != "CampaignSeekMark":
		return false
	var here: Vector2i = pt._cell_of_pos((p as Node3D).global_position)
	return here != pt._cell_of_node(dest)

static func _floor_step(pt: PlayHost, cell: Vector2i) -> bool:
	return pt._steer_floor(cell) and not pt._prop_cell(cell)

static func _toward(pt: PlayHost, start: Vector2i, goal: Vector2i) -> Vector2i:
	# Reachable floor cell inside the window that is closest to the goal. A straight
	# line into a wall is not a step.
	var best: Vector2i = start
	var best_d: int = _manh(start, goal)
	var q: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head: int = 0
	var guard: int = 0
	while head < q.size() and guard < ASTAR_GUARD:
		guard += 1
		var cur: Vector2i = q[head]
		head += 1
		if cur == goal and _floor_step(pt, cur):
			return goal
		var md: int = _manh(cur, goal)
		if _floor_step(pt, cur) and (md < best_d or (md == best_d and _manh(cur, start) < _manh(best, start))):
			best = cur
			best_d = md
		if _manh(cur, start) >= REACH:
			continue
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + n
			if seen.has(nxt) or not _floor_step(pt, nxt):
				continue
			seen[nxt] = true
			q.append(nxt)
	return best

static func _travel_axis(pt: PlayHost, start: Vector2i) -> Vector2i:
	if not pt.has_meta("trail") or not (pt.get_meta("trail") is Array):
		return Vector2i.ZERO
	var trail: Array = pt.get_meta("trail")
	var i: int = trail.size() - 2
	while i >= 0:
		var c: Variant = trail[i]
		if c is Vector2i and (c as Vector2i) != start:
			var prev: Vector2i = c as Vector2i
			var dx: int = start.x - prev.x
			var dy: int = start.y - prev.y
			if absi(dx) >= absi(dy) and dx != 0:
				return Vector2i(1 if dx > 0 else -1, 0)
			if dy != 0:
				return Vector2i(0, 1 if dy > 0 else -1)
			return Vector2i.ZERO
		i -= 1
	return Vector2i.ZERO

static func _fog_now(pt: PlayHost) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _fog_frame:
		return
	_fog_frame = frame
	var wh: Vector2i = _map_wh(pt)
	_fog_w = wh.x
	_fog_h = wh.y
	_fog_v = PackedByteArray()
	var dung: Node = pt._dungeon()
	if dung != null:
		var vis_v: Variant = dung.get("visited")
		if vis_v is PackedByteArray:
			_fog_v = vis_v as PackedByteArray
	_fog_seen = {}
	if pt.has_meta("seen_map"):
		var seen_v: Variant = pt.get_meta("seen_map")
		if seen_v is Dictionary:
			_fog_seen = seen_v as Dictionary

static func revealed(pt: PlayHost, cell: Vector2i) -> bool:
	_fog_now(pt)
	if _fog_w > 0 and _fog_h > 0 and cell.x >= 0 and cell.y >= 0 and cell.x < _fog_w and cell.y < _fog_h:
		var i: int = cell.y * _fog_w + cell.x
		if i >= 0 and i < _fog_v.size() and _fog_v[i] != 0:
			return true
	return _fog_seen.has(cell)

static func _map_wh(pt: PlayHost) -> Vector2i:
	var dim: Dictionary = pt._grid_dims()
	if dim.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(dim.w), int(dim.h))

static func _is_frontier(pt: PlayHost, cell: Vector2i) -> bool:
	if not _floor_step(pt, cell) or not revealed(pt, cell):
		return false
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = cell + n
		if _floor_step(pt, nb) and not revealed(pt, nb):
			return true
	return false

static func _seek_lock(pt: PlayHost) -> Vector2i:
	if not pt.has_meta("seek_goal"):
		return Vector2i(-999, -999)
	var v: Variant = pt.get_meta("seek_goal")
	if v is Vector2i:
		return v as Vector2i
	return Vector2i(-999, -999)

static func _meta_arr(pt: PlayHost, key: String) -> Array:
	if pt.has_meta(key) and pt.get_meta(key) is Array:
		return pt.get_meta(key)
	return []

static func _seek_banned(pt: PlayHost, cell: Vector2i) -> bool:
	return _meta_arr(pt, "seek_ban").has(cell)

static func _seek_ban(pt: PlayHost, cell: Vector2i) -> void:
	var bans: Array = _meta_arr(pt, "seek_ban")
	if bans.has(cell):
		return
	bans.append(cell)
	while bans.size() > 32:
		bans.pop_front()
	pt.set_meta("seek_ban", bans)

static func _crumb_note(pt: PlayHost, here: Vector2i) -> void:
	var crumb: Array = _meta_arr(pt, "crumb")
	if crumb.is_empty() or crumb[crumb.size() - 1] != here:
		crumb.append(here)
	while crumb.size() > CRUMB_CAP:
		crumb.pop_front()
	pt.set_meta("crumb", crumb)

static func _crumb_leave(pt: PlayHost, here: Vector2i) -> Vector2i:
	var crumb: Array = _meta_arr(pt, "crumb")
	var popped: bool = false
	while crumb.size() > 0:
		var tail: Variant = crumb[crumb.size() - 1]
		if not (tail is Vector2i):
			crumb.pop_back()
			popped = true
			continue
		var cell: Vector2i = tail as Vector2i
		if cell == here or _seek_banned(pt, cell):
			crumb.pop_back()
			popped = true
			continue
		break
	if crumb.is_empty():
		pt.set_meta("crumb", crumb)
		return here
	if popped:
		var extra: int = mini(5, crumb.size() - 1)
		var n: int = 0
		while n < extra:
			crumb.pop_back()
			n += 1
	var goal_v: Variant = crumb[crumb.size() - 1]
	pt.set_meta("crumb", crumb)
	if goal_v is Vector2i and _floor_step(pt, goal_v as Vector2i):
		return goal_v as Vector2i
	return here

static func _into_dark(pt: PlayHost, cell: Vector2i) -> Vector2i:
	var travel: Vector2i = _travel_axis(pt, cell)
	var fallback: Vector2i = cell
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = cell + n
		if not _floor_step(pt, nb) or revealed(pt, nb) or _seek_banned(pt, nb):
			continue
		if travel != Vector2i.ZERO and n == travel:
			return nb
		fallback = nb
	return fallback

static func frontier_goal(pt: PlayHost, start: Vector2i) -> Vector2i:
	var locked: Vector2i = _seek_lock(pt)
	if locked.x > -900 and locked != start and _floor_step(pt, locked) and not _seek_banned(pt, locked):
		if not revealed(pt, locked) and _manh(locked, start) > 1:
			pt.remove_meta("seek_goal")
		else:
			var cell_t: float = 0.0
			if pt.has_meta("cell_t"):
				cell_t = float(pt.get_meta("cell_t"))
			if cell_t < 2.0 or _manh(locked, start) > 2:
				var crumb: Array = _meta_arr(pt, "crumb")
				var leaving: bool = false
				if crumb.size() > 0:
					var tail: Variant = crumb[crumb.size() - 1]
					leaving = tail is Vector2i and (tail as Vector2i) == locked
				if not leaving:
					_crumb_note(pt, start)
				return locked
			_seek_ban(pt, locked)
	if _is_frontier(pt, start):
		var into: Vector2i = _into_dark(pt, start)
		if into != start:
			_crumb_note(pt, start)
			pt.set_meta("seek_goal", into)
			return into
	var travel: Vector2i = _travel_axis(pt, start)
	var best_fwd: Vector2i = start
	var best_fwd_d: int = -1
	var best_side: Vector2i = start
	var best_side_d: int = -1
	var q: Array[Vector2i] = [start]
	var walked: Dictionary = {start: true}
	var head: int = 0
	var guard: int = 0
	while head < q.size() and guard < ASTAR_GUARD:
		guard += 1
		var cur: Vector2i = q[head]
		head += 1
		var md: int = _manh(cur, start)
		if cur != start and _is_frontier(pt, cur) and not _seek_banned(pt, cur):
			var along: int = (cur.x - start.x) * travel.x + (cur.y - start.y) * travel.y
			if along > 0 and (best_fwd_d < 0 or md < best_fwd_d):
				best_fwd = cur
				best_fwd_d = md
			elif along == 0 and md >= SIDE_LEAVE and (best_side_d < 0 or md < best_side_d):
				best_side = cur
				best_side_d = md
		if md >= REACH:
			continue
		for n2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + n2
			if walked.has(nxt) or not _floor_step(pt, nxt):
				continue
			if not revealed(pt, nxt) and not _is_frontier(pt, nxt):
				continue
			walked[nxt] = true
			q.append(nxt)
	if best_fwd_d >= 0:
		_crumb_note(pt, start)
		pt.set_meta("seek_goal", best_fwd)
		return best_fwd
	if best_side_d >= 0:
		_crumb_note(pt, start)
		pt.set_meta("seek_goal", best_side)
		return best_side
	var back: Vector2i = _crumb_leave(pt, start)
	if back != start:
		pt.set_meta("seek_goal", back)
		return back
	if pt.has_meta("seek_goal"):
		pt.remove_meta("seek_goal")
	return start

static func opens_toward(pt: PlayHost, start: Vector2i, goal: Vector2i) -> bool:
	var step: Vector2i = _toward(pt, start, goal)
	if step == goal and _floor_step(pt, step):
		return true
	return _manh(step, goal) < _manh(start, goal)

static func astar(pt: PlayHost, p: Node, dest: Node, known_only: bool = false) -> Array[Vector2i]:
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
			if known_only and nxt != goal and not revealed(pt, nxt):
				continue
			var tg: int = int(gscore.get(cur, 0)) + 1
			if tg < int(gscore.get(nxt, 1 << 30)):
				came[nxt] = cur
				gscore[nxt] = tg
				fscore[nxt] = float(tg) + nxt.distance_to(goal)
				if open.find(nxt) < 0:
					open.append(nxt)
	return out
