extends Object

const Combat := preload("res://scripts/combat/combat.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")
const Threat := preload("res://scripts/combat/threat.gd")


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
			load("res://scripts/combat/enemy_ai.gd").move_dir(host, host.locked_aim, 2.35, delta)
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
	var wind_col: Color = Color(1.0, 0.82, 0.28, 0.42)
	var act_col: Color = Color(1.0, 0.25, 0.18, 0.55)
	var col: Color = act_col if active else wind_col
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
		var n: int = 3 if host.is_named else 1
		if host.is_named:
			var base: float = atan2(host.locked_aim.y, host.locked_aim.x)
			for i: int in n:
				var t: float = 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
				var a: float = base + t * 0.28
				spawn_shot(host, Vector2(cos(a), sin(a)))
		else:
			spawn_shot(host, host.locked_aim)
		return
	if host.role == "mage":
		var rad: float = 1.85 if not host.is_named else 2.35
		if host.is_boss:
			rad = host.atk_range
		if player and Combat.in_circle(host.spec_point, rad, player.global_position):
			if Combat.los(host.spec_point, player.global_position, host.get_world_3d()):
				hit_player(host, player)
		if host.is_named or host.is_boss:
			spawn_shot(host, host.locked_aim)
			if host.is_boss:
				var base2: float = atan2(host.locked_aim.y, host.locked_aim.x)
				spawn_shot(host, Vector2(cos(base2 + 0.4), sin(base2 + 0.4)))
				spawn_shot(host, Vector2(cos(base2 - 0.4), sin(base2 - 0.4)))
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


static func hit_player(host: Node, player: Node, mult: float = 1.0) -> void:
	if player and player.has_method("take_hit"):
		player.take_hit(host.damage * mult * Threat.dealt_mult(host.combat_lv), host.locked_aim, false, host.kill_tag())


static func spawn_shot(host: Node, dir: Vector2) -> void:
	var p: Node3D = ProjS.new()
	var parent: Node = host.get_parent()
	if parent:
		parent.add_child(p)
	else:
		host.add_child(p)
	var tex: String = "res://assets/fx/arrow.png"
	if host.role == "mage":
		tex = "res://assets/fx/lightning.png"
	p.setup(host.global_position, dir, App.bal.enemy_proj_speed, host.atk_range + 1.5, host.damage * Threat.dealt_mult(host.combat_lv), true, false, true, tex)
	p.source = host.kill_tag()
