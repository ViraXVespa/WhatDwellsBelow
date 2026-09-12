extends RefCounted

const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const Gate := preload("res://scripts/world/dungeon_gate.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")

static func place_n(host: Node, rooms: Array, n: int, what: String) -> void:
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
		var pos: Vector3 = host._cell_pos(cell)
		if what == "mine":
			var node := GatherS.new()
			node.setup("mine", pos)
			host.add_child(node)
			host._note("mine")
		elif what == "wood":
			var wood := GatherS.new()
			wood.setup("wood", pos)
			host.add_child(wood)
			host._note("wood")
		elif what == "break":
			var br := BreakS.new()
			br.setup("pot" if host.floor_rng.randf() < 0.6 else "barrel", pos)
			host.add_child(br)
			host._note("break")
		elif what == "campfire":
			var fire := SpotS.new()
			fire.setup("campfire", pos)
			host.add_child(fire)
			host._note("campfire")
		elif what == "shrine":
			var sh := SpotS.new()
			sh.setup("shrine", pos)
			host.add_child(sh)
			host._note("shrine")
		else:
			continue
		host._mark_cell(cell)
		placed += 1

static func spawn_puzzle(host: Node, r: Dictionary) -> void:
	var _fac = load("res://scripts/world/dungeon_props.gd")
	host._note("puzzle")
	var c: Vector2i = host._center_room(r)
	var plate := SpotS.new()
	plate.setup("plate", host._cell_pos(c))
	plate.pair = "puzzle"
	host.add_child(plate)
	host._note("plate")
	var lever := SpotS.new()
	lever.setup("lever", host._cell_pos(Vector2i(c.x + 2, c.y)))
	lever.pair = "puzzle"
	host.add_child(lever)
	host._note("lever")
	var gate := SpotS.new()
	gate.setup("gate", host._cell_pos(Vector2i(c.x, c.y - 2)))
	gate.pair = "puzzle"
	host.add_child(gate)
	host._note("gate")
	var chest := SpotS.new()
	chest.setup("puzzle_chest", host._cell_pos(Vector2i(c.x, c.y - 3)))
	host.add_child(chest)
	host._note("chest")
	var hidden := SpotS.new()
	hidden.setup("puzzle_chest", host._cell_pos(Vector2i(c.x - 2, c.y)))
	hidden.hide_as_secret()
	host.add_child(hidden)
	var crack := BreakS.new()
	crack.setup("crack", host._cell_pos(Vector2i(c.x - 1, c.y)))
	crack.reveal = hidden
	host.add_child(crack)
	host._note("crack")
	for cell in _fac.puzzle_cells(c):
		host._mark_cell(cell)
