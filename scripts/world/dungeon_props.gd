extends RefCounted

const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const Gate := preload("res://scripts/world/dungeon_gate.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const Spawn := preload("res://scripts/world/dungeon_props_spawn.gd")
const Place := preload("res://scripts/world/dungeon_props_place.gd")


static func spawn_world(host: Node) -> void:
	Spawn.spawn_world(host)

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
	Place.place_n(host, [r], n, what)
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
	Place.place_n(host, rooms, int(App.bal.mine_nodes), "mine")
	Place.place_n(host, rooms, int(App.bal.wood_nodes), "wood")
	Place.place_n(host, rooms, int(App.bal.break_count), "break")
	Place.place_n(host, rooms, int(App.bal.campfire_count), "campfire")
	Place.place_n(host, rooms, int(App.bal.shrine_count), "shrine")

static func place_n(host: Node, rooms: Array, n: int, what: String) -> void:
	Place.place_n(host, rooms, n, what)

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
	Place.spawn_puzzle(host, r)

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
	Spawn.ensure_world(host)
