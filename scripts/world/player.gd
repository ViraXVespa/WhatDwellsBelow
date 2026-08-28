extends CharacterBody3D

const T := preload("res://scripts/data/tunables.gd")
const Facing := preload("res://scripts/world/facing.gd")
const Depth := preload("res://scripts/world/depth.gd")
const CamRig := preload("res://scripts/world/camera_rig.gd")
const Combat := preload("res://scripts/combat/combat.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const AimLineS := preload("res://scripts/combat/aim_line.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")

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
	idle.clear()
	walk.clear()
	equip.clear()
	attack.clear()
	special.clear()
	gather.clear()
	death.clear()
	dispel.clear()
	var kind: String = App.character_type
	var base := "res://assets/sprites/player/%s/" % kind
	var wpn: String = App.weapon
	for k in Facing.KEYS:
		var ip := base + "idle_%s.png" % k
		if ResourceLoader.exists(ip):
			idle[k] = load(ip)
		var ep := base + "equip_%s_%s.png" % [wpn, k]
		if ResourceLoader.exists(ep):
			equip[k] = load(ep)
		var frames: Array = []
		var i := 0
		while ResourceLoader.exists(base + "walk_%s_%d.png" % [k, i]):
			frames.append(load(base + "walk_%s_%d.png" % [k, i]))
			i += 1
		if not frames.is_empty():
			walk[k] = frames
		var atk: Array = []
		i = 0
		while ResourceLoader.exists(base + "atk_%s_%s_%d.png" % [wpn, k, i]):
			atk.append(load(base + "atk_%s_%s_%d.png" % [wpn, k, i]))
			i += 1
		if not atk.is_empty():
			attack[k] = atk
		var spc: Array = []
		i = 0
		while ResourceLoader.exists(base + "spc_%s_%s_%d.png" % [wpn, k, i]):
			spc.append(load(base + "spc_%s_%s_%d.png" % [wpn, k, i]))
			i += 1
		if not spc.is_empty():
			special[k] = spc
		var gth: Array = []
		i = 0
		while ResourceLoader.exists(base + "gather_%s_%d.png" % [k, i]):
			gth.append(load(base + "gather_%s_%d.png" % [k, i]))
			i += 1
		if not gth.is_empty():
			gather[k] = gth
		var dth: Array = []
		i = 0
		while ResourceLoader.exists(base + "death_%s_%d.png" % [k, i]):
			dth.append(load(base + "death_%s_%d.png" % [k, i]))
			i += 1
		if not dth.is_empty():
			death[k] = dth
		var dsp: Array = []
		i = 0
		while ResourceLoader.exists(base + "dispel_%s_%d.png" % [k, i]):
			dsp.append(load(base + "dispel_%s_%d.png" % [k, i]))
			i += 1
		if not dsp.is_empty():
			dispel[k] = dsp


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
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase4-smoke" in args or "--wdb-phase3-smoke" in args or "--wdb-phase5-smoke" in args or "--wdb-phase7-smoke" in args:
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
	if telegraph == null:
		return
	var col := Color(1.0, 0.25, 0.18, 0.55) if active else Color(1.0, 0.82, 0.28, 0.4)
	if App.weapon == "longbow":
		telegraph.show_arc(global_position, aim_dir, App.bal.bow_range, 12.0, col)
		return
	if App.weapon == "staff":
		telegraph.show_arc(global_position, aim_dir, App.bal.staff_range, App.bal.staff_arc_deg, col)
		return
	telegraph.show_arc(global_position, aim_dir, App.bal.axe_range, App.bal.axe_arc_deg, col)


func _draw_special_tele(active: bool) -> void:
	if telegraph == null:
		return
	var col := Color(0.45, 0.85, 1.0, 0.55) if active else Color(1.0, 0.82, 0.28, 0.42)
	if App.weapon == "great_axe":
		telegraph.show_circle(global_position, App.bal.slam_radius, col)
	elif App.weapon == "staff":
		telegraph.show_circle(spec_point, App.bal.staff_special_radius, col)
	else:
		telegraph.show_cone(global_position, aim_dir, App.bal.bow_special_range, App.bal.bow_special_cone, col)


func _special_point() -> Vector3:
	if _valid_lock(lock_target):
		return (lock_target as Node3D).global_position
	var reach: float = App.bal.staff_special_radius + 1.5
	return global_position + Vector3(aim_dir.x, 0.0, aim_dir.y) * reach


func _apply_basic() -> void:
	if App.weapon == "longbow":
		_spawn_arrow(aim_dir, _scaled_dmg(App.bal.bow_damage, false), App.bal.bow_range, App.bal.bow_proj_speed, App.bal.bow_los)
		App.sfx("bow")
		return
	var rng: float = App.bal.axe_range
	var arc: float = App.bal.axe_arc_deg
	var dmg: float = App.bal.axe_damage
	var need_los: bool = App.bal.axe_los
	if App.weapon == "staff":
		rng = App.bal.staff_range
		arc = App.bal.staff_arc_deg
		dmg = App.bal.staff_damage
		need_los = App.bal.staff_los
		App.sfx("hit")
	else:
		App.sfx("hit")
	_hit_arc(rng, arc, dmg, need_los, false)


func _apply_special() -> void:
	if App.weapon == "great_axe":
		App.sfx("slam")
		_hit_circle(global_position, App.bal.slam_radius, App.bal.axe_damage * App.bal.axe_slam_mult, false, true, "auto", true)
		_fx("res://assets/fx/crack.png", global_position, 2.4, false)
		return
	if App.weapon == "staff":
		App.sfx("bolt")
		_hit_circle(spec_point, App.bal.staff_special_radius, App.bal.staff_special_damage, false, false, "magic", true)
		_fx("res://assets/fx/lightning.png", spec_point, 2.6, true)
		return
	App.sfx("bow")
	var n := int(App.bal.bow_special_count)
	var cone := deg_to_rad(App.bal.bow_special_cone)
	var base := atan2(aim_dir.y, aim_dir.x)
	for i in n:
		var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
		var a := base + t * cone
		var d := Vector2(cos(a), sin(a))
		_spawn_arrow(d, _scaled_dmg(App.bal.bow_special_damage, true), App.bal.bow_special_range, App.bal.bow_proj_speed, App.bal.bow_los)


func _hit_arc(rng: float, arc: float, dmg: float, need_los: bool, stagger: bool) -> void:
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var p: Vector3 = (e as Node3D).global_position
		if not Combat.in_arc(global_position, aim_dir, rng, arc, p):
			continue
		if need_los and not Combat.los(global_position, p, get_world_3d()):
			continue
		_damage_enemy(e, dmg, stagger, "auto", false)
	_hit_breakables_arc(rng, arc, dmg, need_los)


func _hit_circle(origin: Vector3, radius: float, dmg: float, need_los: bool, stagger: bool, xp := "auto", is_special := false) -> void:
	for e in Combat.enemies():
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var p: Vector3 = (e as Node3D).global_position
		if not Combat.in_circle(origin, radius, p):
			continue
		if need_los and not Combat.los(origin, p, get_world_3d()):
			continue
		_damage_enemy(e, dmg, stagger, xp, is_special)
	_hit_breakables_circle(origin, radius, dmg, need_los)


func _scaled_dmg(base: float, is_special: bool) -> float:
	var d: float = base * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		d *= 1.0 + App.bal.shrine_dmg
	return d


func _damage_enemy(e: Node, dmg: float, stagger: bool, xp := "auto", is_special := false) -> void:
	if xp == "magic":
		is_special = true
	dmg = dmg * App.prog.skill_dmg_mult(is_special) + App.prog.gear_dmg()
	if App.shrine_t > 0.0:
		dmg *= 1.0 + App.bal.shrine_dmg
	_grant_hit_xp(xp)
	var crit := Combat.roll_crit(App.bal.crit_chance + float(App.prog.set_stats().crit))
	if e.has_method("take_hit"):
		e.take_hit(dmg, aim_dir, crit)
	if App.tel:
		App.tel.note_damage_dealt(dmg if not crit else dmg * App.bal.crit_mult, crit)
		if atk_state == ATK_ACT or atk_state == ATK_WIND:
			App.tel.spec_hit += 1
			var key := App.weapon
			if App.tel.wpn.has(key):
				App.tel.wpn[key].spec_hit = int(App.tel.wpn[key].spec_hit) + 1
	if stagger and e.has_method("apply_stagger"):
		e.apply_stagger(App.bal.slam_stagger)


func _grant_hit_xp(xp: String) -> void:
	var mode := xp
	if mode == "none":
		return
	if mode == "auto":
		if App.weapon == "staff":
			mode = "melee_staff"
		elif App.weapon == "longbow":
			mode = "ranged"
		else:
			mode = "melee_axe"
	if mode == "magic":
		App.prog.skill_grant_hit(true)
	elif mode == "ranged":
		App.prog.skill_grant_hit(false)
	elif mode == "melee_staff":
		App.prog.skill_grant_hit(false)
	else:
		App.prog.skill_grant_hit(false)


func _hit_breakables_arc(rng: float, arc: float, dmg: float, need_los: bool) -> void:
	for b in get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b):
			continue
		var p: Vector3 = (b as Node3D).global_position
		if not Combat.in_arc(global_position, aim_dir, rng + 0.35, arc, p):
			continue
		if need_los and not Combat.los(global_position, p, get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, aim_dir, false)


func _hit_breakables_circle(origin: Vector3, radius: float, dmg: float, need_los: bool) -> void:
	for b in get_tree().get_nodes_in_group("breakables"):
		if b == null or not is_instance_valid(b):
			continue
		var p: Vector3 = (b as Node3D).global_position
		if not Combat.in_circle(origin, radius + 0.25, p):
			continue
		if need_los and not Combat.los(origin, p, get_world_3d()):
			continue
		if b.has_method("take_hit"):
			b.take_hit(dmg, aim_dir, false)


func _spawn_arrow(dir: Vector2, dmg: float, rng: float, spd: float, need_los: bool) -> void:
	var p: Node3D = ProjS.new()
	var host := get_parent()
	if host:
		host.add_child(p)
	else:
		add_child(p)
	var crit := Combat.roll_crit(App.bal.crit_chance + float(App.prog.set_stats().crit))
	p.setup(global_position, dir, spd, rng, dmg, need_los, crit, false, "", true)


func _fx(path: String, pos: Vector3, h: float, ybill: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := Sprite3D.new()
	s.texture = load(path)
	s.centered = true
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if ybill else BaseMaterial3D.BILLBOARD_DISABLED
	s.pixel_size = h / float(maxi(1, s.texture.get_height()))
	s.position = pos + Vector3(0.0, 0.02 if not ybill else h * 0.45, 0.0)
	if not ybill:
		s.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var host := get_parent()
	if host:
		host.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.45)
	tw.finished.connect(s.queue_free)


func _trail(delta: float) -> void:
	if not is_inside_tree():
		return
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	if body.texture == null:
		return
	trail_acc += delta
	if trail_acc < App.bal.trail_gap:
		return
	trail_acc = 0.0
	var host := get_parent()
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var g := Sprite3D.new()
	g.texture = body.texture
	g.centered = true
	g.shaded = false
	g.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	g.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	g.pixel_size = body.pixel_size
	g.modulate = Color(0.45, 0.85, 1.0, 0.55)
	host.add_child(g)
	g.global_position = body.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, App.bal.trail_life)
	tw.finished.connect(g.queue_free)


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
	if equip.has(key):
		return equip[key]
	if idle.has(key):
		return idle[key]
	if idle.has("down"):
		return idle["down"]
	return null


func _clip(store: Dictionary, key: String) -> Array:
	if store.has(key):
		return store[key]
	var card := key
	if key.begins_with("up"):
		card = "up"
	elif key.begins_with("down"):
		card = "down"
	elif key.find("left") >= 0:
		card = "left"
	elif key.find("right") >= 0:
		card = "right"
	if store.has(card):
		return store[card]
	if store.has("down"):
		return store["down"]
	return []


func _apply_tex(tex: Texture2D) -> void:
	if body == null or tex == null:
		return
	body.texture = tex
	var th := float(maxi(1, tex.get_height()))
	body.pixel_size = T.PLAYER_H / th
	body.position.y = T.PLAYER_H * 0.5 + T.FEET_LIFT


func _apply_facing(delta: float) -> void:
	var key := Facing.from_aim(aim_dir)
	facing_key = key
	var tex: Texture2D = null
	if exiting:
		var frames := _clip(death if exit_cond == "death" else dispel, key)
		if not frames.is_empty():
			tex = frames[mini(frames.size() - 1, int(exit_t * 8.0))]
		elif idle.has(key):
			tex = idle[key]
		if tex:
			_apply_tex(tex)
		return
	if atk_state == ATK_WIND or atk_state == ATK_ACT or atk_state == ATK_REC:
		var frames := _clip(special, key)
		if frames.is_empty():
			frames = _clip(attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(atk_t * App.bal.atk_fps))
			tex = frames[idx]
	elif gathering != null:
		var frames := _clip(gather, key)
		if frames.is_empty():
			frames = _clip(attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(gather_t * 6.0) % frames.size())
			tex = frames[idx]
	elif atk_state == ATK_BASIC:
		var frames := _clip(attack, key)
		if not frames.is_empty():
			var idx := mini(frames.size() - 1, int(atk_t * App.bal.atk_fps))
			tex = frames[idx]
			atk_i = idx
	var planar := Vector2(velocity.x, velocity.z)
	var moving := planar.length() > T.MOVE_EPS and dash_t <= 0.0 and atk_state == ATK_NONE
	if tex == null and moving and walk.has(key):
		var frames: Array = walk[key]
		walk_t += delta
		tex = frames[int(walk_t * T.WALK_FPS) % frames.size()]
	if tex == null:
		walk_t = 0.0
		tex = _pose_tex(key)
	if tex:
		_apply_tex(tex)