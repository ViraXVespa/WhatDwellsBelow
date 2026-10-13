extends Object

## Player physics tick.

const Ground := preload("res://scripts/world/player/ground.gd")
const PlayerAnim := preload("res://scripts/world/player/player_anim.gd")

static var _gd_at: Dictionary = {}

static func _gd(path: String) -> GDScript:
	var s: GDScript = _gd_at.get(path) as GDScript
	if s == null:
		s = load(path) as GDScript
		_gd_at[path] = s
	return s

static func physics(host: CharacterBody3D, delta: float) -> void:
	if bool(App.get("_menu_loading")):
		_loco(host, delta)
		return
	var PlayerAct: GDScript = _gd("res://scripts/world/player/player_act.gd")
	var PlayerLock: GDScript = _gd("res://scripts/world/player/player_lock.gd")
	var PlayerCombat: GDScript = _gd("res://scripts/world/player/player_combat.gd")
	var PlayerHit: GDScript = _gd("res://scripts/combat/player_hit.gd")
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
		Ground.ground(host, Vector3.ZERO)
		PlayerAnim.apply_facing(host, delta)
		if host.telegraph:
			host.telegraph.hide_now()
		Ground.follow(host)
		return
	if host.hp > 0.0:
		App.prog.tick_mana(delta)
	var close_block := false
	if host.ui_latch:
		host.ui_latch = false
		close_block = true
		host.interact_lock = maxf(host.interact_lock, 0.2)
		host.special_held = PlayerLock.ai_held(host, "special") or App.pad_held("special")
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
	var move: Vector2 = PlayerLock.ai_or_vec(host, "move") as Vector2
	if host.gathering != null:
		PlayerAct.tick_gather(host, delta, move)
		if host.gathering != null:
			Ground.settle(host, Vector3.ZERO, delta)
			return
	Ground.follow(host)
	PlayerLock.lock_and_aim(host, move, delta)
	if not close_block:
		PlayerCombat.try_special(host)
		PlayerCombat.try_basic(host)
		PlayerCombat.try_dash(host, move)
	var spd: float = App.bal.move_speed * (1.0 + _move_gear())
	if App.adrenaline:
		spd *= App.bal.adrenaline_speed
	if host.atk_state == host.ATK_BASIC:
		spd *= App.bal.attack_move_mult
	if host.atk_state == host.ATK_WIND or host.atk_state == host.ATK_ACT or host.atk_state == host.ATK_REC:
		spd *= 0.2
	var vel: Vector3 = Vector3(move.x, 0.0, move.y) * spd
	if host.dash_t > 0.0:
		var d: Vector2 = host.dash_dir if host.dash_dir.length_squared() > 0.0001 else (host.aim_dir if host.aim_dir.length_squared() > 0.0001 else Vector2.DOWN)
		vel = Vector3(d.x, 0.0, d.y) * App.bal.move_speed * App.bal.dash_speed_mult
		host.velocity = vel
		if host.is_inside_tree():
			PlayerHit.trail(host, delta)
	Ground.ground(host, vel)
	PlayerCombat.advance_attack(host, delta)
	if host.hurt_flash > 0.0:
		host.hurt_flash -= delta
		if host.body:
			host.body.modulate = Color(1.5, 0.7, 0.7) if host.hurt_flash > 0.0 else Color.WHITE
	PlayerAnim.apply_facing(host, delta)
	PlayerCombat.update_aim_line(host)
	PlayerCombat.update_aura(host, delta)
	Ground.follow(host)
	PlayerAct.refresh_prompt(host)
	if not close_block:
		if PlayerLock.ai_just(host, "interact") or App.pad_just("interact") or Input.is_action_just_pressed("interact"):
			PlayerAct.try_interact(host)
		if PlayerLock.ai_just(host, "potion") or App.pad_just("potion"):
			App.prog.use_potion()
		if PlayerLock.ai_just(host, "food") or App.pad_just("food"):
			App.prog.use_food()

static func _loco(host: CharacterBody3D, delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if App.has_method("pad_move"):
		move = App.pad_move()
	Ground.settle(host, Vector3(move.x, 0.0, move.y) * App.bal.move_speed, delta)

## Gear move speed, recomputed only when the equipped slots change (App.gear walks every slot and set).
static var _gear_key: int = 0
static var _gear_prog: Object = null
static var _gear_val: float = 0.0

static func _move_gear() -> float:
	if App.prog == null:
		return App.gear("move_spd")
	var key: int = App.prog.slots.hash()
	if key != _gear_key or _gear_prog != App.prog:
		_gear_key = key
		_gear_prog = App.prog
		_gear_val = App.gear("move_spd")
	return _gear_val
