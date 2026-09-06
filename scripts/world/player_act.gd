extends Object

const Depth := preload("res://scripts/world/depth.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")


static func take_hit(host: Node, raw: float, from_dir: Vector2, crit: bool, src := "") -> void:
	if host.hp <= 0.0 or host.exiting:
		return
	if host.iframe > 0.0:
		return
	if src != "":
		host.last_hit = src
	var dmg: float = App.bal.apply_defense(raw, App.prog.gear_def() + App.prog.skill_def())
	if crit:
		dmg *= App.bal.crit_mult
	host.hp = maxf(0.0, host.hp - dmg)
	host.iframe = App.bal.player_hurt_iframe
	host.hurt_flash = 0.12
	host.velocity += Vector3(from_dir.x, 0.0, from_dir.y) * App.bal.knockback * 0.45
	App.sfx("hurt")
	stop_gather(host)
	var glance := false
	if host.get("last_glance") != null:
		glance = bool(host.get("last_glance"))
		host.set("last_glance", false)
	_float(host, int(round(dmg)), crit, glance and not crit)
	if App.tel:
		App.tel.note_damage_taken(dmg, host.hp, host.max_hp)
	App.prog.add_run_xp("def", App.bal.xp_def_hit)
	if host.hp <= 0.0:
		player_die(host)


static func _float(host: Node, amount: int, crit: bool, glance: bool) -> void:
	var n: Label3D = FloatS.new()
	n.setup(amount, crit, glance)
	n.position = host.global_position + Vector3(0.0, 1.35, 0.0)
	var world := host.get_parent()
	if world:
		world.add_child(n)
	else:
		host.add_child(n)


static func player_die(host: Node) -> void:
	if Smoke.hold_player():
		host.hp = host.max_hp
		return
	play_exit(host, "death", host.last_hit)


static func heal(host: Node, amount: float) -> void:
	if amount > 0.0 and host.hp < host.max_hp:
		App.prog.add_run_xp("hp", App.bal.xp_hp_heal)
	host.hp = minf(host.max_hp, host.hp + amount)


static func play_exit(host: Node, cond: String, killer := "") -> void:
	if host.exiting:
		return
	host.exiting = true
	host.exit_t = 0.0
	host.exit_cond = cond
	host.exit_killer = killer
	stop_gather(host)
	host.dash_t = 0.0
	host.atk_state = host.ATK_NONE
	host.iframe = 99.0
	host.lock_target = null
	host.lock_armed = false
	if cond == "death":
		host.hp = 0.0


static func tick_exit(host: Node, delta: float) -> void:
	host.exit_t += delta
	host.velocity = Vector3.ZERO
	host.move_and_slide()
	host.global_position.y = 0.0
	host._apply_facing(delta)
	if host.body:
		Depth.apply(host.body, host.global_position)
		host.body.modulate.a = clampf(1.0 - host.exit_t / 0.9, 0.12, 1.0)
	if host.rig and host.rig.has_method("follow"):
		host.rig.follow(host.global_position)
	if host.exit_t >= 0.9:
		host.exiting = false
		App.finish_end(host.exit_cond, host.exit_killer)


static func start_gather(host: Node, node: Node) -> void:
	if host.exiting:
		return
	if node == null or not is_instance_valid(node):
		return
	host.gathering = node
	host.gather_t = 0.0
	host.atk_state = host.ATK_NONE
	var p: Vector3 = (node as Node3D).global_position
	var d := Vector2(p.x - host.global_position.x, p.z - host.global_position.z)
	if d.length() > 0.001:
		host.aim_dir = d.normalized()


static func stop_gather(host: Node) -> void:
	host.gathering = null
	host.gather_t = 0.0


static func tick_gather(host: Node, delta: float, move: Vector2) -> void:
	if host.gathering == null or not is_instance_valid(host.gathering):
		stop_gather(host)
		return
	if move.length() > 0.22 or Input.is_action_just_pressed("dash") or Input.is_action_pressed("attack") or Input.is_action_just_pressed("special"):
		stop_gather(host)
		return
	host.gather_t += delta
	if App.tel:
		App.tel.gather_t += delta
	var wait := 2.4
	if host.gathering.get("interval") != null:
		wait = float(host.gathering.interval)
	if host.gather_t >= wait:
		host.gather_t = 0.0
		if host.gathering.has_method("strike"):
			var r: Dictionary = host.gathering.strike()
			if r.get("done", false):
				stop_gather(host)


static func refresh_prompt(host: Node) -> void:
	if App.ui_open:
		return
	var best: Node = null
	var best_d := 1.35
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var d := Vector2((n as Node3D).global_position.x - host.global_position.x, (n as Node3D).global_position.z - host.global_position.z).length()
			if d < best_d:
				best_d = d
				best = n
	if best and best.get("prompt") != null:
		App.interact_prompt = str(best.prompt)
	elif host.gathering:
		App.interact_prompt = "Gathering…"
	else:
		App.interact_prompt = ""


static func try_interact(host: Node) -> void:
	if App.ui_open or host.interact_lock > 0.0:
		return
	var best: Node = null
	var best_d := 1.25
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var d := Vector2((n as Node3D).global_position.x - host.global_position.x, (n as Node3D).global_position.z - host.global_position.z).length()
			if d < best_d:
				best_d = d
				best = n
	if best and best.has_method("interact"):
		var msg: String = str(best.interact(host))
		App.interact_prompt = msg
	else:
		App.interact_prompt = ""


static func cooldowns(host: Node, delta: float) -> void:
	host.dash_cd = maxf(0.0, host.dash_cd - delta)
	host.iframe = maxf(0.0, host.iframe - delta)
	host.interact_lock = maxf(0.0, host.interact_lock - delta)
	if host.dash_t > 0.0:
		host.dash_t = maxf(0.0, host.dash_t - delta)
		host.iframe = maxf(host.iframe, host.dash_t)
