extends Object

## Player physics tick.

const Depth := preload("res://scripts/world/depth.gd")
const PlayerAct := preload("res://scripts/world/player_act.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
const PlayerCombat := preload("res://scripts/world/player_combat.gd")
const PlayerHit := preload("res://scripts/combat/player_hit.gd")
const PlayerAnim := preload("res://scripts/world/player_anim.gd")


static func physics(host: CharacterBody3D, delta: float) -> void:
	if host.exiting:
		PlayerAct.tick_exit(host, delta)
		return
	PlayerAct.cooldowns(host, delta)
	if App.ui_open:
		host.ui_latch = true
		PlayerAct.stop_gather(host)
		host.atk_state = host.ATK_NONE
		host.dash_t = 0.0
		host.special_held = PlayerLock.ai_held(host, "special") or App.pad_held("special")
		host.velocity = Vector3.ZERO
		host.move_and_slide()
		host.global_position.y = 0.0
		if host.body:
			Depth.apply(host.body, host.global_position)
		PlayerAnim.apply_facing(host, delta)
		if host.telegraph:
			host.telegraph.hide_now()
		if host.rig and host.rig.has_method("follow"):
			host.rig.follow(host.global_position)
		return
	var close_block := false
	if host.ui_latch:
		host.ui_latch = false
		close_block = true
		host.interact_lock = maxf(host.interact_lock, 0.2)
		host.special_held = PlayerLock.ai_held(host, "special") or App.pad_held("special")
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
	var move := PlayerLock.ai_or_vec(host, "move")
	if host.gathering != null:
		PlayerAct.tick_gather(host, delta, move)
		if host.gathering != null:
			host.velocity = Vector3.ZERO
			host.move_and_slide()
			host.global_position.y = 0.0
			if host.body:
				Depth.apply(host.body, host.global_position)
			PlayerAnim.apply_facing(host, delta)
			if host.rig and host.rig.has_method("follow"):
				host.rig.follow(host.global_position)
			return
	if host.rig and host.rig.has_method("follow"):
		host.rig.follow(host.global_position)
	PlayerLock.lock_and_aim(host, move, delta)
	if not close_block:
		PlayerCombat.try_special(host)
		PlayerCombat.try_basic(host)
		PlayerCombat.try_dash(host, move)
	var spd: float = App.bal.move_speed * (1.0 + float(App.prog.set_stats().spd))
	if App.adrenaline:
		spd *= App.bal.adrenaline_speed
	if host.atk_state == host.ATK_BASIC:
		spd *= App.bal.attack_move_mult
	if host.atk_state == host.ATK_WIND or host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_REC:
		spd *= 0.2
	if host.dash_t > 0.0:
		var d := host.dash_dir if host.dash_dir.length_squared() > 0.0001 else (host.aim_dir if host.aim_dir.length_squared() > 0.0001 else Vector2.DOWN)
		host.velocity = Vector3(d.x, 0.0, d.y) * App.bal.move_speed * App.bal.dash_speed_mult
		if host.is_inside_tree():
			PlayerHit.trail(host, delta)
	else:
		host.velocity = Vector3(move.x, 0.0, move.y) * spd
	host.move_and_slide()
	host.global_position.y = 0.0
	if host.body:
		Depth.apply(host.body, host.global_position)
	PlayerCombat.advance_attack(host, delta)
	if host.hurt_flash > 0.0:
		host.hurt_flash -= delta
		if host.body:
			host.body.modulate = Color(1.5, 0.7, 0.7) if host.hurt_flash > 0.0 else Color.WHITE
	PlayerAnim.apply_facing(host, delta)
	PlayerCombat.update_aim_line(host)
	PlayerCombat.update_aura(host, delta)
	if host.rig and host.rig.has_method("follow"):
		host.rig.follow(host.global_position)
	PlayerAct.refresh_prompt(host)
	if not close_block:
		if PlayerLock.ai_just(host, "interact") or App.pad_just("interact") or Input.is_action_just_pressed("interact"):
			PlayerAct.try_interact(host)
		if PlayerLock.ai_just(host, "potion") or App.pad_just("potion"):
			App.prog.use_potion()
		if PlayerLock.ai_just(host, "food") or App.pad_just("food"):
			App.prog.use_food()