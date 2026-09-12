extends RefCounted

const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const Gate := preload("res://scripts/world/dungeon_gate.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const Place := preload("res://scripts/world/dungeon_props_place.gd")

static func ensure_world(host: Node) -> void:
	var _fac = load("res://scripts/world/dungeon_props.gd")
	var prefer: Dictionary = host._away_room()
	if prefer.is_empty():
		return
	if int(host.counts.get("mine", 0)) < 1:
		_fac.place_one(host, "mine", prefer)
	if int(host.counts.get("wood", 0)) < 1:
		_fac.place_one(host, "wood", prefer)
	if int(host.counts.get("break", 0)) < 1:
		_fac.place_one(host, "break", prefer)
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
		_fac.place_one(host, "campfire", prefer)
	if int(host.counts.get("shrine", 0)) < 1:
		_fac.place_one(host, "shrine", prefer)
	if int(host.counts.get("shop", 0)) < 1 and Smoke.phase(5):
		_fac.place_one(host, "shop", prefer)
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
			for cell in _fac.puzzle_cells(center):
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
			Place.spawn_puzzle(host, pr)

static func spawn_world(host: Node) -> void:
	var _fac = load("res://scripts/world/dungeon_props.gd")
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
			_fac.spawn_vein(host, r)
		elif kind == "puzzle":
			Place.spawn_puzzle(host, r)
	_fac.scatter_counts(host)
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
