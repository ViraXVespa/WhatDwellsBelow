extends RefCounted

const CrystalNet := preload("res://scripts/world/crystal_net.gd")


static func job_anchor(job: Dictionary) -> Vector2i:
	return Vector2i(job.cell)


static func activate_job(host: Node, job: Dictionary) -> void:
	if str(job.state) != "pending":
		return
	if str(job.kind) == "boss":
		_activate_boss(host, job)
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
		var cell: Vector2i = job_anchor(job)
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
	if str(job.kind) == "boss" or str(job.kind) == "prop":
		return
	var remain := PackedStringArray()
	var live: Array = job.get("live", [])
	for raw in live:
		if raw == null or not is_instance_valid(raw):
			continue
		var e: Node = raw as Node
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
		var e: Node = raw as Node
		if e == null:
			continue
		kept.append(e)
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d: float = Vector2(e.global_position.x - host.player.global_position.x, e.global_position.z - host.player.global_position.z).length()
		if d < 8.0:
			close = true
	job.live = kept
	return close


static func _activate_boss(host: Node, job: Dictionary) -> void:
	var EnemyS: GDScript = load("res://scripts/combat/enemy.gd") as GDScript
	var boss: CharacterBody3D = EnemyS.new() as CharacterBody3D
	var bp: Vector2i = job_anchor(job)
	boss.position = Vector3(float(bp.x) + 0.5, 0.0, float(bp.y) + 0.5)
	host.add_child(boss)
	boss.setup_boss(str(job.nname), App.floor_n)
	boss.group_id = int(job.gid)
	job.live = [boss]
	job.state = "live"
	if App.boss_dead:
		host._on_boss_dead()
