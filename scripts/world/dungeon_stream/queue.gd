extends RefCounted

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const CrystalNet := preload("res://scripts/world/crystal/net.gd")

static func queue_initial(host: Node, pool: PackedStringArray) -> void:
	for r in host.data.get("rooms", []):
		queue_room(host, r, pool)
	queue_pool(host, pool)
	queue_named(host, pool)
	queue_hall(host, pool)

static func queue_room(host: Node, r: Dictionary, pool: PackedStringArray) -> void:
	var kind: String = str(r.get("kind", "normal"))
	if kind == "spawn" or kind == "boss" or Gen.is_safe_kind(kind):
		return
	if host._near_spawn(host._center_room(r)):
		return
	if CrystalNet.blocks_spawn(host, host._center_room(r)):
		return
	if pool.is_empty():
		return
	var n: int = maxi(1, int(App.bal.room_pack))
	if kind == "base":
		n = maxi(2, int(App.bal.base_guards))
		var chest: Node = SpotS.new()
		var c := Vector2i(int(r.x) + int(int(r.w) / 2.0), int(r.y) + int(int(r.h) / 2.0))
		chest.setup("base_chest", Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5), false)
		host.add_child(chest)
	var ids := PackedStringArray()
	for i in n:
		ids.append(pool[host.floor_rng.randi() % pool.size()])
	host.spawn_jobs.append(new_job(host, "room", host._center_room(r), r, ids, false, ""))

static func queue_pool(host: Node, pool: PackedStringArray) -> void:
	var room: Dictionary = host._combat_room()
	if room.is_empty() or pool.is_empty():
		return
	if host._near_spawn(host._center_room(room)):
		return
	if CrystalNet.blocks_spawn(host, host._center_room(room)):
		return
	var ids := PackedStringArray()
	for id in pool:
		var have: bool = host.types_present.find(id) >= 0
		if not have:
			for job in host.spawn_jobs:
				if (job.ids as PackedStringArray).find(id) >= 0:
					have = true
					break
		if have:
			continue
		ids.append(id)
	if ids.is_empty():
		return
	host.spawn_jobs.append(new_job(host, "fill", host._center_room(room), room, ids, false, ""))

static func queue_named(host: Node, pool: PackedStringArray) -> void:
	var ntype := ""
	var nname := ""
	if App.quest_named_type != "":
		ntype = App.quest_named_type
		nname = App.quest_named_name
	else:
		var due: bool = App.floors_since_named + 1 >= int(App.bal.named_every)
		var roll: float = host.floor_rng.randf() < (1.0 / maxf(1.0, App.bal.named_every))
		if not due and not roll:
			App.floors_since_named += 1
			return
		ntype = pool[host.floor_rng.randi() % pool.size()] if not pool.is_empty() else "goblin"
		nname = Roster.make_name(host.floor_rng)
	App.floors_since_named = 0
	var room: Dictionary = host._combat_room()
	if room.is_empty():
		return
	host.last_named = nname
	var ids := PackedStringArray()
	ids.append(ntype)
	host.spawn_jobs.append(new_job(host, "named", host._center_room(room), room, ids, true, nname))

static func queue_ambushes(host: Node, pool: PackedStringArray) -> void:
	if pool.is_empty():
		return
	var spots: Array = host.data.get("ambushes", [])
	var cap := 40
	if App.bal:
		cap = maxi(1, int(App.bal.get("ambush_cap")))
	var max_spots: int = mini(cap, spots.size())
	var lo := 1
	var hi := 2
	if App.bal:
		lo = maxi(1, int(App.bal.get("ambush_pack_min")))
		hi = maxi(lo, int(App.bal.get("ambush_pack_max")))
	var placed := 0
	for si in spots.size():
		if placed >= max_spots:
			break
		var center := Vector2i(spots[si])
		if not host._is_floor_cell(center):
			continue
		if host._near_spawn(center):
			continue
		if CrystalNet.blocks_spawn(host, center):
			continue
		var n: int = host.floor_rng.randi_range(lo, hi)
		var ids := PackedStringArray()
		for i in n:
			ids.append(pool[host.floor_rng.randi() % pool.size()])
		host.spawn_jobs.append(new_job(host, "ambush", center, {}, ids, false, ""))
		placed += 1

static func _land(host: Node, cell: Vector2i) -> Vector2i:
	if host._is_floor_cell(cell):
		return cell
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for rad in range(1, 4):
		for d: Vector2i in dirs:
			var n: Vector2i = cell + d * rad
			if host._is_floor_cell(n):
				return n
	return cell

static func queue_hall(host: Node, pool: PackedStringArray) -> void:
	if pool.is_empty():
		return
	var grid: PackedByteArray = host.data.grid
	var w: int = int(host.data.w)
	var h: int = int(host.data.h)
	if w < 3 or h < 3 or grid.is_empty():
		return
	var roomish := PackedByteArray()
	roomish.resize(w * h)
	roomish.fill(0)
	for r in host.data.get("rooms", []):
		var x0 := int(r.x)
		var y0 := int(r.y)
		var x1 := x0 + int(r.w)
		var y1 := y0 + int(r.h)
		var yy := y0
		while yy < y1:
			if yy >= 0 and yy < h:
				var row := yy * w
				var xx := x0
				while xx < x1:
					if xx >= 0 and xx < w:
						roomish[row + xx] = 1
					xx += 1
			yy += 1
	var ambush := {}
	for spot in host.data.get("ambushes", []):
		ambush[Vector2i(spot)] = true
	var halls: Array[Vector2i] = []
	for y in range(1, h - 1):
		var row2 := y * w
		for x in range(1, w - 1):
			var i := row2 + x
			if grid[i] != Gen.FLOOR or roomish[i] != 0:
				continue
			var nbs := 0
			if grid[i + 1] == Gen.FLOOR:
				nbs += 1
			if grid[i - 1] == Gen.FLOOR:
				nbs += 1
			if grid[i + w] == Gen.FLOOR:
				nbs += 1
			if grid[i - w] == Gen.FLOOR:
				nbs += 1
			if nbs >= 2:
				halls.append(Vector2i(x, y))
	if halls.is_empty():
		return
	var seed_n := int(App.run_seed) * 17 + int(App.floor_n) * 31
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var placed: Array[Vector2i] = []
	for start in halls:
		var si := start.y * w + start.x
		if seen[si] != 0:
			continue
		var run: Array[Vector2i] = []
		var stack: Array[int] = [si]
		seen[si] = 1
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			var cy := int(float(cur) / float(w))
			var cx := cur - cy * w
			run.append(Vector2i(cx, cy))
			for d in dirs:
				var nx := cx + d.x
				var ny := cy + d.y
				if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
					continue
				var ni := ny * w + nx
				if seen[ni] != 0:
					continue
				if grid[ni] != Gen.FLOOR or roomish[ni] != 0:
					continue
				seen[ni] = 1
				stack.append(ni)
		if run.size() < 10:
			continue
		var step := 14 + int(abs(seed_n + run[0].x * 13 + run[0].y * 29)) % 5
		var phase := int(abs(seed_n + run[0].y * 7 + run[0].x)) % step
		var i2 := phase
		while i2 < run.size():
			var cell: Vector2i = run[i2]
			i2 += step
			if ambush.has(cell) or host._near_spawn(cell) or CrystalNet.blocks_spawn(host, cell):
				continue
			var crowded := false
			for prev in placed:
				if absi(prev.x - cell.x) + absi(prev.y - cell.y) < 10:
					crowded = true
					break
			if crowded:
				continue
			var ids := PackedStringArray()
			ids.append(pool[host.floor_rng.randi() % pool.size()])
			host.spawn_jobs.append(new_job(host, "hall", cell, {}, ids, false, ""))
			placed.append(cell)

static func new_job(host: Node, kind: String, cell: Vector2i, room: Dictionary, ids: PackedStringArray, named: bool, nname: String) -> Dictionary:
	var gid: int = host.next_group
	host.next_group = gid + 1
	var land: Vector2i = _land(host, cell)
	return {
		"kind": kind,
		"cell": land,
		"room": room,
		"ids": ids,
		"named": named,
		"nname": nname,
		"gid": gid,
		"live": [],
		"state": "pending",
	}
