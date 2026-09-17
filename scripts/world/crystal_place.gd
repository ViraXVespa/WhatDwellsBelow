extends Object
const RoomsPlace := preload("res://scripts/dungeon/gen_rooms_place.gd")

const Threat := preload("res://scripts/combat/threat.gd")
const FloorCrystal := preload("res://scripts/world/floor_crystal.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _num(key: String, fallback: int) -> int:
	if App.bal and App.bal.get(key) != null:
		return maxi(1, int(App.bal.get(key)))
	return fallback


static func _sep() -> int:
	return _num("crystal_min_sep", 56)


static func _deadend_sep() -> int:
	return _num("crystal_deadend_sep", 32)


static func _deadend_len() -> int:
	return _num("crystal_deadend_len", 28)


static func _extra_max() -> int:
	return _num("crystal_extra_max", 6)


static func _band_w() -> int:
	return _num("crystal_cl_band", 2)


static func _place_chance() -> float:
	if App.bal and App.bal.get("crystal_place_chance") != null:
		return clampf(float(App.bal.get("crystal_place_chance")), 0.15, 1.0)
	return 0.50


static func cl_at(host: Node, cell: Vector2i) -> int:
	return Threat.walk_level(App.floor_n, cell, host.travel_dist, int(host.data.w), host.travel_cap)


static func _walk(host: Node, cell: Vector2i) -> int:
	var grid_w: int = int(host.data.w)
	if grid_w <= 0:
		return 0
	var i: int = cell.y * grid_w + cell.x
	if i >= 0 and i < host.travel_dist.size() and host.travel_dist[i] >= 0:
		return int(host.travel_dist[i])
	return 0


static func _band_of(cl: int) -> int:
	var lo: int = Threat.floor_lo(App.floor_n)
	var span: int = _band_w()
	return maxi(0, int(float(cl - lo) / float(span)))


static func _band_target(band: int) -> int:
	var lo: int = Threat.floor_lo(App.floor_n)
	var span: int = _band_w()
	var mid: int = int(float(span - 1) / 2.0)
	return lo + band * span + mid


static func _far_enough(host: Node, cell: Vector2i, spots: Array, sep: int) -> bool:
	for s: Variant in spots:
		if host._cell_manhattan(cell, Vector2i(s.cell)) < sep:
			return false
	return true


static func _in_room(r: Dictionary, cell: Vector2i) -> bool:
	return RoomsPlace.in_room(r, cell)


static func _room_exits(host: Node, r: Dictionary) -> int:
	var seen: Dictionary = {}
	var n: int = 0
	var rx: int = int(r.x)
	var ry: int = int(r.y)
	var rw: int = int(r.w)
	var rh: int = int(r.h)
	for y: int in range(ry, ry + rh):
		for x: int in range(rx, rx + rw):
			var cell := Vector2i(x, y)
			if not host._is_floor_cell(cell):
				continue
			for d: Vector2i in DIRS:
				var other: Vector2i = cell + d
				if _in_room(r, other):
					continue
				if not host._is_floor_cell(other):
					continue
				if seen.has(other):
					continue
				seen[other] = true
				n += 1
	return n


static func _hub_rooms(host: Node) -> Array:
	var out: Array = []
	for r: Variant in host.data.get("rooms", []):
		if _room_exits(host, r) >= 2:
			out.append(r)
	return out


static func _hub_cells(host: Node, hubs: Array) -> Dictionary:
	var cells: Dictionary = {}
	for r: Variant in hubs:
		var rx: int = int(r.x)
		var ry: int = int(r.y)
		var rw: int = int(r.w)
		var rh: int = int(r.h)
		for y: int in range(ry, ry + rh):
			for x: int in range(rx, rx + rw):
				var cell := Vector2i(x, y)
				if host._is_floor_cell(cell):
					cells[cell] = true
	return cells


static func _spur_long_enough(host: Node, start: Vector2i, hub_cells: Dictionary, min_len: int) -> bool:
	if hub_cells.has(start):
		return false
	var dist: Dictionary = {start: 0}
	var q: Array[Vector2i] = [start]
	var qi: int = 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		var steps: int = int(dist[cur])
		for d: Vector2i in DIRS:
			var nxt: Vector2i = cur + d
			if dist.has(nxt):
				continue
			if not host._is_floor_cell(nxt):
				continue
			if hub_cells.has(nxt):
				return (steps + 1) >= min_len
			var nxt_steps: int = steps + 1
			if nxt_steps >= min_len:
				return true
			dist[nxt] = nxt_steps
			q.append(nxt)
	return false


static func _snap_cell(host: Node, pick: Dictionary) -> Vector2i:
	var cell: Vector2i = Vector2i(pick.cell)
	if bool(pick.get("gate", false)):
		return cell
	var room: Dictionary = pick.get("room", {})
	if room.is_empty():
		return cell
	var free: Vector2i = host._free_cell(room, 1)
	if host._is_floor_cell(free):
		return free
	return cell


static func _try_add(host: Node, spots: Array, pick: Dictionary, sep: int) -> bool:
	var cell: Vector2i = _snap_cell(host, pick)
	if not host._is_floor_cell(cell):
		return false
	if not _far_enough(host, cell, spots, sep):
		return false
	spots.append({
		"cell": cell,
		"cl": cl_at(host, cell),
		"gate": bool(pick.get("gate", false)),
	})
	return true


static func place_floor(host: Node) -> void:
	place_entrance(host)
	place_extras(host)


static func place_entrance(host: Node) -> void:
	var Net = load("res://scripts/world/crystal_net.gd")
	Net.ensure_run()
	Net.arrive()
	var spots: Array = []
	var spawn: Vector2i = host.data.spawn
	_try_add(host, spots, {"cell": spawn, "cl": cl_at(host, spawn), "gate": true}, _sep())
	_spawn_spots(host, spots, true)


static func place_extras(host: Node) -> void:
	if bool(host.get_meta("crystal_extras", false)):
		return
	host.set_meta("crystal_extras", true)
	var spots: Array = []
	var spawn: Vector2i = host.data.spawn
	for raw: Variant in host.data.get("crystals", []):
		spots.append({"cell": Vector2i(raw), "cl": 1, "gate": false})
	var by_band: Dictionary = {}
	for r: Variant in host.data.get("rooms", []):
		var kind: String = str(r.get("kind", "normal"))
		if kind == "spawn" or kind == "boss" or kind == "extract_gate" or kind == "shop" or kind == "puzzle" or kind == "stash" or kind == "vein":
			continue
		var c: Vector2i = host._center_room(r)
		if not host._is_floor_cell(c):
			continue
		if host._cell_manhattan(c, spawn) < _sep():
			continue
		var cl: int = cl_at(host, c)
		var band: int = _band_of(cl)
		if band <= 0:
			continue
		var cand: Dictionary = {"cell": c, "cl": cl, "gate": false, "room": r}
		var cur: Dictionary = by_band.get(band, {})
		if cur.is_empty() or _better_band(host, cand, cur, _band_target(band)):
			by_band[band] = cand
	var bands: Array = by_band.keys()
	bands.sort()
	var extra: int = 0
	for band_v: Variant in bands:
		if extra >= _extra_max():
			break
		var pick: Dictionary = by_band[band_v]
		if extra > 0 and host.floor_rng.randf() > _place_chance():
			continue
		if _try_add(host, spots, pick, _sep()):
			extra += 1
	var hubs: Array = _hub_rooms(host)
	var hub_cells: Dictionary = _hub_cells(host, hubs)
	var min_spur: int = _deadend_len()
	var dsep: int = _deadend_sep()
	var sep: int = _sep()
	for raw: Variant in host.data.get("deadends", []):
		var dc: Vector2i = Vector2i(raw)
		if not host._is_floor_cell(dc):
			continue
		if host._cell_manhattan(dc, spawn) < dsep:
			continue
		if not _spur_long_enough(host, dc, hub_cells, min_spur):
			continue
		_try_add(host, spots, {"cell": dc, "cl": cl_at(host, dc), "gate": false}, sep)
	_spawn_spots(host, spots, false)


static func _spawn_spots(host: Node, spots: Array, reset: bool) -> void:
	if reset or not (host.data.get("crystals", []) is Array):
		host.data["crystals"] = []
	var have: Dictionary = {}
	for raw: Variant in host.data.crystals:
		have[Vector2i(raw)] = true
	for s: Variant in spots:
		var cell: Vector2i = Vector2i(s.cell)
		if have.has(cell):
			continue
		var node: Node = FloorCrystal.new()
		host.add_child(node)
		node.setup_crystal(host._cell_pos(cell), cell, int(s.cl), bool(s.gate))
		host._mark_cell(cell)
		host.data.crystals.append(cell)
		have[cell] = true
		if bool(s.gate):
			host.data.crystal = cell


static func _better_band(host: Node, cand: Dictionary, cur: Dictionary, target_cl: int) -> bool:
	var d_new: int = absi(int(cand.cl) - target_cl)
	var d_old: int = absi(int(cur.cl) - target_cl)
	if d_new != d_old:
		return d_new < d_old
	return _walk(host, Vector2i(cand.cell)) > _walk(host, Vector2i(cur.cell))
