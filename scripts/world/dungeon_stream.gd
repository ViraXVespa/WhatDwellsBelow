extends RefCounted

const Roster := preload("res://scripts/combat/roster.gd")
const GeoStream := preload("res://scripts/world/dungeon_geo_stream.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")
const Queue := preload("res://scripts/world/dungeon_stream_queue.gd")
const Act := preload("res://scripts/world/dungeon_stream_act.gd")

const STREAM_IN := 28
const STREAM_OUT := 42
const SPAWN_PER_TICK := 2
const SPAWN_BOOT := 6


static func queue_initial(host: Node, pool: PackedStringArray) -> void:
	Queue.queue_initial(host, pool)


static func queue_room(host: Node, r: Dictionary, pool: PackedStringArray) -> void:
	Queue.queue_room(host, r, pool)


static func queue_pool(host: Node, pool: PackedStringArray) -> void:
	Queue.queue_pool(host, pool)


static func queue_named(host: Node, pool: PackedStringArray) -> void:
	Queue.queue_named(host, pool)


static func queue_ambushes(host: Node, pool: PackedStringArray) -> void:
	Queue.queue_ambushes(host, pool)


static func new_job(host: Node, kind: String, cell: Vector2i, room: Dictionary, ids: PackedStringArray, named: bool, nname: String) -> Dictionary:
	return Queue.new_job(host, kind, cell, room, ids, named, nname)


static func job_anchor(job: Dictionary) -> Vector2i:
	return Act.job_anchor(job)


static func activate_job(host: Node, job: Dictionary) -> void:
	Act.activate_job(host, job)


static func sleep_job(host: Node, job: Dictionary) -> void:
	Act.sleep_job(host, job)


static func job_in_combat(host: Node, job: Dictionary) -> bool:
	return Act.job_in_combat(host, job)


static func tick(host: Node, delta: float) -> void:
	host.stream_t += delta
	if host.stream_t < 0.2 and delta < 0.9:
		return
	host.stream_t = 0.0
	if host.player == null:
		return
	if not bool(host.get_meta("ambush_q", false)):
		host.set_meta("ambush_q", true)
		var pool: PackedStringArray = Roster.floor_types(App.floor_n)
		Queue.queue_initial(host, pool)
		Queue.queue_ambushes(host, pool)
		var SpawnS: GDScript = load("res://scripts/world/dungeon_props_spawn.gd") as GDScript
		if host.prop_jobs.is_empty() and not bool(host.get_meta("props_scattered", false)):
			SpawnS.spawn_world(host)
	var pc: Vector2i = host._player_cell()
	var budget: int = SPAWN_BOOT if delta >= 0.9 else SPAWN_PER_TICK
	var spawned := 0
	for job in host.spawn_jobs:
		var st: String = str(job.state)
		if st == "cleared":
			continue
		var d: int = host._cell_manhattan(pc, Act.job_anchor(job))
		if st == "pending" and (host.stream_all or d <= STREAM_IN):
			if not host.stream_all and spawned >= budget:
				continue
			Act.activate_job(host, job)
			spawned += 1
		elif st == "live" and not host.stream_all and d >= STREAM_OUT and not Act.job_in_combat(host, job):
			Act.sleep_job(host, job)
	var PropS: GDScript = load("res://scripts/world/dungeon_props_spawn.gd") as GDScript
	PropS.tick(host, pc, budget)
	CrystalNet.place_extras(host)
	GeoStream.tick(host, delta)


static func force_all(host: Node) -> void:
	host.stream_all = true
	if not bool(host.get_meta("ambush_q", false)):
		host.set_meta("ambush_q", true)
		var pool: PackedStringArray = Roster.floor_types(App.floor_n)
		Queue.queue_initial(host, pool)
		Queue.queue_ambushes(host, pool)
	if host.prop_jobs.is_empty() and not bool(host.get_meta("props_scattered", false)):
		var SpawnS: GDScript = load("res://scripts/world/dungeon_props_spawn.gd") as GDScript
		SpawnS.spawn_world(host)
	for job in host.spawn_jobs:
		if str(job.state) == "pending":
			Act.activate_job(host, job)
	var PropS: GDScript = load("res://scripts/world/dungeon_props_spawn.gd") as GDScript
	PropS.flush(host)
	CrystalNet.place_extras(host)


static func activate_room(host: Node, r: Dictionary, pool: PackedStringArray) -> void:
	Queue.queue_room(host, r, pool)
	for job in host.spawn_jobs:
		if str(job.state) == "pending" and job.get("room", {}) == r:
			Act.activate_job(host, job)
