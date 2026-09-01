extends RefCounted

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const GeoStream := preload("res://scripts/world/dungeon_geo_stream.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")

const STREAM_IN := 28
const STREAM_OUT := 42


static func queue_initial(host: Node, pool: PackedStringArray) -> void:
	for r in host.data.get("rooms", []):
		queue_room(host, r, pool)
	queue_pool(host, pool)
	queue_named(host, pool)


static func queue_room(host: Node, r: Dictionary, pool: PackedStringArray) -> void:
	var kind := str(r.get("kind", "normal"))
	if kind == "spawn" or kind == "boss" or Gen.is_safe_kind(kind):
		return
	if host._near_spawn(host._center_room(r)):
		return
	if CrystalNet.blocks_spawn(host, host._center_room(r)):
		return
	if pool.is_empty():
		return
	var n := mini(2, maxi(1, int(App.bal.room_pack)))
	if kind == "base":
		n = mini(3, maxi(2, int(App.bal.base_guards)))
		var chest = SpotS.new()
		var c := Vector2i(int(r.x) + int(r.w) / 2, int(r.y) + int(r.h) / 2)
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
		var due := App.floors_since_named + 1 >= int(App.bal.named_every)
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
	var max_spots := mini(12, spots.size())
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
		var n: int = host.floor_rng.randi_range(1, 2)
		var ids := PackedStringArray()
		for i in n:
			ids.append(pool[host.floor_rng.randi() % pool.size()])
		host.spawn_jobs.append(new_job(host, "ambush", center, {}, ids, false, ""))
		placed += 1


static func new_job(host: Node, kind: String, cell: Vector2i, room: Dictionary, ids: PackedStringArray, named: bool, nname: String) -> Dictionary:
	var gid: int = host.next_group
	host.next_group = gid + 1
	return {
		"kind": kind,
		"cell": cell,
		"room": room,
		"ids": ids,
		"named": named,
		"nname": nname,
		"gid": gid,
		"live": [],
		"state": "pending",
	}


static func job_anchor(job: Dictionary) -> Vector2i:
	return Vector2i(job.cell)


static func activate_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	if host._near_spawn(job_anchor(job), 8) or CrystalNet.blocks_spawn(host, job_anchor(job)):
		job.state = "cleared"
		return
	var ids: PackedStringArray = job.ids
	if ids.is_empty():
		job.state = "cleared"
		return
	var live: Array = []
	var room: Dictionary = job.get("room", {})
	for i in ids.size():
		var cell := job_anchor(job)
		if not room.is_empty():
			cell = host._rand_cell(room)
		elif i > 0:
			var near: Vector2i = host._walkable_near(job_anchor(job), 2, false)
			if near != Vector2i(-1, -1):
				cell = near
		if host._near_spawn(cell, 8) or CrystalNet.blocks_spawn(host, cell):
			continue
		var e: Node = host._add_enemy(ids[i], host._cell_pos(cell), int(job.gid), bool(job.named), str(job.nname))
		if e and bool(job.named):
			e.add_to_group("named")
		live.append(e)
	job.live = live
	job.state = "live" if not live.is_empty() else "cleared"


static func sleep_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "live":
		return
	var remain := PackedStringArray()
	var live: Array = job.get("live", [])
	for raw in live:
		if raw == null or not is_instance_valid(raw):
			continue
		var e := raw as Node
		if e == null:
			continue
		var alive := true
		if e.has_method("is_alive"):
			alive = e.is_alive()
		if alive:
			remain.append(str(e.get("type_id")))
		e.queue_free()
	job.live = []
	if host.groups.has(int(job.gid)):
		host.groups.erase(int(job.gid))
	if remain.is_empty():
		job.state = "cleared"
		job.ids = PackedStringArray()
		return
	job.ids = remain
	job.gid = host.next_group
	host.next_group += 1
	job.state = "pending"


static func job_in_combat(host: Node, job: Dictionary) -> bool:
	if host.player == null:
		return false
	var live: Array = job.get("live", [])
	var kept: Array = []
	var close := false
	for raw in live:
		if raw == null or not is_instance_valid(raw):
			continue
		var e := raw as Node
		if e == null:
			continue
		kept.append(e)
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - host.player.global_position.x, e.global_position.z - host.player.global_position.z).length()
		if d < 8.0:
			close = true
	job.live = kept
	return close


static func tick(host: Node, delta: float) -> void:
	host.stream_t += delta
	if host.stream_t < 0.2 and delta < 0.9:
		return
	host.stream_t = 0.0
	if host.player == null:
		return
	var pc: Vector2i = host._player_cell()
	for job in host.spawn_jobs:
		var st := str(job.state)
		if st == "cleared":
			continue
		var d: int = host._cell_manhattan(pc, job_anchor(job))
		if st == "pending" and (host.stream_all or d <= STREAM_IN):
			activate_job(host, job)
		elif st == "live" and not host.stream_all and d >= STREAM_OUT and not job_in_combat(host, job):
			sleep_job(host, job)
	GeoStream.tick(host, delta)


static func force_all(host: Node) -> void:
	host.stream_all = true
	for job in host.spawn_jobs:
		if str(job.state) == "pending":
			activate_job(host, job)


static func activate_room(host: Node, r: Dictionary, pool: PackedStringArray) -> void:
	queue_room(host, r, pool)
	for job in host.spawn_jobs:
		if str(job.state) == "pending" and job.get("room", {}) == r:
			activate_job(host, job)
