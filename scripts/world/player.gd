extends CharacterBody3D

const T := preload("res://scripts/data/tunables.gd")
const Depth := preload("res://scripts/world/depth.gd")
const CamRig := preload("res://scripts/world/camera_rig.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const AimLineS := preload("res://scripts/combat/aim_line.gd")
const PlayerAnim := preload("res://scripts/world/player_anim.gd")
const PlayerHit := preload("res://scripts/combat/player_hit.gd")
const PlayerLock := preload("res://scripts/world/player_lock.gd")
const PlayerAct := preload("res://scripts/world/player_act.gd")

const ATK_NONE := 0
const ATK_BASIC := 1
const ATK_WIND := 2
const ATK_ACT := 3
const ATK_REC := 4

var aim_dir := Vector2.DOWN
var facing_key := "down"
var walk_t := 0.0
var atk_i := 0
var body: Sprite3D
var idle := {}
var walk := {}
var equip := {}
var attack := {}
var special := {}
var rig: Node3D
var telegraph
var aim_line
var iframe := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.DOWN
var trail_acc := 0.0
var atk_state := ATK_NONE
var atk_t := 0.0
var hit_done := false
var spec_point := Vector3.ZERO
var lock_armed := false
var lock_target: Node = null
var stick_hold := 0.0
var special_held := false
var aura: Sprite3D
var hp := 100.0
var max_hp := 100.0
var hurt_flash := 0.0
var gathering: Node = null
var gather_t := 0.0
var gather := {}
var death := {}
var dispel := {}
var exiting := false
var exit_t := 0.0
var exit_cond := ""
var exit_killer := ""
var last_hit := ""
var interact_lock := 0.0
var ui_latch := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	axis_lock_linear_y = true
	_add_body_shape()
	_load_sprites()
	body = _make_sprite(2)
	add_child(body)
	aura = _make_sprite(3)
	aura.modulate = Color(1.0, 0.45, 0.12, 0.0)
	aura.pixel_size = 0.018
	add_child(aura)
	rig = CamRig.new()
	rig.name = "CamRig"
	add_child(rig)
	if rig.has_method("follow"):
		rig.follow(global_position)
	telegraph = TelegraphS.new()
	add_child(telegraph)
	telegraph.hide_now()
	aim_line = AimLineS.new()
	add_child(aim_line)
	max_hp = App.bal.player_max_hp + App.prog.gear_hp() + App.prog.skill_hp()
	if App.run_hp >= 0.0:
		hp = clampf(App.run_hp, 0.0, max_hp)
	else:
		hp = max_hp
	_apply_tex(_pose_tex("down"))
	_apply_facing(0.016)


func _make_sprite(prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.centered = true
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.alpha_scissor_threshold = 0.4
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.render_priority = prio
	return s


func _add_body_shape() -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = T.PLAYER_BODY
	cs.shape = sh
	cs.position = Vector3(0.0, T.PLAYER_BODY.y * 0.5, 0.08)
	add_child(cs)


func _load_sprites() -> void:
	PlayerAnim.load_sprites(self)


func reload_character() -> void:
	_load_sprites()
	_apply_facing(0.016)


func set_weapon(id: String) -> void:
	App.weapon = id
	_load_sprites()


func _physics_process(delta: float) -> void:
	if exiting:
		_tick_exit(delta)
		return
	_cooldowns(delta)
	if App.ui_open:
		ui_latch = true
		stop_gather()
		atk_state = ATK_NONE
		dash_t = 0.0
		special_held = _ai_held("special") or App.pad_held("special")
		velocity = Vector3.ZERO
		move_and_slide()
		global_position.y = 0.0
		if body:
			Depth.apply(body, global_position)
		_apply_facing(delta)
		if telegraph:
			telegraph.hide_now()
		if rig and rig.has_method("follow"):
			rig.follow(global_position)
		return
	var close_block := false
	if ui_latch:
		ui_latch = false
		close_block = true
		interact_lock = maxf(interact_lock, 0.2)
		special_held = _ai_held("special") or App.pad_held("special")
		if App.has_method("swallow_close_pad"):
			App.swallow_close_pad()
	var move := _ai_or_vec("move")
	if gathering != null:
		_tick_gather(delta, move)
		if gathering != null:
			velocity = Vector3.ZERO
			move_and_slide()
			global_position.y = 0.0
			if body:
				Depth.apply(body, global_position)
			_apply_facing(delta)
			if rig and rig.has_method("follow"):
				rig.follow(global_position)
			return
	if rig and rig.has_method("follow"):
		rig.follow(global_position)
	_lock_and_aim(move, delta)
	if not close_block:
		_try_special()
		_try_basic()
		_try_dash(move)
	var spd: float = App.bal.move_speed * (1.0 + float(App.prog.set_stats().spd))
	if App.adrenaline:
		spd *= App.bal.adrenaline_speed
	if atk_state == ATK_BASIC:
		spd *= App.bal.attack_move_mult
	if atk_state == ATK_WIND or atk_state == ATK_ACT or atk_state == ATK_REC:
		spd *= 0.2
	if dash_t > 0.0:
		var d := dash_dir if dash_dir.length_squared() > 0.0001 else (aim_dir if aim_dir.length_squared() > 0.0001 else Vector2.DOWN)
		velocity = Vector3(d.x, 0.0, d.y) * App.bal.move_speed * App.bal.dash_speed_mult
		if is_inside_tree():
			_trail(delta)
	else:
		velocity = Vector3(move.x, 0.0, move.y) * spd
	move_and_slide()
	global_position.y = 0.0
	if body:
		Depth.apply(body, global_position)
	_advance_attack(delta)
	if hurt_flash > 0.0:
		hurt_flash -= delta
		if body:
			body.modulate = Color(1.5, 0.7, 0.7) if hurt_flash > 0.0 else Color.WHITE
	_apply_facing(delta)
	_update_aim_line()
	_update_aura(delta)
	if rig and rig.has_method("follow"):
		rig.follow(global_position)
	_refresh_prompt()
	if not close_block:
		if _ai_just("interact") or App.pad_just("interact"):
			_try_interact()
		if _ai_just("potion") or App.pad_just("potion"):
			App.prog.use_potion()
		if _ai_just("food") or App.pad_just("food"):
			App.prog.use_food()


func is_alive() -> bool:
	return hp > 0.0


func take_hit(raw: float, from_dir: Vector2, crit: bool, src := "") -> void:
	PlayerAct.take_hit(self, raw, from_dir, crit, src)


func heal(amount: float) -> void:
	PlayerAct.heal(self, amount)


func play_exit(cond: String, killer := "") -> void:
	PlayerAct.play_exit(self, cond, killer)


func start_gather(node: Node) -> void:
	PlayerAct.start_gather(self, node)


func stop_gather() -> void:
	PlayerAct.stop_gather(self)


func _tick_exit(delta: float) -> void:
	PlayerAct.tick_exit(self, delta)


func _tick_gather(delta: float, move: Vector2) -> void:
	PlayerAct.tick_gather(self, delta, move)


func _refresh_prompt() -> void:
	PlayerAct.refresh_prompt(self)


func _try_interact() -> void:
	PlayerAct.try_interact(self)


func _cooldowns(delta: float) -> void:
	PlayerAct.cooldowns(self, delta)


func _ai_on() -> bool:
	return PlayerLock.ai_on()


func _ai_or_vec(which: String) -> Vector2:
	return PlayerLock.ai_or_vec(self, which)


func _ai_just(action: String) -> bool:
	return PlayerLock.ai_just(self, action)


func _ai_held(action: String) -> bool:
	return PlayerLock.ai_held(self, action)


func _lock_and_aim(move: Vector2, delta: float) -> void:
	PlayerLock.lock_and_aim(self, move, delta)


func _try_dash(move: Vector2) -> void:
	if App.ui_open or interact_lock > 0.0:
		return
	if dash_t > 0.0:
		return
	if not (_ai_just("dash") or App.pad_just("dash")):
		return
	if dash_cd > 0.0:
		return
	if move.length() > 0.2:
		dash_dir = move.normalized()
	elif aim_dir.length() > 0.2:
		dash_dir = aim_dir
	dash_t = App.bal.dash_duration
	dash_cd = App.bal.dash_cooldown
	iframe = App.bal.dash_duration
	App.sfx("dash")
	if App.tel:
		App.tel.note_dash()


func _try_special() -> void:
	if App.ui_open:
		special_held = _ai_held("special") or App.pad_held("special")
		return
	var held := _ai_held("special") or App.pad_held("special")
	var pressed := held and not special_held
	special_held = held
	if not pressed:
		return
	if atk_state != ATK_NONE or dash_t > 0.0:
		return
	atk_state = ATK_WIND
	atk_t = 0.0
	hit_done = false
	spec_point = _special_point()
	_draw_special_tele(false)
	if App.tel:
		App.tel.note_special(false)


func _try_basic() -> void:
	if App.ui_open:
		return
	if atk_state != ATK_NONE or dash_t > 0.0:
		return
	if not (_ai_held("attack") or App.pad_held("attack")):
		return
	atk_state = ATK_BASIC
	atk_t = 0.0
	hit_done = false
	_draw_basic_tele(false)


func _advance_attack(delta: float) -> void:
	if atk_state == ATK_NONE:
		if telegraph:
			telegraph.hide_now()
		return
	atk_t += delta
	if atk_state == ATK_BASIC:
		var dur := _basic_duration()
		var hit_at := dur * _hit_norm()
		if not hit_done and atk_t >= hit_at:
			hit_done = true
			_draw_basic_tele(true)
			_apply_basic()
		if atk_t >= dur:
			atk_state = ATK_NONE
			if telegraph:
				telegraph.hide_now()
		return
	if atk_state == ATK_WIND:
		_draw_special_tele(false)
		if atk_t >= App.bal.special_windup:
			atk_state = ATK_ACT
			atk_t = 0.0
			_draw_special_tele(true)
			_apply_special()
		return
	if atk_state == ATK_ACT:
		if atk_t >= 0.16:
			atk_state = ATK_REC
			atk_t = 0.0
			if telegraph:
				telegraph.hide_now()
		return
	if atk_state == ATK_REC:
		if atk_t >= App.bal.special_recovery:
			atk_state = ATK_NONE


func _basic_duration() -> float:
	var rate: float = App.bal.axe_rate
	if App.weapon == "staff":
		rate = App.bal.staff_rate
	elif App.weapon == "longbow":
		rate = App.bal.bow_rate
	return 1.0 / maxf(0.2, rate)


func _hit_norm() -> float:
	if App.weapon == "staff":
		return App.bal.staff_hit_norm
	if App.weapon == "longbow":
		return App.bal.bow_hit_norm
	return App.bal.axe_hit_norm


func _draw_basic_tele(active: bool) -> void:
	PlayerHit.draw_basic_tele(self, active)


func _draw_special_tele(active: bool) -> void:
	PlayerHit.draw_special_tele(self, active)


func _special_point() -> Vector3:
	return PlayerHit.special_point(self)


func _apply_basic() -> void:
	PlayerHit.apply_basic(self)


func _apply_special() -> void:
	PlayerHit.apply_special(self)


func _trail(delta: float) -> void:
	PlayerHit.trail(self, delta)


func _update_aim_line() -> void:
	if aim_line == null:
		return
	var on: bool = App.in_dungeon and App.bal.aim_line_on
	var length: float = App.bal.aim_line_length
	if App.bal.aim_line_use_weapon_range:
		length = _weapon_reach()
	aim_line.update_line(global_position, aim_dir, length, App.bal.aim_line_width, App.bal.aim_line_opacity, on)


func _weapon_reach() -> float:
	if App.weapon == "great_axe":
		return maxf(App.bal.axe_range, App.bal.slam_radius)
	if App.weapon == "staff":
		return maxf(App.bal.staff_range, App.bal.staff_special_radius)
	return maxf(App.bal.bow_range, App.bal.bow_special_range)


func _update_aura(delta: float) -> void:
	if aura == null:
		return
	var a := 0.55 if App.adrenaline else 0.0
	aura.modulate.a = move_toward(aura.modulate.a, a, delta * 3.0)
	aura.visible = aura.modulate.a > 0.02
	if aura.visible:
		aura.rotate_y(delta * 2.4)
		if body:
			aura.texture = body.texture
			aura.pixel_size = body.pixel_size * 1.15
			aura.position.y = body.position.y


func _pose_tex(key: String) -> Texture2D:
	return PlayerAnim.pose_tex(self, key)


func _apply_tex(tex: Texture2D) -> void:
	PlayerAnim.apply_tex(self, tex)


func _apply_facing(delta: float) -> void:
	PlayerAnim.apply_facing(self, delta)
