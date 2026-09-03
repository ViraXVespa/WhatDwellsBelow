extends RefCounted

const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const Gate := preload("res://scripts/world/dungeon_gate.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")


static func spawn_world(host: Node) -> void:
	host.counts.clear()
	host._seed_occupied()
	for r in host.data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if host._near_spawn(host._center_room(r)) and kind != "spawn":
			if kind == "vein" or kind == "shop":
				continue
		if kind == "extract_gate":
			Gate.place(host, r)
		elif kind == "shop":
			var sc: Vector2i = host._free_cell(r)
			if not host._cell_clear(sc, 1):
				sc = host._center_room(r)
			var s := SpotS.new()
			s.setup_shop(host._cell_pos(sc), host.floor_rng)
			host.add_child(s)
			host._mark_cell(sc)
			host._note("shop")
		elif kind == "stash":
			var st: Vector2i = host._center_room(r)
			var chest := SpotS.new()
			chest.setup("base_chest", host._cell_pos(st), false)
			host.add_child(chest)
			host._mark_cell(st)
			host._note("chest")
		elif kind == "vein":
			spawn_vein(host, r)
		elif kind == "puzzle":
			spawn_puzzle(host, r)
	scatter_counts(host)
	ensure_world(host)
	if str(App.prog.quest_active.get("kind", "")) == "fetch" and int(App.prog.quest_active.get("floor", 1)) == App.floor_n:
		var spawn_r: Dictionary = host._find_kind_room("normal")
		if spawn_r.is_empty():
			spawn_r = host._away_room()
		if not spawn_r.is_empty():
			var qc: Vector2i = host._free_cell_world(spawn_r)
			var q := SpotS.new()
			q.setup("quest_item", host._cell_pos(qc))
			host.add_child(q)
			host._mark_cell(qc)


static func spawn_vein(host: Node, r: Dictionary) -> void:
	if host._near_spawn(host._center_room(r)):
		return
	var what := str(r.get("vein", ""))
	if what != "mine" and what != "wood" and what != "break":
		var roll: float = host.floor_rng.randf()
		if roll < 0.4:
			what = "wood"
		elif roll < 0.8:
			what = "mine"
		else:
			what = "break"
	var n := 7
	if what == "wood" or what == "break":
		n = 8
	place_n(host, [r], n, what)
	host._note("vein")


static func scatter_rooms(host: Node) -> Array:
	var out: Array = []
	for r in host.data.get("rooms", []):
		var k := str(r.get("kind", "normal"))
		if k == "spawn" or k == "boss" or k == "extract_gate" or k == "shop" or k == "puzzle":
			continue
		if host._near_spawn(host._center_room(r)):
			continue
		if k == "normal" or k == "base":
			out.append(r)
	if out.is_empty():
		var fallback: Dictionary = host._away_room()
		if not fallback.is_empty():
			out.append(fallback)
	return out


static func shuffle_rooms(host: Node, rooms: Array) -> Array:
	var pool: Array = rooms.duplicate()
	for i in pool.size():
		var j: int = host.floor_rng.randi_range(i, pool.size() - 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool


static func scatter_counts(host: Node) -> void:
	var rooms: Array = scatter_rooms(host)
	place_n(host, rooms, int(App.bal.mine_nodes), "mine")
	place_n(host, rooms, int(App.bal.wood_nodes), "wood")
	place_n(host, rooms, int(App.bal.break_count), "break")
	place_n(host, rooms, int(App.bal.campfire_count), "campfire")
	place_n(host, rooms, int(App.bal.shrine_count), "shrine")


static func place_n(host: Node, rooms: Array, n: int, what: String) -> void:
	if n <= 0 or rooms.is_empty():
		return
	var pool: Array = shuffle_rooms(host, rooms)
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


static func puzzle_cells(c: Vector2i) -> Array[Vector2i]:
	return [
		c,
		Vector2i(c.x + 2, c.y),
		Vector2i(c.x, c.y - 2),
		Vector2i(c.x, c.y - 3),
		Vector2i(c.x - 2, c.y),
		Vector2i(c.x - 1, c.y),
	]


static func spawn_puzzle(host: Node, r: Dictionary) -> void:
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
	for cell in puzzle_cells(c):
		host._mark_cell(cell)


static func place_one(host: Node, kind: String, prefer: Dictionary) -> Vector2i:
	var cell: Vector2i = host._free_cell_world(prefer)
	if host._near_spawn(cell):
		var away: Dictionary = host._away_room()
		if not away.is_empty():
			cell = host._free_cell(away)
	var pos: Vector3 = host._cell_pos(cell)
	if kind == "mine":
		var n := GatherS.new()
		n.setup("mine", pos)
		host.add_child(n)
		host._note("mine")
	elif kind == "wood":
		var w := GatherS.new()
		w.setup("wood", pos)
		host.add_child(w)
		host._note("wood")
	elif kind == "break":
		var b := BreakS.new()
		b.setup("pot", pos)
		host.add_child(b)
		host._note("break")
	elif kind == "campfire":
		var f := SpotS.new()
		f.setup("campfire", pos)
		host.add_child(f)
		host._note("campfire")
	elif kind == "shrine":
		var s := SpotS.new()
		s.setup("shrine", pos)
		host.add_child(s)
		host._note("shrine")
	elif kind == "shop":
		var sh := SpotS.new()
		sh.setup_shop(pos, host.floor_rng)
		host.add_child(sh)
		host._note("shop")
	host._mark_cell(cell)
	return cell


static func ensure_world(host: Node) -> void:
	var prefer: Dictionary = host._away_room()
	if prefer.is_empty():
		return
	if int(host.counts.get("mine", 0)) < 1:
		place_one(host, "mine", prefer)
	if int(host.counts.get("wood", 0)) < 1:
		place_one(host, "wood", prefer)
	if int(host.counts.get("break", 0)) < 1:
		place_one(host, "break", prefer)
	if int(host.counts.get("extract_gate", 0)) < 3:
		for r in host.data.get("rooms", []):
			if int(host.counts.get("extract_gate", 0)) >= 3:
				break
			if str(r.get("kind", "")) != "normal":
				continue
			if host._near_spawn(host._center_room(r)):
				continue
			if int(r.w) < 5 or int(r.y) < 1:
				continue
			Gate.place(host, r)
	if int(host.counts.get("campfire", 0)) < 1:
		place_one(host, "campfire", prefer)
	if int(host.counts.get("shrine", 0)) < 1:
		place_one(host, "shrine", prefer)
	if int(host.counts.get("shop", 0)) < 1 and Smoke.phase(5):
		place_one(host, "shop", prefer)
	if int(host.counts.get("puzzle", 0)) < 1:
		var pr := {}
		for r in host.data.get("rooms", []):
			var k := str(r.get("kind", ""))
			if k == "spawn" or k == "boss" or k == "extract_gate" or k == "shop" or k == "puzzle" or k == "stash" or k == "vein":
				continue
			if host._near_spawn(host._center_room(r)):
				continue
			var center: Vector2i = host._center_room(r)
			var blocked := false
			for cell in puzzle_cells(center):
				if host.occupied.has(cell):
					blocked = true
					break
			if not blocked:
				pr = r
				break
		if pr.is_empty():
			pr = host._find_kind_room("normal")
		if pr.is_empty():
			pr = host._find_kind_room("base")
		if not pr.is_empty() and str(pr.get("kind", "")) != "spawn" and str(pr.get("kind", "")) != "boss":
			spawn_puzzle(host, pr)
