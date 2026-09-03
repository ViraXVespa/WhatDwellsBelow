extends Object

const EnemyS := preload("res://scripts/combat/enemy.gd")
const Roster := preload("res://scripts/combat/roster.gd")


static func add_enemy(host: Node, id: String, pos: Vector3, gid: int, named: bool, nname: String) -> Node:
	var e = EnemyS.new()
	e.position = pos
	host.add_child(e)
	e.setup(id, App.floor_n, named, nname)
	e.group_id = gid
	if not host.groups.has(gid):
		host.groups[gid] = {"max_hp": 0.0, "hp": 0.0, "fled": false}
	host.groups[gid].max_hp += e.max_hp
	host.groups[gid].hp += e.max_hp
	if host.types_present.find(id) < 0:
		host.types_present.append(id)
	return e


static func note_enemy_hit(host: Node, e: Node, dmg: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	var gid: int = int(e.get("group_id"))
	if not host.groups.has(gid):
		return
	var g: Dictionary = host.groups[gid]
	g.hp = maxf(0.0, float(g.hp) - dmg)
	if g.fled:
		return
	if host.flee_used >= int(App.bal.flee_per_floor):
		return
	if float(g.hp) <= float(g.max_hp) * (1.0 - App.bal.flee_hp_frac):
		trigger_flee(host, gid)


static func trigger_flee(host: Node, gid: int) -> Node:
	if not host.groups.has(gid):
		return null
	if host.groups[gid].fled:
		return null
	var best: Node = null
	var best_spd := -1.0
	for n in host.get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n):
			continue
		if int(n.get("group_id")) != gid:
			continue
		if n.get("is_boss") == true:
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var spd := float(n.get("move_spd"))
		if spd > best_spd:
			best_spd = spd
			best = n
	if best and best.has_method("start_flee"):
		best.start_flee()
		host.groups[gid].fled = true
		host.flee_used += 1
	return best


static func spawn_reinforcement(host: Node, id: String, from: Vector3, gid: int) -> Node:
	var cell: Vector2i = host._walkable_near(Vector2i(int(from.x), int(from.z)), 3, false)
	if cell == Vector2i(-1, -1):
		return null
	return host._add_enemy(id, host._cell_pos(cell), gid, false, "")


static func _pressure_cap(host: Node) -> bool:
	if not host.has_meta("pressure_floor") or int(host.get_meta("pressure_floor")) != App.floor_n:
		host.set_meta("pressure_floor", App.floor_n)
		host.set_meta("pressure_waves_used", 0)
	var used := int(host.get_meta("pressure_waves_used"))
	var cap := 3
	if App.bal:
		cap = maxi(0, int(App.bal.get("pressure_waves")))
	return used < cap


static func _note_pressure_wave(host: Node) -> void:
	var used := int(host.get_meta("pressure_waves_used"))
	host.set_meta("pressure_waves_used", used + 1)


static func tick_pressure(host: Node, delta: float, grew: bool) -> void:
	if host.player == null:
		return
	host.pressure_cd_t = maxf(0.0, host.pressure_cd_t - delta)
	var moving: bool = host.player.velocity.length() > 0.25
	if moving:
		host.idle_t = 0.0
	else:
		host.idle_t += delta
	if grew:
		host.noreveal_t = 0.0
	else:
		host.noreveal_t += delta
	if host.pressure_cd_t > 0.0:
		return
	if host.is_safe_world(host.player.global_position):
		return
	if not _pressure_cap(host):
		return
	if host.idle_t >= App.bal.idle_timer or host.noreveal_t >= App.bal.noreveal_timer:
		pressure_spawn(host)
		host.idle_t = 0.0
		host.noreveal_t = 0.0
		host.pressure_cd_t = App.bal.pressure_cd


static func pressure_spawn(host: Node) -> int:
	if host.player and host.is_safe_world(host.player.global_position):
		return 0
	if not _pressure_cap(host):
		return 0
	var pool: PackedStringArray = Roster.floor_types(App.floor_n)
	if pool.is_empty():
		return 0
	var n := int(App.bal.pressure_count)
	var gid: int = host.next_group
	host.next_group += 1
	var spawned := 0
	var origin: Vector2i = Vector2i(int(host.player.global_position.x), int(host.player.global_position.z)) if host.player else Vector2i.ZERO
	for i in n:
		var cell: Vector2i = host._walkable_near(origin, int(App.bal.pressure_radius), false)
		if cell == Vector2i(-1, -1):
			continue
		var id := pool[host.floor_rng.randi() % pool.size()]
		host._add_enemy(id, host._cell_pos(cell), gid, false, "")
		spawned += 1
	if spawned > 0:
		_note_pressure_wave(host)
	return spawned
