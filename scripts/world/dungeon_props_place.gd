extends RefCounted

const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const Gate := preload("res://scripts/world/dungeon_gate.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")


static func place_n(host: Node, rooms: Array, n: int, what: String, eager: bool = true) -> void:
	var _fac = load("res://scripts/world/dungeon_props.gd")
	if n <= 0 or rooms.is_empty():
		return
	var pool: Array = _fac.shuffle_rooms(host, rooms)
	var placed := 0
	var attempts := 0
	var ri := 0
	var budget := n * maxi(8, pool.size() * 3)
	while placed < n and attempts < budget:
		attempts += 1
		var r: Dictionary = pool[ri % pool.size()]
		ri += 1
		var cell: Vector2i = host._free_cell(r)
		if not host._cell_clear(cell, 1) or host._near_spawn(cell):
			continue
		host._mark_cell(cell)
		if eager:
			commit_kind(host, what, cell)
		else:
			host.prop_jobs.append({"kind": what, "cell": cell, "state": "pending"})
		placed += 1


static func commit_kind(host: Node, what: String, cell: Vector2i) -> void:
	var pos: Vector3 = host._cell_pos(cell)
	if what == "mine":
		var node: Node = GatherS.new()
		node.setup("mine", pos)
		host.add_child(node)
		host._note("mine")
	elif what == "wood":
		var wood: Node = GatherS.new()
		wood.setup("wood", pos)
		host.add_child(wood)
		host._note("wood")
	elif what == "break":
		var br: Node = BreakS.new()
		br.setup("pot" if host.floor_rng.randf() < 0.6 else "barrel", pos)
		host.add_child(br)
		host._note("break")
	elif what == "campfire":
		var fire: Node = SpotS.new()
		fire.setup("campfire", pos)
		host.add_child(fire)
		host._note("campfire")
	elif what == "shrine":
		var sh: Node = SpotS.new()
		sh.setup("shrine", pos)
		host.add_child(sh)
		host._note("shrine")
	elif what == "quest_item":
		var q: Node = SpotS.new()
		q.setup("quest_item", pos)
		host.add_child(q)


static func spawn_puzzle(host: Node, r: Dictionary) -> void:
	var _fac = load("res://scripts/world/dungeon_props.gd")
	host._note("puzzle")
	var spots: Array[Vector2i] = _room_spots(host, r)
	var used: Array[Vector2i] = []
	var gate_c: Vector2i = _take_spot(host, spots)
	if not _valid_cell(gate_c):
		return
	used.append(gate_c)
	var gate: Node3D = SpotS.new()
	gate.setup("gate", host._cell_pos(gate_c))
	gate.pair = "puzzle"
	host.add_child(gate)
	host._note("gate")
	var act_c: Vector2i = _take_spot(host, spots)
	if _valid_cell(act_c):
		used.append(act_c)
		var use_plate: bool = host.floor_rng.randf() < 0.5
		var act: Node3D = SpotS.new()
		if use_plate:
			act.setup("plate", host._cell_pos(act_c))
			host._note("plate")
		else:
			act.setup("lever", host._cell_pos(act_c))
			host._note("lever")
		act.pair = "puzzle"
		host.add_child(act)
	var chest_c: Vector2i = _take_spot(host, spots)
	if _valid_cell(chest_c):
		used.append(chest_c)
		var chest: Node3D = SpotS.new()
		chest.setup("puzzle_chest", host._cell_pos(chest_c))
		host.add_child(chest)
		host._note("chest")
	var hid_c: Vector2i = _take_spot(host, spots)
	var crack_c: Vector2i = Vector2i(-999, -999)
	if _valid_cell(hid_c):
		crack_c = _take_adjacent(host, spots, hid_c)
		if not _valid_cell(crack_c):
			spots.append(hid_c)
		else:
			used.append(hid_c)
			used.append(crack_c)
			var hidden: Node3D = SpotS.new()
			hidden.setup("puzzle_chest", host._cell_pos(hid_c))
			hidden.hide_as_secret()
			host.add_child(hidden)
			var crack: Node3D = BreakS.new()
			crack.setup("crack", host._cell_pos(crack_c))
			crack.reveal = hidden
			host.add_child(crack)
			host._note("crack")
	for cell: Vector2i in used:
		host._mark_cell(cell)
	for extra: Vector2i in _fac.puzzle_cells(used):
		host._mark_cell(extra)


static func _room_spots(host: Node, r: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0: int = int(r.x)
	var y0: int = int(r.y)
	var x1: int = x0 + int(r.w)
	var y1: int = y0 + int(r.h)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var c := Vector2i(x, y)
			if host._cell_clear(c, 1) and not host._near_spawn(c):
				out.append(c)
	return out


static func _take_spot(host: Node, spots: Array[Vector2i]) -> Vector2i:
	if spots.is_empty():
		return Vector2i(-999, -999)
	var i: int = host.floor_rng.randi() % spots.size()
	var c: Vector2i = spots[i]
	spots.remove_at(i)
	return c


static func _take_adjacent(host: Node, spots: Array[Vector2i], origin: Vector2i) -> Vector2i:
	var hits: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP,
	]
	for d: Vector2i in dirs:
		var n: Vector2i = origin + d
		if spots.has(n):
			hits.append(n)
	if hits.is_empty():
		return Vector2i(-999, -999)
	var i: int = host.floor_rng.randi() % hits.size()
	var c: Vector2i = hits[i]
	spots.erase(c)
	return c


static func _valid_cell(c: Vector2i) -> bool:
	return c.x > -900 and c.y > -900
