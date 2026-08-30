extends CharacterBody3D

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const Depth := preload("res://scripts/world/depth.gd")
const CamRig := preload("res://scripts/world/camera_rig.gd")
const Combat := preload("res://scripts/combat/combat.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const AimLineS := preload("res://scripts/combat/aim_line.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const PlayerAnim := preload("res://scripts/world/player_anim.gd")
const PlayerHit := preload("res://scripts/combat/player_hit.gd")

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
	if hp <= 0.0 or exiting:
		return
	if iframe > 0.0:
		return
	if src != "":
		last_hit = src
	var dmg: float = App.bal.apply_defense(raw, App.prog.gear_def() + App.prog.skill_def())
	if crit:
		dmg *= App.bal.crit_mult
	hp = maxf(0.0, hp - dmg)
	iframe = App.bal.player_hurt_iframe
	hurt_flash = 0.12
	velocity += Vector3(from_dir.x, 0.0, from_dir.y) * App.bal.knockback * 0.45
	App.sfx("hurt")
	stop_gather()
	if App.tel:
		App.tel.note_damage_taken(dmg, hp, max_hp)
	App.prog.add_run_xp("def", App.bal.xp_def_hit)
	if hp <= 0.0:
		_player_die()


func _player_die() -> void:
	if Smoke.hold_player():
		hp = max_hp
		return
	play_exit("death", last_hit)


func heal(amount: float) -> void:
	if amount > 0.0 and hp < max_hp:
		App.prog.add_run_xp("hp", App.bal.xp_hp_heal)
	hp = minf(max_hp, hp + amount)


func play_exit(cond: String, killer := "") -> void:
	if exiting:
		return
	exiting = true
	exit_t = 0.0
	exit_cond = cond
	exit_killer = killer
	stop_gather()
	dash_t = 0.0
	atk_state = ATK_NONE
	iframe = 99.0
	lock_target = null
	lock_armed = false
	if cond == "death":
		hp = 0.0


func _tick_exit(delta: float) -> void:
	exit_t += delta
	velocity = Vector3.ZERO
	move_and_slide()
	global_position.y = 0.0
	_apply_facing(delta)
	if body:
		Depth.apply(body, global_position)
		body.modulate.a = clampf(1.0 - exit_t / 0.9, 0.12, 1.0)
	if rig and rig.has_method("follow"):
		rig.follow(global_position)
	if exit_t >= 0.9:
		exiting = false
		App.finish_end(exit_cond, exit_killer)


func start_gather(node: Node) -> void:
	if exiting:
		return
	if node == null or not is_instance_valid(node):
		return
	gathering = node
	gather_t = 0.0
	atk_state = ATK_NONE
	var p: Vector3 = (node as Node3D).global_position
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	if d.length() > 0.001:
		aim_dir = d.normalized()


func stop_gather() -> void:
	gathering = null
	gather_t = 0.0


func _tick_gather(delta: float, move: Vector2) -> void:
	if gathering == null or not is_instance_valid(gathering):
		stop_gather()
		return
	if move.length() > 0.22 or Input.is_action_just_pressed("dash") or Input.is_action_pressed("attack") or Input.is_action_just_pressed("special"):
		stop_gather()
		return
	gather_t += delta
	if App.tel:
		App.tel.gather_t += delta
	var wait := 2.4
	if gathering.get("interval") != null:
		wait = float(gathering.interval)
	if gather_t >= wait:
		gather_t = 0.0
		if gathering.has_method("strike"):
			var r: Dictionary = gathering.strike()
			if r.get("done", false):
				stop_gather()


func _refresh_prompt() -> void:
	if App.ui_open:
		return
	var best: Node = null
	var best_d := 1.35
	for n in get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var d := Vector2((n as Node3D).global_position.x - global_position.x, (n as Node3D).global_position.z - global_position.z).length()
			if d < best_d:
				best_d = d
				best = n
	if best and best.get("prompt") != null:
		App.interact_prompt = str(best.prompt)
	elif gathering:
		App.interact_prompt = "Gathering…"
	else:
		App.interact_prompt = ""


func _try_interact() -> void:
	if App.ui_open or interact_lock > 0.0:
		return
	var best: Node = null
	var best_d := 1.25
	for n in get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var d := Vector2((n as Node3D).global_position.x - global_position.x, (n as Node3D).global_position.z - global_position.z).length()
			if d < best_d:
				best_d = d
				best = n
	if best and best.has_method("interact"):
		var msg: String = str(best.interact(self))
		App.interact_prompt = msg
	else:
		App.interact_prompt = ""


func _cooldowns(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	iframe = maxf(0.0, iframe - delta)
	interact_lock = maxf(0.0, interact_lock - delta)
	if dash_t > 0.0:
		dash_t = maxf(0.0, dash_t - delta)
		iframe = maxf(iframe, dash_t)


func _ai_on() -> bool:
	return App.playtest != null and bool(App.playtest.get("ai_on"))


func _ai_or_vec(which: String) -> Vector2:
	if _ai_on():
		var raw: Variant = App.playtest.aim if which == "aim" else App.playtest.move
		if raw is Vector2:
			var v: Vector2 = raw
			if which != "aim" or v.length() > 0.1:
				return v
	if which == "aim":
		return App.pad_aim()
	return App.pad_move()


func _ai_just(action: String) -> bool:
	if not _ai_on():
		return false
	var raw: Variant = App.playtest.just
	if raw is Dictionary:
		return bool((raw as Dictionary).get(action, false))
	return false


func _ai_held(action: String) -> bool:
	if not _ai_on():
		return false
	if action == "attack":
		return bool(App.playtest.attack)
	if action == "special":
		return bool(App.playtest.special)
	return false


func _lock_and_aim(move: Vector2, delta: float) -> void:
	if Input.is_action_just_pressed("target_lock") or App.pad_just("target_lock"):
		if lock_armed:
			lock_armed = false
			lock_target = null
		else:
			lock_armed = true
			_acquire_lock()
	if lock_armed:
		if not _valid_lock(lock_target):
			_acquire_lock()
		if _valid_lock(lock_target):
			var tp: Vector3 = (lock_target as Node3D).global_position
			var d := Vector2(tp.x - global_position.x, tp.z - global_position.z)
			if d.length() > 0.001:
				aim_dir = d.normalized()
		var stick := _ai_or_vec("aim")
		if stick.length() > App.bal.lock_stick_deadzone:
			stick_hold += delta
			if stick_hold >= App.bal.lock_stick_delay:
				_cycle_lock(stick.normalized())
				stick_hold = 0.0
		else:
			stick_hold = 0.0
		return
	_update_aim(move)


func _valid_lock(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n.has_method("is_alive") and not n.is_alive():
		return false
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not Combat.on_screen(n as Node3D, cam):
		return false
	return Combat.los(global_position, (n as Node3D).global_position, get_world_3d())


func _acquire_lock() -> void:
	lock_target = _nearest(null, Vector2.ZERO)
	if lock_target == null:
		lock_armed = true


func _cycle_lock(dir: Vector2) -> void:
	var n := _nearest(lock_target, dir)
	if n:
		lock_target = n


func _nearest(exclude: Node, dir: Vector2) -> Node:
	var best: Node = null
	var best_s := 1.0e9
	for e in Combat.enemies():
		if e == exclude or not _valid_lock(e):
			continue
		var d := Combat.xz(e) - Vector2(global_position.x, global_position.z)
		var score := d.length()
		if dir.length_squared() > 0.0001:
			score = 2.5 - d.normalized().dot(dir) + d.length() * 0.05
		if score < best_s:
			best_s = score
			best = e
	return best


func _mouse_aim_dir() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2.ZERO
	var p: Vector3 = hit
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	if d.length_squared() < 0.0004:
		return Vector2.ZERO
	return d.normalized()


func _update_aim(move: Vector2) -> void:
	var stick := _ai_or_vec("aim")
	if stick.length() >= 0.24:
		aim_dir = stick.normalized()
		return
	if App.using_pad():
		if move.length() >= 0.12:
			aim_dir = move.normalized()
		return
	var mouse_dir := _mouse_aim_dir()
	if mouse_dir.length_squared() > 0.0001:
		aim_dir = mouse_dir
		return
	if move.length() >= 0.12:
		aim_dir = move.normalized()


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
