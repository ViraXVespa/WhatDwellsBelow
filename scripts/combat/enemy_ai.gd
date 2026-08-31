extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const Threat := preload("res://scripts/combat/threat.gd")


static func tick(host: Node, delta: float) -> void:
	var player: Node = host._player() as Node
	if player == null:
		idle(host, delta)
		return
	var ppos: Vector3 = player.global_position
	var to_p := Vector2(ppos.x - host.global_position.x, ppos.z - host.global_position.z)
	var dist := to_p.length()
	var from_post := Vector2(host.global_position.x - host.post.x, host.global_position.z - host.post.z).length()
	var has_los := Combat.los(host.global_position, ppos, host.get_world_3d())
	if has_los:
		host.last_seen = ppos
		if to_p.length_squared() > 0.0001:
			host.aim = to_p.normalized()
	if host.state == host.ST_FLEE:
		do_flee(host, delta, to_p)
		return
	if host.state == host.ST_WIND or host.state == host.ST_STRIKE or host.state == host.ST_REC:
		do_attack(host, delta)
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
			begin_windup(host)
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
		var near_last := Vector2(host.last_seen.x - host.global_position.x, host.last_seen.z - host.global_position.z).length() < 0.4
		if near_last:
			host.state = host.ST_RETURN
		return
	idle(host, delta)


static func begin_windup(host: Node) -> void:
	host.state = host.ST_WIND
	host.wind_t = 0.0
	host.locked_aim = host.aim if host.aim.length_squared() > 0.0001 else Vector2.DOWN
	host.aim = host.locked_aim
	if host.role == "mage":
		host.wind_dur = App.bal.windup_mage
		var reach: float = host.atk_range * 0.55
		host.spec_point = host.global_position + Vector3(host.locked_aim.x, 0.0, host.locked_aim.y) * reach
		var player: Node = host._player() as Node
		if player:
			host.spec_point = player.global_position
	elif host.role == "ranged":
		host.wind_dur = App.bal.windup_ranged
	else:
		host.wind_dur = App.bal.windup_melee
	if host.is_boss and host.role == "melee":
		host.wind_dur += 0.12
	draw_tele(host, false)


static func do_attack(host: Node, delta: float) -> void:
	if host.state == host.ST_WIND:
		host.velocity = Vector3.ZERO
		host.wind_t += delta
		draw_tele(host, false)
		if host.wind_t >= host.wind_dur:
			host.state = host.ST_STRIKE
			host.wind_t = 0.0
			draw_tele(host, true)
			strike(host)
		return
	if host.state == host.ST_STRIKE:
		if host.role == "melee":
			move_dir(host, host.locked_aim, 2.35, delta)
		else:
			host.velocity = Vector3.ZERO
		host.wind_t += delta
		if host.wind_t >= 0.14:
			host.state = host.ST_REC
			host.rec_t = 0.0
			host.velocity = Vector3.ZERO
			if host.telegraph:
				host.telegraph.hide_now()
		return
	if host.state == host.ST_REC:
		host.velocity = Vector3.ZERO
		host.rec_t += delta
		if host.rec_t >= App.bal.enemy_recover:
			host.state = host.ST_CHASE
			if host.telegraph:
				host.telegraph.hide_now()


static func draw_tele(host: Node, active: bool) -> void:
	if host.telegraph == null:
		return
	var wind_col := Color(1.0, 0.82, 0.28, 0.42)
	var act_col := Color(1.0, 0.25, 0.18, 0.55)
	var col := act_col if active else wind_col
	if host.role == "mage" or (host.is_boss and host.type_id == "shaman"):
		col = Color(0.55, 0.35, 1.0, 0.5) if active else Color(0.7, 0.55, 1.0, 0.38)
		host.telegraph.show_circle(host.spec_point if host.role == "mage" else host.global_position, host.atk_range if host.is_boss and host.role == "mage" else 1.65, col)
		return
	if host.role == "ranged":
		col = Color(0.95, 0.55, 0.2, 0.5) if active else Color(1.0, 0.82, 0.28, 0.4)
		host.telegraph.show_arc(host.global_position, host.locked_aim, host.atk_range, maxf(12.0, host.arc_deg), col)
		return
	if host.is_boss and host.role == "melee":
		host.telegraph.show_circle(host.global_position, host.atk_range, col)
		return
	host.telegraph.show_arc(host.global_position, host.locked_aim, host.atk_range, host.arc_deg, col)


static func strike(host: Node) -> void:
	var player: Node = host._player() as Node
	if host.role == "ranged":
		var n := 3 if host.is_named else 1
		if host.is_named:
			var base := atan2(host.locked_aim.y, host.locked_aim.x)
			for i in n:
				var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
				var a := base + t * 0.28
				spawn_shot(host, Vector2(cos(a), sin(a)))
		else:
			spawn_shot(host, host.locked_aim)
		return
	if host.role == "mage":
		var rad := 1.85 if not host.is_named else 2.35
		if host.is_boss:
			rad = host.atk_range
		if player and Combat.in_circle(host.spec_point, rad, player.global_position):
			if Combat.los(host.spec_point, player.global_position, host.get_world_3d()):
				hit_player(host, player)
		if host.is_named or host.is_boss:
			spawn_shot(host, host.locked_aim)
			if host.is_boss:
				var base := atan2(host.locked_aim.y, host.locked_aim.x)
				spawn_shot(host, Vector2(cos(base + 0.4), sin(base + 0.4)))
				spawn_shot(host, Vector2(cos(base - 0.4), sin(base - 0.4)))
		return
	if player == null:
		return
	if host.is_boss:
		if Combat.in_circle(host.global_position, host.atk_range, player.global_position):
			hit_player(host, player)
		return
	if Combat.in_arc(host.global_position, host.locked_aim, host.atk_range, host.arc_deg, player.global_position):
		hit_player(host, player)
	if host.is_named and Combat.in_arc(host.global_position, host.locked_aim, host.atk_range * 1.1, host.arc_deg + 20.0, player.global_position):
		hit_player(host, player, 0.45)


static func hit_player(host: Node, player: Node, mult := 1.0) -> void:
	if player and player.has_method("take_hit"):
		player.take_hit(host.damage * mult * Threat.dealt_mult(host.combat_lv), host.locked_aim, false, host.kill_tag())


static func spawn_shot(host: Node, dir: Vector2) -> void:
	var p: Node3D = ProjS.new()
	var parent := host.get_parent()
	if parent:
		parent.add_child(p)
	else:
		host.add_child(p)
	var tex := "res://assets/fx/arrow.png"
	if host.role == "mage":
		tex = "res://assets/fx/lightning.png"
	p.setup(host.global_position, dir, App.bal.enemy_proj_speed, host.atk_range + 1.5, host.damage * Threat.dealt_mult(host.combat_lv), true, false, true, tex)
	p.source = host.kill_tag()


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
	var away := -to_p.normalized() if to_p.length_squared() > 0.0001 else Vector2.RIGHT
	host.aim = away
	move_dir(host, away, App.bal.flee_speed_mult, delta)
	if host.flee_t <= 0.0:
		host.bang.visible = false
		call_help(host)
		host.state = host.ST_CHASE


static func steer_to(host: Node, dest: Vector3, _delta: float) -> void:
	var d := Vector2(dest.x - host.global_position.x, dest.z - host.global_position.z)
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
		var a := randf() * TAU
		host.wander_dir = Vector2(cos(a), sin(a))
	var dest: Vector3 = host.post + Vector3(host.wander_dir.x, 0.0, host.wander_dir.y) * 0.7
	var d := Vector2(dest.x - host.global_position.x, dest.z - host.global_position.z)
	if d.length() > 0.12:
		steer_to(host, dest, delta)
	else:
		host.velocity = Vector3.ZERO


static func stuck(host: Node, delta: float) -> void:
	if host.state != host.ST_CHASE and host.state != host.ST_HUNT and host.state != host.ST_RETURN:
		host.stuck_t = 0.0
		host.last_pos = host.global_position
		return
	var step := Vector2(host.global_position.x - host.last_pos.x, host.global_position.z - host.last_pos.z).length()
	host.last_pos = host.global_position
	if step < 0.012:
		host.stuck_t += delta
		if host.stuck_t > 0.35:
			var side := Vector2(-host.aim.y, host.aim.x)
			if randf() < 0.5:
				side = - side
			host.velocity += Vector3(side.x, 0.0, side.y) * host.move_spd * 1.2
			host.stuck_t = 0.0
	else:
		host.stuck_t = 0.0


static func sep(host: Node) -> Vector3:
	var push := Vector3.ZERO
	var lim: float = App.bal.enemy_sep
	for e in Combat.enemies():
		if e == host or e == null or not is_instance_valid(e):
			continue
		var d: Vector3 = host.global_position - (e as Node3D).global_position
		d.y = 0.0
		var L := d.length()
		if L < lim and L > 0.01:
			push += d / L * (lim - L) * 2.4
	return push


static func call_help(host: Node) -> void:
	if host.spawned_help:
		return
	host.spawned_help = true
	var parent := host.get_parent()
	if parent and parent.has_method("spawn_reinforcement"):
		var n := int(App.bal.flee_help)
		for i in n:
			parent.spawn_reinforcement(host.type_id, host.global_position, host.group_id)


static func move_dir(host: Node, dir: Vector2, spd_m: float, delta: float) -> void:
	var push := sep(host)
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
