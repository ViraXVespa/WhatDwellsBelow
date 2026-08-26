extends CharacterBody3D

const Combat := preload("res://scripts/combat/combat.gd")
const Depth := preload("res://scripts/world/depth.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const Facing := preload("res://scripts/world/facing.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const ProjS := preload("res://scripts/combat/projectile.gd")

const ST_IDLE := 0
const ST_CHASE := 1
const ST_HUNT := 2
const ST_RETURN := 3
const ST_WIND := 4
const ST_STRIKE := 5
const ST_REC := 6
const ST_FLEE := 7

var type_id := "goblin"
var role := "melee"
var move_kind := "walk"
var hp := 32.0
var max_hp := 32.0
var defense := 0.0
var damage := 8.0
var move_spd := 3.0
var atk_range := 1.2
var arc_deg := 90.0
var is_boss := false
var is_named := false
var named_name := ""
var group_id := 0
var post := Vector3.ZERO
var last_seen := Vector3.ZERO
var hunt_t := 0.0
var reaggro_t := 0.0
var state := ST_IDLE
var aim := Vector2.DOWN
var locked_aim := Vector2.DOWN
var wind_t := 0.0
var rec_t := 0.0
var hop_t := 0.0
var bob_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var flash := 0.0
var stagger := 0.0
var knock := Vector3.ZERO
var knock_t := 0.0
var dead := false
var spr: Sprite3D
var tag: Label3D
var bang: Label3D
var telegraph
var base_mod := Color.WHITE
var size_u := 1.5
var idle_t := 0.0
var wander_dir := Vector2.RIGHT
var flee_t := 0.0
var spawned_help := false
var spec_point := Vector3.ZERO
var wind_dur := 0.42


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	axis_lock_linear_y = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.48, 1.05, 0.38)
	cs.shape = sh
	cs.position = Vector3(0.0, 0.52, 0.0)
	add_child(cs)
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.render_priority = 1
	add_child(spr)
	tag = Label3D.new()
	tag.position = Vector3(0.0, 1.55, 0.0)
	tag.font_size = 34
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.011
	tag.visible = false
	add_child(tag)
	bang = Label3D.new()
	bang.text = "!"
	bang.position = Vector3(0.0, 1.85, 0.0)
	bang.font_size = 64
	bang.outline_size = 12
	bang.modulate = Color(1.0, 0.92, 0.2)
	bang.outline_modulate = Color(0.05, 0.04, 0.02)
	bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bang.no_depth_test = true
	bang.pixel_size = 0.014
	bang.visible = false
	add_child(bang)
	telegraph = TelegraphS.new()
	add_child(telegraph)
	telegraph.hide_now()


func setup(id: String, floor_n: int, named := false, given_name := "") -> void:
	type_id = id
	var d: Dictionary = Roster.def(id)
	role = str(d.role)
	move_kind = str(d.move)
	var cycle := int((maxi(1, floor_n) - 1) / 5)
	var hp_m: float = App.bal.enemy_hp_mult * (1.0 + App.bal.cycle_hp * float(cycle))
	var dmg_m: float = App.bal.enemy_dmg_mult * (1.0 + App.bal.cycle_hp * 0.5 * float(cycle))
	hp = float(d.hp) * hp_m
	damage = float(d.dmg) * dmg_m
	move_spd = float(d.spd) * App.bal.enemy_speed_mult
	atk_range = float(d.range)
	defense = float(d.def) + float(cycle) * 2.0
	arc_deg = float(d.arc)
	size_u = float(d.size)
	base_mod = Roster.cycle_tint(cycle)
	if named:
		_make_named(given_name, floor_n)
	max_hp = hp
	_load_tex()
	call_deferred("_mark_post")


func setup_boss(title: String, floor_n: int) -> void:
	is_boss = true
	add_to_group("boss")
	var cycle := int((maxi(1, floor_n) - 1) / 5)
	var id := "orc"
	role = "melee"
	move_kind = "walk"
	if title == "Gate Master":
		id = "shaman"
		role = "mage"
		move_kind = "walk"
	type_id = id
	var d: Dictionary = Roster.def(id)
	var mult: float = App.bal.boss_hp_mult * (1.0 + App.bal.cycle_hp * float(cycle))
	if title == "Gate Master":
		mult *= 1.35
	hp = float(d.hp) * mult
	max_hp = hp
	damage = float(d.dmg) * 1.8 * App.bal.enemy_dmg_mult
	move_spd = float(d.spd) * 0.85 * App.bal.enemy_speed_mult
	atk_range = 2.4 if title != "Gate Master" else 4.6
	defense = float(d.def) + 10.0 + float(cycle) * 4.0
	arc_deg = 140.0 if title != "Gate Master" else 360.0
	size_u = float(d.size) * 1.55
	base_mod = Color(1.15, 0.72, 0.55) if title != "Gate Master" else Color(0.72, 0.58, 1.18)
	tag.text = title
	tag.visible = true
	tag.modulate = Color(1.0, 0.82, 0.35)
	tag.outline_modulate = Color(0, 0, 0)
	_load_tex(title)
	call_deferred("_mark_post")


func setup_guard(id: String, floor_n: int) -> void:
	setup(id, floor_n, false, "")


func _make_named(given: String, _floor_n: int) -> void:
	is_named = true
	add_to_group("named")
	named_name = given
	hp *= App.bal.named_hp
	damage *= App.bal.named_dmg
	size_u *= App.bal.named_scale
	atk_range *= 1.12
	tag.text = named_name
	tag.visible = true
	tag.position = Vector3(0.0, 0.08, 0.0)
	tag.modulate = Color(1.0, 0.92, 0.18)
	tag.outline_modulate = Color(0, 0, 0)
	tag.outline_size = 12
	base_mod *= Color(1.08, 1.05, 0.9)


func _mark_post() -> void:
	post = global_position
	last_seen = global_position
	last_pos = global_position


func _load_tex(boss_title := "") -> void:
	if spr == null:
		return
	var path := "res://assets/sprites/enemies/%s/idle_down.png" % type_id
	if boss_title == "Floor Guardian":
		var g := "res://assets/sprites/enemies/guardian/idle_down.png"
		if ResourceLoader.exists(g):
			path = g
	elif boss_title == "Gate Master":
		var m := "res://assets/sprites/enemies/gate_master/idle_down.png"
		if ResourceLoader.exists(m):
			path = m
	if not ResourceLoader.exists(path):
		path = "res://assets/fx/dummy.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		var th := float(maxi(1, spr.texture.get_height()))
		spr.pixel_size = size_u / th
	spr.position.y = size_u * 0.48
	spr.modulate = base_mod
	if is_named:
		tag.position.y = 0.08
	else:
		tag.position.y = size_u * 0.95 + 0.35
	bang.position.y = size_u * 0.95 + 0.65


func force_kill() -> void:
	hp = 0.0
	_die()


func is_alive() -> bool:
	return not dead and hp > 0.0


func start_flee() -> void:
	if dead or is_boss:
		return
	state = ST_FLEE
	flee_t = App.bal.flee_run_time
	spawned_help = false
	bang.visible = true
	if telegraph:
		telegraph.hide_now()
	_call_help()


func take_hit(raw: float, from_dir: Vector2, crit: bool) -> void:
	if dead:
		return
	var dmg: float = App.bal.apply_defense(raw, defense)
	if crit:
		dmg *= App.bal.crit_mult
		flash = 0.16
	else:
		flash = 0.08
	hp = maxf(0.0, hp - dmg)
	knock = Vector3(from_dir.x, 0.0, from_dir.y) * App.bal.knockback
	knock_t = 0.12
	_float(int(round(dmg)), crit)
	App.hitstop(App.bal.hitstop)
	App.sfx("hit" if not crit else "crit")
	var host := get_parent()
	if host and host.has_method("note_enemy_hit"):
		host.note_enemy_hit(self, dmg)
	if hp <= 0.0:
		_die()


func apply_stagger(sec: float) -> void:
	if is_boss:
		stagger = maxf(stagger, App.bal.slam_stagger_boss)
	else:
		stagger = maxf(stagger, sec)


func _float(amount: int, crit: bool) -> void:
	var n: Label3D = FloatS.new()
	n.setup(amount, crit)
	n.position = global_position + Vector3(0.0, size_u * 0.7, 0.0)
	var host := get_parent()
	if host:
		host.add_child(n)
	else:
		add_child(n)


func _die() -> void:
	if dead:
		return
	dead = true
	App.on_kill()
	App.prog.note_kill(type_id, named_name)
	collision_layer = 0
	if telegraph:
		telegraph.hide_now()
	if is_boss:
		App.notify_boss_dead()
	_drop_loot()
	state = ST_REC
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.42)
	if spr:
		tw.parallel().tween_property(spr, "pixel_size", spr.pixel_size * 0.86, 0.42)
	tw.finished.connect(queue_free)


func _drop_loot() -> void:
	var host := get_parent()
	if host == null:
		return
	var gold_n := 1 + randi() % (2 + mini(4, App.floor_n))
	if is_boss:
		gold_n += 6
	var PickupS := load("res://scripts/world/pickup.gd")
	var g: Node3D = PickupS.new()
	host.add_child(g)
	g.setup("gold", global_position + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), gold_n)
	if is_boss:
		return
	if randf() < 0.12 + 0.02 * float(App.floor_n):
		var rarity := "white"
		if randf() < 0.18:
			rarity = "green"
		var item := App.prog.make_armor(["head", "body", "legs"][randi() % 3], rarity)
		if not App.prog.add_item(item):
			App.spawn_floor_item(item, global_position)
		else:
			App.toast(str(item.name))
			App.sfx("pickup")


func _physics_process(delta: float) -> void:
	if dead:
		return
	if post == Vector3.ZERO:
		_mark_post()
	bob_t += delta
	reaggro_t = maxf(0.0, reaggro_t - delta)
	if stagger > 0.0:
		stagger -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		_present(delta)
		return
	if knock_t > 0.0:
		knock_t -= delta
		velocity = knock
		move_and_slide()
		_present(delta)
		return
	_ai(delta)
	move_and_slide()
	global_position.y = 0.0
	_stuck(delta)
	_present(delta)


func _ai(delta: float) -> void:
	var player := _player()
	if player == null:
		_idle(delta)
		return
	var ppos: Vector3 = player.global_position
	var to_p := Vector2(ppos.x - global_position.x, ppos.z - global_position.z)
	var dist := to_p.length()
	var from_post := Vector2(global_position.x - post.x, global_position.z - post.z).length()
	var has_los := Combat.los(global_position, ppos, get_world_3d())
	if has_los:
		last_seen = ppos
		if to_p.length_squared() > 0.0001:
			aim = to_p.normalized()
	if state == ST_FLEE:
		_do_flee(delta, to_p)
		return
	if state == ST_WIND or state == ST_STRIKE or state == ST_REC:
		_do_attack(delta)
		return
	if from_post > App.bal.leash_range:
		state = ST_RETURN
		reaggro_t = App.bal.reaggro_cd
		_steer_to(post, delta)
		return
	if state == ST_RETURN:
		if from_post < 0.45:
			state = ST_IDLE
			velocity = Vector3.ZERO
			return
		if has_los and dist < App.bal.aggro_range and from_post < App.bal.leash_range * 0.75 and reaggro_t <= 0.0:
			state = ST_CHASE
			return
		_steer_to(post, delta)
		return
	if has_los and dist <= App.bal.aggro_range:
		if dist <= atk_range:
			_begin_windup()
			return
		state = ST_CHASE
		hunt_t = App.bal.hunt_duration
		_steer_to(ppos, delta)
		return
	if state == ST_CHASE or state == ST_HUNT:
		hunt_t -= delta
		state = ST_HUNT
		if hunt_t <= 0.0:
			state = ST_RETURN
			_steer_to(post, delta)
			return
		_steer_to(last_seen, delta)
		var near_last := Vector2(last_seen.x - global_position.x, last_seen.z - global_position.z).length() < 0.4
		if near_last:
			state = ST_RETURN
		return
	_idle(delta)


func _begin_windup() -> void:
	state = ST_WIND
	wind_t = 0.0
	locked_aim = aim if aim.length_squared() > 0.0001 else Vector2.DOWN
	aim = locked_aim
	if role == "mage":
		wind_dur = App.bal.windup_mage
		var reach: float = atk_range * 0.55
		spec_point = global_position + Vector3(locked_aim.x, 0.0, locked_aim.y) * reach
		var player := _player()
		if player:
			spec_point = player.global_position
	elif role == "ranged":
		wind_dur = App.bal.windup_ranged
	else:
		wind_dur = App.bal.windup_melee
	if is_boss and role == "melee":
		wind_dur += 0.12
	_draw_tele(false)


func _do_attack(delta: float) -> void:
	if state == ST_WIND:
		velocity = Vector3.ZERO
		wind_t += delta
		_draw_tele(false)
		if wind_t >= wind_dur:
			state = ST_STRIKE
			wind_t = 0.0
			_draw_tele(true)
			_strike()
		return
	if state == ST_STRIKE:
		if role == "melee":
			_move_dir(locked_aim, 2.35, delta)
		else:
			velocity = Vector3.ZERO
		wind_t += delta
		if wind_t >= 0.14:
			state = ST_REC
			rec_t = 0.0
			velocity = Vector3.ZERO
			if telegraph:
				telegraph.hide_now()
		return
	if state == ST_REC:
		velocity = Vector3.ZERO
		rec_t += delta
		if rec_t >= App.bal.enemy_recover:
			state = ST_CHASE
			if telegraph:
				telegraph.hide_now()


func _draw_tele(active: bool) -> void:
	if telegraph == null:
		return
	var wind_col := Color(1.0, 0.82, 0.28, 0.42)
	var act_col := Color(1.0, 0.25, 0.18, 0.55)
	var col := act_col if active else wind_col
	if role == "mage" or (is_boss and type_id == "shaman"):
		col = Color(0.55, 0.35, 1.0, 0.5) if active else Color(0.7, 0.55, 1.0, 0.38)
		telegraph.show_circle(spec_point if role == "mage" else global_position, atk_range if is_boss and role == "mage" else 1.65, col)
		return
	if role == "ranged":
		col = Color(0.95, 0.55, 0.2, 0.5) if active else Color(1.0, 0.82, 0.28, 0.4)
		telegraph.show_arc(global_position, locked_aim, atk_range, maxf(12.0, arc_deg), col)
		return
	if is_boss and role == "melee":
		telegraph.show_circle(global_position, atk_range, col)
		return
	telegraph.show_arc(global_position, locked_aim, atk_range, arc_deg, col)


func _strike() -> void:
	var player := _player()
	if role == "ranged":
		var n := 3 if is_named else 1
		if is_named:
			var base := atan2(locked_aim.y, locked_aim.x)
			for i in n:
				var t := 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
				var a := base + t * 0.28
				_spawn_shot(Vector2(cos(a), sin(a)))
		else:
			_spawn_shot(locked_aim)
		return
	if role == "mage":
		var rad := 1.85 if not is_named else 2.35
		if is_boss:
			rad = atk_range
		if player and Combat.in_circle(spec_point, rad, player.global_position):
			if Combat.los(spec_point, player.global_position, get_world_3d()):
				_hit_player(player)
		if is_named or is_boss:
			_spawn_shot(locked_aim)
			if is_boss:
				var base := atan2(locked_aim.y, locked_aim.x)
				_spawn_shot(Vector2(cos(base + 0.4), sin(base + 0.4)))
				_spawn_shot(Vector2(cos(base - 0.4), sin(base - 0.4)))
		return
	if player == null:
		return
	if is_boss:
		if Combat.in_circle(global_position, atk_range, player.global_position):
			_hit_player(player)
		return
	if Combat.in_arc(global_position, locked_aim, atk_range, arc_deg, player.global_position):
		_hit_player(player)
	if is_named and Combat.in_arc(global_position, locked_aim, atk_range * 1.1, arc_deg + 20.0, player.global_position):
		_hit_player(player, 0.45)


func _hit_player(player: Node, mult := 1.0) -> void:
	if player and player.has_method("take_hit"):
		player.take_hit(damage * mult, locked_aim, false, kill_tag())


func kill_tag() -> String:
	if is_boss:
		var title := str(tag.text) if tag else ""
		return "gate_master" if title == "Gate Master" else "guardian"
	return type_id


func _spawn_shot(dir: Vector2) -> void:
	var p: Node3D = ProjS.new()
	var host := get_parent()
	if host:
		host.add_child(p)
	else:
		add_child(p)
	var tex := "res://assets/fx/arrow.png"
	if role == "mage":
		tex = "res://assets/fx/lightning.png"
	p.setup(global_position, dir, App.bal.enemy_proj_speed, atk_range + 1.5, damage, true, false, true, tex)
	p.source = kill_tag()


func _do_flee(delta: float, to_p: Vector2) -> void:
	flee_t -= delta
	var away := -to_p.normalized() if to_p.length_squared() > 0.0001 else Vector2.RIGHT
	aim = away
	_move_dir(away, App.bal.flee_speed_mult, delta)
	if flee_t <= 0.0:
		bang.visible = false
		_call_help()
		state = ST_CHASE


func _call_help() -> void:
	if spawned_help:
		return
	spawned_help = true
	var host := get_parent()
	if host and host.has_method("spawn_reinforcement"):
		var n := int(App.bal.flee_help)
		for i in n:
			host.spawn_reinforcement(type_id, global_position, group_id)


func _idle(delta: float) -> void:
	state = ST_IDLE
	idle_t -= delta
	if idle_t <= 0.0:
		idle_t = randf_range(0.8, 1.8)
		var a := randf() * TAU
		wander_dir = Vector2(cos(a), sin(a))
	var dest := post + Vector3(wander_dir.x, 0.0, wander_dir.y) * 0.7
	var d := Vector2(dest.x - global_position.x, dest.z - global_position.z)
	if d.length() > 0.12:
		_steer_to(dest, delta)
	else:
		velocity = Vector3.ZERO


func _steer_to(dest: Vector3, delta: float) -> void:
	var d := Vector2(dest.x - global_position.x, dest.z - global_position.z)
	if d.length_squared() < 0.0004:
		velocity = Vector3.ZERO
		return
	aim = d.normalized()
	_move_dir(aim, 1.0, delta)


func _move_dir(dir: Vector2, spd_m: float, delta: float) -> void:
	var sep := _sep()
	var wish := dir.normalized() * move_spd * spd_m
	wish += Vector2(sep.x, sep.z)
	if move_kind == "hop":
		hop_t -= delta
		if hop_t <= 0.0:
			hop_t = 0.42
			velocity = Vector3(wish.x, 0.0, wish.y) * 1.35
		else:
			velocity = velocity.move_toward(Vector3.ZERO, move_spd * 3.0 * delta)
	else:
		velocity = Vector3(wish.x, 0.0, wish.y)


func _sep() -> Vector3:
	var push := Vector3.ZERO
	var lim: float = App.bal.enemy_sep
	for e in Combat.enemies():
		if e == self or e == null or not is_instance_valid(e):
			continue
		var d: Vector3 = global_position - (e as Node3D).global_position
		d.y = 0.0
		var L := d.length()
		if L < lim and L > 0.01:
			push += d / L * (lim - L) * 2.4
	return push


func _stuck(delta: float) -> void:
	if state != ST_CHASE and state != ST_HUNT and state != ST_RETURN:
		stuck_t = 0.0
		last_pos = global_position
		return
	var step := Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	last_pos = global_position
	if step < 0.012:
		stuck_t += delta
		if stuck_t > 0.35:
			var side := Vector2(-aim.y, aim.x)
			if randf() < 0.5:
				side = -side
			velocity += Vector3(side.x, 0.0, side.y) * move_spd * 1.2
			stuck_t = 0.0
	else:
		stuck_t = 0.0


func _present(delta: float) -> void:
	if spr == null:
		return
	var lift := 0.0
	if move_kind == "fly":
		lift = App.bal.fly_height + sin(bob_t * 5.0) * 0.08
	elif move_kind == "hop" and hop_t > 0.18:
		lift = App.bal.hop_height * (hop_t / 0.42)
	spr.position.y = size_u * 0.48 + lift
	var fk := Facing.from_aim(aim)
	spr.flip_h = fk == "left" or fk == "up_left" or fk == "down_left"
	Depth.apply(spr, global_position)
	if flash > 0.0:
		flash -= delta
		spr.modulate = Color(1.7, 1.7, 1.7)
	elif state == ST_WIND:
		spr.modulate = base_mod * Color(1.15, 0.85, 0.55)
	else:
		spr.modulate = base_mod
	if bang.visible and state != ST_FLEE:
		bang.visible = false


func _player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var n := tree.get_first_node_in_group("player")
	if n is Node3D:
		return n
	return null


func state_name() -> String:
	match state:
		ST_IDLE:
			return "idle"
		ST_CHASE:
			return "chase"
		ST_HUNT:
			return "hunt"
		ST_RETURN:
			return "return"
		ST_WIND:
			return "windup"
		ST_STRIKE:
			return "strike"
		ST_REC:
			return "recover"
		ST_FLEE:
			return "flee"
		_:
			return "unk"


func smoke_force_leash() -> String:
	post = global_position
	global_position = post + Vector3(App.bal.leash_range + 2.5, 0.0, 0.0)
	state = ST_CHASE
	_ai(0.016)
	return state_name()
