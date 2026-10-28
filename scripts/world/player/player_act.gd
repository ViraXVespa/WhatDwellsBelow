extends Object

const Dbg := preload("res://scripts/app/dbg.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")
const Near := preload("res://scripts/world/player/near_interact.gd")
const Ground := preload("res://scripts/world/player/ground.gd")

static func take_hit(host: Node, raw: float, from_dir: Vector2, crit: bool, src := "", hit_lv := -1) -> void:
	if host.hp <= 0.0 or host.exiting:
		return
	if host.iframe > 0.0:
		return
	if src != "":
		host.last_hit = src
	if int(hit_lv) >= 0:
		host.last_hit_lv = int(hit_lv)
		host.last_hit_lv_set = true
	else:
		host.last_hit_lv = -1
		host.last_hit_lv_set = false
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
	FloatS.spawn(host as Node3D, amount, crit, glance, 1.35)

static func player_die(host: Node) -> void:
	if Dbg.smoke_hold_player():
		host.hp = host.max_hp
		return
	if host.last_hit_lv_set and App.tel:
		App.tel.note_death_levels(int(host.last_hit_lv), App.prog.combat_lv())
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
	Ground.ground(host, Vector3.ZERO)
	host._apply_facing(delta)
	if host.body:
		host.body.modulate.a = clampf(1.0 - host.exit_t / 0.9, 0.12, 1.0)
	Ground.follow(host)
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
	var best: Node = Near.cached(host as Node3D, 1.35)
	App.interact_locked = false
	if best and best.get("prompt") != null:
		App.interact_prompt = str(best.prompt)
		App.interact_locked = best.get("prompt_locked") == true
	elif host.gathering:
		App.interact_prompt = App.tr("player_act.gathering")
	else:
		App.interact_prompt = ""

static func try_interact(host: Node) -> void:
	if App.ui_open or host.interact_lock > 0.0:
		return
	var best: Node = Near.nearest(host as Node3D, 1.25)
	if best and best.has_method("interact"):
		App.interact_locked = false
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
