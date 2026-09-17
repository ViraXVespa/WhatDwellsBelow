extends RefCounted

const Smoke := preload("res://scripts/debug/smoke.gd")

static func _place() -> GDScript:
	return load("res://scripts/world/dungeon_props_place.gd") as GDScript


static func _gate() -> GDScript:
	return load("res://scripts/world/dungeon_gate.gd") as GDScript


static func _spot() -> GDScript:
	return load("res://scripts/world/interact.gd") as GDScript


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
			_gate().place(host, r)
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
			_place().spawn_puzzle(host, pr)

static func _eager(host: Node) -> bool:
	return bool(host.stream_all) or Smoke.phase(5)


static func _queue(host: Node, kind: String, cell: Vector2i, room: Dictionary = {}) -> void:
	host.prop_jobs.append({"kind": kind, "cell": cell, "room": room, "state": "pending"})


static func spawn_world(host: Node) -> void:
	var eager: bool = _eager(host)
	host.counts.clear()
	host.prop_jobs.clear()
	host._seed_occupied()
	for r in host.data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if host._near_spawn(host._center_room(r)) and kind != "spawn":
			if kind == "vein" or kind == "shop":
				continue
		if kind == "extract_gate":
			if eager:
				_gate().place(host, r)
			else:
				_queue(host, "extract_gate", host._center_room(r), r)
		elif kind == "shop":
			var sc: Vector2i = host._free_cell(r)
			if not host._cell_clear(sc, 1):
				sc = host._center_room(r)
			host._mark_cell(sc)
			if eager:
				var SpotS: GDScript = _spot()
				var s: Node = SpotS.new()
				s.setup_shop(host._cell_pos(sc), host.floor_rng)
				host.add_child(s)
				host._note("shop")
			else:
				_queue(host, "shop", sc, r)
		elif kind == "stash":
			var st: Vector2i = host._center_room(r)
			host._mark_cell(st)
			if eager:
				var SpotS2: GDScript = _spot()
				var chest: Node = SpotS2.new()
				chest.setup("base_chest", host._cell_pos(st), false)
				host.add_child(chest)
				host._note("chest")
			else:
				_queue(host, "stash", st)
		elif kind == "vein":
			if eager:
				var Fac: GDScript = load("res://scripts/world/dungeon_props.gd") as GDScript
				Fac.spawn_vein(host, r)
			else:
				_queue(host, "vein", host._center_room(r), r)
		elif kind == "puzzle":
			if eager:
				_place().spawn_puzzle(host, r)
			else:
				_queue(host, "puzzle", host._center_room(r), r)
	if eager:
		var Fac2: GDScript = load("res://scripts/world/dungeon_props.gd") as GDScript
		Fac2.scatter_counts(host, true)
		ensure_world(host)
		host.set_meta("props_scattered", true)
	if str(App.prog.quest_active.get("kind", "")) == "fetch" and int(App.prog.quest_active.get("floor", 1)) == App.floor_n:
		var spawn_r: Dictionary = host._find_kind_room("normal")
		if spawn_r.is_empty():
			spawn_r = host._away_room()
		if not spawn_r.is_empty():
			var qc: Vector2i = host._free_cell_world(spawn_r)
			host._mark_cell(qc)
			if eager:
				var SpotS3: GDScript = _spot()
				var q: Node = SpotS3.new()
				q.setup("quest_item", host._cell_pos(qc))
				host.add_child(q)
			else:
				_queue(host, "quest_item", qc)


static func _queue_scatter(host: Node) -> void:
	var rooms: Array = []
	for r: Variant in host.data.get("rooms", []):
		var k: String = str(r.get("kind", "normal"))
		if k == "spawn" or k == "boss" or k == "extract_gate" or k == "shop" or k == "puzzle":
			continue
		if host._near_spawn(host._center_room(r)):
			continue
		if k == "normal" or k == "base":
			rooms.append(r)
	if rooms.is_empty():
		var fallback: Dictionary = host._away_room()
		if not fallback.is_empty():
			rooms.append(fallback)
	_queue_n(host, rooms, int(App.bal.mine_nodes), "mine")
	_queue_n(host, rooms, int(App.bal.wood_nodes), "wood")
	_queue_n(host, rooms, int(App.bal.break_count), "break")
	_queue_n(host, rooms, int(App.bal.campfire_count), "campfire")
	_queue_n(host, rooms, int(App.bal.shrine_count), "shrine")


static func _queue_n(host: Node, rooms: Array, n: int, what: String) -> void:
	if n <= 0 or rooms.is_empty():
		return
	var pool: Array = rooms.duplicate()
	var i: int = 0
	while i < pool.size():
		var j: int = host.floor_rng.randi_range(i, pool.size() - 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
		i += 1
	var placed: int = 0
	var attempts: int = 0
	var ri: int = 0
	var budget: int = n * maxi(8, pool.size() * 3)
	while placed < n and attempts < budget:
		attempts += 1
		var r: Dictionary = pool[ri % pool.size()]
		ri += 1
		var cell: Vector2i = host._free_cell(r)
		if not host._cell_clear(cell, 1) or host._near_spawn(cell):
			continue
		host._mark_cell(cell)
		_queue(host, what, cell)
		placed += 1


static func tick(host: Node, pc: Vector2i, budget: int) -> void:
	if not bool(host.get_meta("props_scattered", false)):
		host.set_meta("props_scattered", true)
		_queue_scatter(host)
	if budget <= 0:
		return
	var spawned: int = 0
	for job: Variant in host.prop_jobs:
		if spawned >= budget:
			break
		if str(job.state) != "pending":
			continue
		var d: int = host._cell_manhattan(pc, Vector2i(job.cell))
		if not host.stream_all and d > 28:
			continue
		commit(host, job)
		spawned += 1


static func flush(host: Node) -> void:
	if not bool(host.get_meta("props_scattered", false)):
		host.set_meta("props_scattered", true)
		_queue_scatter(host)
	for job: Variant in host.prop_jobs:
		if str(job.state) == "pending":
			commit(host, job)


static func commit(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	job.state = "live"
	var kind: String = str(job.kind)
	if kind == "extract_gate":
		_gate().place(host, job.room)
	elif kind == "puzzle":
		_place().spawn_puzzle(host, job.room)
	elif kind == "vein":
		var Fac: GDScript = load("res://scripts/world/dungeon_props.gd") as GDScript
		Fac.spawn_vein(host, job.room)
	elif kind == "shop":
		var SpotS: GDScript = _spot()
		var s: Node = SpotS.new()
		s.setup_shop(host._cell_pos(Vector2i(job.cell)), host.floor_rng)
		host.add_child(s)
		host._note("shop")
	elif kind == "stash":
		var SpotS2: GDScript = _spot()
		var chest: Node = SpotS2.new()
		chest.setup("base_chest", host._cell_pos(Vector2i(job.cell)), false)
		host.add_child(chest)
		host._note("chest")
	else:
		_place().commit_kind(host, kind, Vector2i(job.cell))
