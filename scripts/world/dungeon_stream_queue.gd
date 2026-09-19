extends RefCounted

const Gen := preload("res://scripts/dungeon/gen.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")


static func queue_initial(host: Node, pool: PackedStringArray) -> void:
	for r in host.data.get("rooms", []):
		queue_room(host, r, pool)
	queue_pool(host, pool)
	queue_named(host, pool)


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
