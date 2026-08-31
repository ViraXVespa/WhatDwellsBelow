extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const Atk := preload("res://scripts/combat/enemy_atk.gd")


static func tick(host: Node, delta: float) -> void:
	var player: Node = host._player() as Node
	if player == null:
		idle(host, delta)
		return
	var ppos: Vector3 = player.global_position
	var to_p: Vector2 = Vector2(ppos.x - host.global_position.x, ppos.z - host.global_position.z)
	var dist: float = to_p.length()
	var from_post: float = Vector2(host.global_position.x - host.post.x, host.global_position.z - host.post.z).length()
	var has_los: bool = Combat.los(host.global_position, ppos, host.get_world_3d())
	if has_los:
		host.last_seen = ppos
		if to_p.length_squared() > 0.0001:
			host.aim = to_p.normalized()
	if host.state == host.ST_FLEE:
		do_flee(host, delta, to_p)
		return
	if host.state == host.ST_WIND or host.state == host.ST_STRIKE or host.state == host.ST_REC:
		Atk.do_attack(host, delta)
		return
	if from_post > App.bal.leash_range:
		host.state = host.ST_RETURN
		host.reaggro_t = App.bal.reaggro_cd
		steer_to(host, host.post, delta)
		return
	if host.state == host.ST_RETURN:
		if from_post < 0.45:
			host.state = host.ST_IDLE
			host.velocity = Vector3.ZERO
			return
		if has_los and dist < App.bal.aggro_range and from_post < App.bal.leash_range * 0.75 and host.reaggro_t <= 0.0:
			host.state = host.ST_CHASE
			return
		steer_to(host, host.post, delta)
		return
	if has_los and dist <= App.bal.aggro_range:
		if dist <= host.atk_range:
			Atk.begin_windup(host)
			return
		host.state = host.ST_CHASE
		host.hunt_t = App.bal.hunt_duration
		steer_to(host, ppos, delta)
		return
	if host.state == host.ST_CHASE or host.state == host.ST_HUNT:
		host.hunt_t -= delta
		host.state = host.ST_HUNT
		if host.hunt_t <= 0.0:
			host.state = host.ST_RETURN
			steer_to(host, host.post, delta)
			return
		steer_to(host, host.last_seen, delta)
		var near_last: bool = Vector2(host.last_seen.x - host.global_position.x, host.last_seen.z - host.global_position.z).length() < 0.4
		if near_last:
			host.state = host.ST_RETURN
		return
	idle(host, delta)


static func begin_windup(host: Node) -> void:
	Atk.begin_windup(host)


static func do_attack(host: Node, delta: float) -> void:
	Atk.do_attack(host, delta)


static func draw_tele(host: Node, active: bool) -> void:
	Atk.draw_tele(host, active)


static func strike(host: Node) -> void:
	Atk.strike(host)


static func hit_player(host: Node, player: Node, mult: float = 1.0) -> void:
	Atk.hit_player(host, player, mult)


static func spawn_shot(host: Node, dir: Vector2) -> void:
	Atk.spawn_shot(host, dir)


static func start_flee(host: Node) -> void:
	if host.dead or host.is_boss:
		return
	host.state = host.ST_FLEE
	host.flee_t = App.bal.flee_run_time
	host.spawned_help = false
	host.bang.visible = true
	if host.telegraph:
		host.telegraph.hide_now()
	call_help(host)


static func do_flee(host: Node, delta: float, to_p: Vector2) -> void:
	host.flee_t -= delta
	var away: Vector2 = - to_p.normalized() if to_p.length_squared() > 0.0001 else Vector2.RIGHT
	host.aim = away
	move_dir(host, away, App.bal.flee_speed_mult, delta)
	if host.flee_t <= 0.0:
		host.bang.visible = false
		call_help(host)
		host.state = host.ST_CHASE


static func steer_to(host: Node, dest: Vector3, _delta: float) -> void:
	var d: Vector2 = Vector2(dest.x - host.global_position.x, dest.z - host.global_position.z)
	if d.length_squared() < 0.0004:
		host.velocity = Vector3.ZERO
		return
	host.aim = d.normalized()
	move_dir(host, host.aim, 1.0, _delta)


static func idle(host: Node, delta: float) -> void:
	host.state = host.ST_IDLE
	host.idle_t -= delta
	if host.idle_t <= 0.0:
		host.idle_t = randf_range(0.8, 1.8)
		var a: float = randf() * TAU
		host.wander_dir = Vector2(cos(a), sin(a))
	var dest: Vector3 = host.post + Vector3(host.wander_dir.x, 0.0, host.wander_dir.y) * 0.7
	var d: Vector2 = Vector2(dest.x - host.global_position.x, dest.z - host.global_position.z)
	if d.length() > 0.12:
		steer_to(host, dest, delta)
	else:
		host.velocity = Vector3.ZERO


static func stuck(host: Node, delta: float) -> void:
	if host.state != host.ST_CHASE and host.state != host.ST_HUNT and host.state != host.ST_RETURN:
		host.stuck_t = 0.0
		host.last_pos = host.global_position
		return
	var step: float = Vector2(host.global_position.x - host.last_pos.x, host.global_position.z - host.last_pos.z).length()
	host.last_pos = host.global_position
	if step < 0.012:
		host.stuck_t += delta
		if host.stuck_t > 0.35:
			var side: Vector2 = Vector2(-host.aim.y, host.aim.x)
			if randf() < 0.5:
				side = - side
			host.velocity += Vector3(side.x, 0.0, side.y) * host.move_spd * 1.2
			host.stuck_t = 0.0
	else:
		host.stuck_t = 0.0


static func sep(host: Node) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var lim: float = App.bal.enemy_sep
	for e: Variant in Combat.enemies():
		if e == host or e == null or not is_instance_valid(e):
			continue
		var d: Vector3 = host.global_position - (e as Node3D).global_position
		d.y = 0.0
		var L: float = d.length()
		if L < lim and L > 0.01:
			push += d / L * (lim - L) * 2.4
	return push


static func call_help(host: Node) -> void:
	if host.spawned_help:
		return
	host.spawned_help = true
	var parent: Node = host.get_parent()
	if parent and parent.has_method("spawn_reinforcement"):
		var n: int = int(App.bal.flee_help)
		for i: int in n:
			parent.spawn_reinforcement(host.type_id, host.global_position, host.group_id)


static func move_dir(host: Node, dir: Vector2, spd_m: float, delta: float) -> void:
	var push: Vector3 = sep(host)
	var wish: Vector2 = dir.normalized() * host.move_spd * spd_m
	wish += Vector2(push.x, push.z)
	if host.move_kind == "hop":
		host.hop_t -= delta
		if host.hop_t <= 0.0:
			host.hop_t = 0.42
			host.velocity = Vector3(wish.x, 0.0, wish.y) * 1.35
		else:
			host.velocity = host.velocity.move_toward(Vector3.ZERO, host.move_spd * 3.0 * delta)
	else:
		host.velocity = Vector3(wish.x, 0.0, wish.y)
