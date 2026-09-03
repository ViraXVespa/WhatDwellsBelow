extends Object

const Threat := preload("res://scripts/combat/threat.gd")
const FloorCrystal := preload("res://scripts/world/floor_crystal.gd")


static func _num(key: String, fallback: int) -> int:
	if App.bal and App.bal.get(key) != null:
		return maxi(1, int(App.bal.get(key)))
	return fallback


static func _sep() -> int:
	return _num("crystal_min_sep", 56)


static func _deadend_sep() -> int:
	return _num("crystal_deadend_sep", 18)


static func _extra_max() -> int:
	return _num("crystal_extra_max", 4)


static func _place_chance() -> float:
	if App.bal and App.bal.get("crystal_place_chance") != null:
		return clampf(float(App.bal.get("crystal_place_chance")), 0.15, 1.0)
	return 0.62


static func cl_at(host: Node, cell: Vector2i) -> int:
	return Threat.level_at(App.floor_n, cell, host.travel_dist, int(host.data.w), host.travel_cap)


static func _far_enough(host: Node, cell: Vector2i, spots: Array, sep: int) -> bool:
	for s: Variant in spots:
		if host._cell_manhattan(cell, Vector2i(s.cell)) < sep:
			return false
	return true


static func place_floor(host: Node) -> void:
	var Net = load("res://scripts/world/crystal_net.gd")
	Net.ensure_run()
	Net.arrive()
	var spots: Array = []
	var spawn: Vector2i = host.data.spawn
	spots.append({"cell": spawn, "cl": cl_at(host, spawn), "gate": true})
	var by_cl: Dictionary = {}
	for r: Variant in host.data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if kind == "spawn" or kind == "boss" or kind == "extract_gate" or kind == "shop" or kind == "puzzle" or kind == "stash" or kind == "vein":
			continue
		var c: Vector2i = host._center_room(r)
		if not host._is_floor_cell(c):
			continue
		if host._cell_manhattan(c, spawn) < _sep():
			continue
		var cl: int = cl_at(host, c)
		var cur: Dictionary = by_cl.get(cl, {})
		if cur.is_empty() or host._cell_manhattan(c, spawn) > host._cell_manhattan(Vector2i(cur.cell), spawn):
			by_cl[cl] = {"cell": c, "cl": cl, "gate": false, "room": r}
	var bands: Array = by_cl.keys()
	bands.sort()
	for i in bands.size():
		var j: int = host.floor_rng.randi_range(i, bands.size() - 1)
		var tmp: Variant = bands[i]
		bands[i] = bands[j]
		bands[j] = tmp
	var extra := 0
	for clv: Variant in bands:
		if extra >= _extra_max():
			break
		var pick: Dictionary = by_cl[clv]
		if not _far_enough(host, Vector2i(pick.cell), spots, _sep()):
			continue
		if extra > 0 and host.floor_rng.randf() > _place_chance():
			continue
		spots.append(pick)
		extra += 1
	var dsep := _deadend_sep()
	for raw: Variant in host.data.get("deadends", []):
		var dc: Vector2i = Vector2i(raw)
		if not host._is_floor_cell(dc):
			continue
		if host._cell_manhattan(dc, spawn) < dsep:
			continue
		if not _far_enough(host, dc, spots, dsep):
			continue
		spots.append({"cell": dc, "cl": cl_at(host, dc), "gate": false})
	host.data["crystals"] = []
	for s: Variant in spots:
		var cell: Vector2i = s.cell
		if not s.gate:
			var room: Dictionary = s.get("room", {})
			if not room.is_empty():
				var free: Vector2i = host._free_cell(room, 1)
				if host._is_floor_cell(free):
					cell = free
		var node: Node = FloorCrystal.new()
		host.add_child(node)
		node.setup_crystal(host._cell_pos(cell), cell, int(s.cl), bool(s.gate))
		host._mark_cell(cell)
		host.data.crystals.append(cell)
		if bool(s.gate):
			host.data.crystal = cell
