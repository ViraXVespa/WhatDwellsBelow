extends CharacterBody3D

const SkillMath := preload("res://scripts/data/skills.gd")
const V3 := preload("res://scripts/view3d/v3.gd")

const SPEED := 190.0 / 64.0
const DASH_SPEED := 620.0 / 64.0
const DASH_TIME := 0.16
const DASH_CD := 1.15
const SLAM_CD := 5.0
const SLAM_RADIUS := 176.0 / 64.0
const AXE_RANGE := 118.0 / 64.0
const AXE_ARC := 0.96
const BODY_H := 1.18

var aim_dir := Vector2.DOWN
var target_mode := false
var current_target: Node = null
var dash_timer := 0.0
var dash_cd := 0.0
var slam_cd := 0.0
var attack_cd := 0.0
var iframe := 0.0
var channeling: Node = null
var channel_t := 0.0
var channel_need := 1.8
var body_sprite: Sprite3D
var flash := 0.0
var facing_sprites: Dictionary = {}
var walk_sprites: Dictionary = {}
var attack_sprites: Dictionary = {}
var facing_key := "down"
var walk_i := 0
var walk_t := 0.0
var attack_i := 0
var attack_t := 0.0
var attacking := false
var dying := false
var knock := Vector3.ZERO
var knock_t := 0.0
const WALK_FPS := 6.5
const ATTACK_FPS := 10.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	axis_lock_linear_y = true
	safe_margin = 0.04
	V3.add_cyl(self, V3.PLAYER_R, 0.7, Vector3(0, 0.35, 0.12))
	_load_facings()
	body_sprite = V3.sprite(facing_sprites.get("down", null), BODY_H, true)
	add_child(body_sprite)
	_apply_facing(0.016)


func _physics_process(delta: float) -> void:
	if dying:
		return
	if get_tree().paused:
		return
	_cooldowns(delta)
	if knock_t > 0.0:
		knock_t -= delta
		velocity = knock
		move_and_slide()
		global_position.y = 0.0
		_apply_facing(delta)
		return
	if channeling:
		_process_channel(delta)
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_aim(move)
	if dash_timer > 0.0:
		velocity = Vector3(aim_dir.x, 0.0, aim_dir.y) * DASH_SPEED
		dash_timer -= delta
		iframe = maxf(iframe, dash_timer)
	else:
		var spd := SPEED
		if Game.run:
			spd *= Game.run.move_mult
		velocity = Vector3(move.x, 0.0, move.y) * spd
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and move.length() + aim_dir.length() > 0.0:
			dash_timer = DASH_TIME
			dash_cd = DASH_CD * (Game.run.dash_cd_mult if Game.run else 1.0)
			iframe = DASH_TIME
			Sfx.play("dash")
			if move.length() > 0.2:
				aim_dir = move.normalized()
	move_and_slide()
	global_position.y = 0.0
	if Input.is_action_just_pressed("target_lock"):
		_toggle_target()
	if target_mode:
		_cycle_target()
		if is_instance_valid(current_target) and current_target is Node3D:
			var tp: Vector3 = (current_target as Node3D).global_position
			var d := Vector2(tp.x - global_position.x, tp.z - global_position.z)
			if d.length() > 0.001:
				aim_dir = d.normalized()
	var slammed := false
	if Input.is_action_just_pressed("slam") and Game.in_dungeon:
		slammed = _try_slam()
	if not slammed and Input.is_action_pressed("attack") and Game.in_dungeon:
		_try_attack()
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("potion"):
		_use_consumable("potion")
	if Input.is_action_just_pressed("food"):
		_use_consumable("food")
	_apply_facing(delta)
	if flash > 0.0:
		flash -= delta
		if body_sprite:
			body_sprite.modulate = Color(1.6, 0.7, 0.7)
	elif body_sprite:
		body_sprite.modulate = Color.WHITE


func _load_facings() -> void:
	for k in Art.FACING_KEYS:
		var path := "res://assets/sprites/player/%s.png" % k
		if ResourceLoader.exists(path):
			facing_sprites[k] = load(path)
		var frames: Array = []
		for i in 8:
			var wp := "res://assets/sprites/player/walk_%s_%d.png" % [k, i]
			if ResourceLoader.exists(wp):
				frames.append(load(wp))
		if not frames.is_empty():
			walk_sprites[k] = frames
	if facing_sprites.is_empty():
		facing_sprites["down"] = Art.body(Vector2i(64, 64), Color(0.24, 0.49, 0.72), Color(0.94, 0.84, 0.38))
	for k in Art.FACING_KEYS:
		var frames: Array = []
		for i in 8:
			var ap := "res://assets/sprites/player/attack_%s_%d.png" % [k, i]
			if ResourceLoader.exists(ap):
				frames.append(load(ap))
		if not frames.is_empty():
			attack_sprites[k] = frames


func _walk_key(key: String) -> String:
	if walk_sprites.has(key):
		return key
	return Art.cardinal_from_dir(aim_dir)


func _apply_facing(delta: float) -> void:
	if body_sprite == null:
		return
	var key := Art.pick_facing(aim_dir, facing_sprites)
	facing_key = key
	var tex: Texture2D = null
	if attacking:
		var ak := Art.pick_facing(aim_dir, attack_sprites)
		if not attack_sprites.has(ak):
			ak = Art.cardinal_from_dir(aim_dir)
		if not attack_sprites.has(ak):
			ak = "down"
		if attack_sprites.has(ak):
			var frames: Array = attack_sprites[ak]
			attack_t += delta
			var adv := int(attack_t * ATTACK_FPS)
			if adv >= frames.size():
				attacking = false
				attack_t = 0.0
				attack_i = 0
			else:
				attack_i = adv
				tex = frames[attack_i]
	var planar := Vector2(velocity.x, velocity.z)
	var moving := planar.length() > V3.u(28.0) and dash_timer <= 0.0 and not attacking
	if tex == null and moving:
		var wk := _walk_key(key)
		if walk_sprites.has(wk):
			var frames: Array = walk_sprites[wk]
			walk_t += delta
			walk_i = int(walk_t * WALK_FPS) % frames.size()
			tex = frames[walk_i]
	if tex == null:
		if facing_sprites.has(key):
			tex = facing_sprites[key]
		elif facing_sprites.has("down"):
			tex = facing_sprites["down"]
		walk_t = 0.0
		walk_i = 0
	if tex:
		V3.apply_sprite_tex(body_sprite, tex, BODY_H)


func _cooldowns(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	iframe = maxf(0.0, iframe - delta)
	if Game.run:
		Game.run.potion_cd = maxf(0.0, Game.run.potion_cd - delta)
		Game.run.shrine_buff_t = maxf(0.0, Game.run.shrine_buff_t - delta)


func _update_aim(move: Vector2) -> void:
	if target_mode:
		return
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.35:
		aim_dir = stick.normalized()
		return
	if Input.get_connected_joypads().is_empty():
		var cam := get_viewport().get_camera_3d()
		var mdir := V3.mouse_xz(cam, global_position)
		if mdir.length() > 0.01:
			aim_dir = mdir
			return
	if move.length() > 0.2:
		aim_dir = move.normalized()


func _toggle_target() -> void:
	target_mode = not target_mode
	if target_mode:
		current_target = _nearest_enemy()
		if current_target == null:
			target_mode = false
	else:
		current_target = null


func _cycle_target() -> void:
	var x := Input.get_axis("aim_left", "aim_right")
	if absf(x) < 0.7:
		return
	if not has_meta("flick_lock"):
		set_meta("flick_lock", 0.0)
	if float(get_meta("flick_lock")) > 0.0:
		set_meta("flick_lock", float(get_meta("flick_lock")) - get_physics_process_delta_time())
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b):
		var ax := 0.0
		var bx := 0.0
		if a is Node3D:
			ax = (a as Node3D).global_position.x
		if b is Node3D:
			bx = (b as Node3D).global_position.x
		return ax < bx
	)
	var idx := enemies.find(current_target)
	idx = clampi(idx, 0, enemies.size() - 1)
	idx = (idx + (1 if x > 0.0 else -1) + enemies.size()) % enemies.size()
	current_target = enemies[idx]
	set_meta("flick_lock", 0.25)


func _nearest_enemy() -> Node:
	var best: Node = null
	var best_d := 99999.0
	var origin := V3.xz(global_position)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D):
			continue
		var d: float = origin.distance_to(V3.xz((e as Node3D).global_position))
		if d < best_d:
			best_d = d
			best = e
	return best


func _weapon() -> ItemData:
	if Game.run and Game.run.weapon:
		return Game.run.weapon
	return ItemData.make_starter_axe()


func _try_attack() -> void:
	if attack_cd > 0.0:
		return
	if Game.run == null or Game.run.weapon == null:
		return
	var w := _weapon()
	attack_cd = w.attack_period
	var dmg: float = w.damage * SkillMath.axe_damage_mult(Game.skill_level("great_axe")) * SkillMath.strength_mult(Game.skill_level("strength"))
	if Game.run:
		dmg *= Game.run.dmg_mult
		if Game.run.shrine_buff_t > 0.0:
			dmg *= 1.2
	attacking = true
	attack_t = 0.0
	attack_i = 0
	Sfx.play("hit")
	_hit_in_arc(dmg, AXE_RANGE)
	Game.grant_xp("great_axe", 4.0)
	Game.grant_xp("strength", 1.2)


func _can_hit(node: Node, max_range: float, check_arc: bool) -> bool:
	if not is_instance_valid(node) or not (node is Node3D):
		return false
	var to: Vector2 = V3.xz((node as Node3D).global_position) - V3.xz(global_position)
	var dist := to.length()
	if dist > max_range or dist < 0.001:
		return false
	if check_arc and absf(aim_dir.angle_to(to.normalized())) > AXE_ARC:
		return false
	var dungeon := get_tree().current_scene
	if dungeon and dungeon.get("data") is Dictionary:
		var grid: PackedByteArray = dungeon.data.get("grid", PackedByteArray())
		if not grid.is_empty() and not V3.los(grid, global_position, (node as Node3D).global_position):
			return false
	return true


func _hit_in_arc(dmg: float, max_range: float, check_arc: bool = true, slam := false) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if _can_hit(e, max_range, check_arc) and e.has_method("take_damage"):
			var st := 0.0
			if slam:
				st = 0.25 if bool(e.get("is_boss")) else 0.5
			e.take_damage(dmg, self, st)
	for b in get_tree().get_nodes_in_group("hittable"):
		if _can_hit(b, max_range, check_arc) and b.has_method("take_damage"):
			b.take_damage(dmg, self)


func _try_slam() -> bool:
	if slam_cd > 0.0:
		return false
	if Game.run == null or Game.run.weapon == null:
		return false
	slam_cd = SLAM_CD
	attack_cd = maxf(attack_cd, 0.4)
	Sfx.play("slam")
	var dmg: float = _weapon().damage * 1.6 * SkillMath.axe_damage_mult(Game.skill_level("great_axe")) * SkillMath.strength_mult(Game.skill_level("strength"))
	if Game.run:
		dmg *= Game.run.dmg_mult * Game.run.slam_dmg_mult
		if Game.run.shrine_buff_t > 0.0:
			dmg *= 1.2
	_hit_in_arc(dmg, SLAM_RADIUS, false, true)
	Game.grant_xp("great_axe", 10.0)
	Game.grant_xp("strength", 3.0)
	return true


func _try_interact() -> void:
	var best: Node = null
	var best_d := V3.INTERACT_R
	var origin := V3.xz(global_position)
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not n.has_method("interact"):
			continue
		var d: float = origin.distance_to(V3.xz((n as Node3D).global_position))
		if d < best_d:
			best_d = d
			best = n
	if best:
		best.interact(self)


func start_channel(node: Node, duration: float) -> void:
	channeling = node
	channel_t = 0.0
	channel_need = duration


func _process_channel(delta: float) -> void:
	if channeling == null or not is_instance_valid(channeling):
		channeling = null
		return
	if Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("slam"):
		channeling = null
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move.length() > 0.25:
		channeling = null
		return
	channel_t += delta
	if channel_t >= channel_need:
		if channeling.has_method("complete_channel"):
			channeling.complete_channel(self)
		if is_instance_valid(channeling) and channeling.has_method("can_channel") and channeling.can_channel():
			channel_t = 0.0
			channel_need = channeling.channel_time(self) if channeling.has_method("channel_time") else 1.8
		else:
			channeling = null


func interrupt_channel() -> void:
	channeling = null
	channel_t = 0.0


func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if iframe > 0.0:
		return
	if not Game.in_dungeon or Game.run == null:
		return
	interrupt_channel()
	flash = 0.12
	iframe = 0.08
	if from_pos != Vector2.INF:
		var k := V3.xz(global_position) - from_pos
		if k.length() > 0.01:
			knock = Vector3(k.x, 0.0, k.y).normalized() * V3.u(280.0)
			knock_t = 0.12
	Sfx.play("hurt")
	var taken := amount
	if Game.run:
		var def := Game.run.total_defense()
		taken = amount * (100.0 / (100.0 + def))
	V3.spawn_float(get_parent(), global_position, taken)
	Game.hitstop(0.045)
	Game.grant_xp("hitpoints", 2.4)
	Game.grant_xp("defense", 1.1)
	Game.damage_player(amount)


func begin_death() -> void:
	if dying:
		return
	dying = true
	interrupt_channel()
	velocity = Vector3.ZERO
	if body_sprite:
		body_sprite.modulate = Color(0.55, 0.45, 0.48)
		body_sprite.rotation_degrees.z = 18.0
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.add_child(fade)
	get_tree().root.add_child(layer)
	var tw := create_tween()
	tw.tween_interval(1.15)
	tw.tween_property(fade, "color:a", 1.0, 0.55)
	tw.tween_callback(func():
		layer.queue_free()
		Game.end_run(false)
	)


func _use_consumable(family: String) -> void:
	if Game.run == null:
		return
	if family == "potion":
		if Game.run.potion == null:
			Game.toast("No potion equipped.", Color(0.9, 0.7, 0.55))
			return
		if Game.run.potion_cd > 0.0:
			return
		Game.heal_player(Game.run.potion.heal)
		Game.run.potion_cd = Game.run.potion.potion_cd
		return
	var it := Game.run.consume_family(family)
	if it == null:
		Game.toast("No food in the bag.", Color(0.9, 0.7, 0.55))
		return
	Game.heal_player(it.heal)
	Game.bag_changed.emit()


func channel_ratio() -> float:
	if channeling == null or channel_need <= 0.0:
		return 0.0
	return clampf(channel_t / channel_need, 0.0, 1.0)


func slam_ratio() -> float:
	return 1.0 - clampf(slam_cd / SLAM_CD, 0.0, 1.0)


func dash_ratio() -> float:
	var m := DASH_CD * (Game.run.dash_cd_mult if Game.run else 1.0)
	if m <= 0.001:
		return 1.0
	return 1.0 - clampf(dash_cd / m, 0.0, 1.0)
