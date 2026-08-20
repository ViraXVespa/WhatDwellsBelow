class_name Player
extends CharacterBody2D

const SPEED := 190.0
const DASH_SPEED := 620.0
const DASH_TIME := 0.16
const DASH_CD := 1.15
const SLAM_CD := 5.0
const SLAM_RADIUS := 176.0
const AXE_RANGE := 118.0
const AXE_ARC := 0.96
const REGEN := 0.5

var aim_dir := Vector2.DOWN
var target_mode := false
var current_target: Node2D = null
var dash_timer := 0.0
var dash_cd := 0.0
var slam_cd := 0.0
var attack_cd := 0.0
var iframe := 0.0
var channeling: Node = null
var channel_t := 0.0
var channel_need := 1.8
var last_pos := Vector2.ZERO
var body_sprite: Sprite2D
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
const WALK_FPS := 8.0
const ATTACK_FPS := 10.0

var dash_cd_max := DASH_CD
var slam_cd_max := SLAM_CD


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(32, 40)
	cs.shape = sh
	cs.position = Vector2.ZERO
	add_child(cs)
	body_sprite = Art.make_sprite(null, 0.78)
	add_child(body_sprite)
	_load_facings()
	_apply_facing(0.016)
	last_pos = global_position


func _physics_process(delta: float) -> void:
	if dying:
		return
	if get_tree().paused:
		return
	_cooldowns(delta)
	if channeling:
		_process_channel(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_aim(move)
	if dash_timer > 0.0:
		velocity = aim_dir * DASH_SPEED
		dash_timer -= delta
		iframe = maxf(iframe, dash_timer)
	else:
		var spd := SPEED
		if Game.run:
			spd *= Game.run.move_mult
		velocity = move * spd
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and move.length() + aim_dir.length() > 0.0:
			dash_timer = DASH_TIME
			dash_cd = DASH_CD * (Game.run.dash_cd_mult if Game.run else 1.0)
			iframe = DASH_TIME
			Sfx.play("dash")
			if move.length() > 0.2:
				aim_dir = move.normalized()
	move_and_slide()
	if Input.is_action_just_pressed("target_lock"):
		_toggle_target()
	if target_mode:
		_cycle_target()
		if is_instance_valid(current_target):
			aim_dir = (current_target.global_position - global_position).normalized()
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
	_regen(delta)
	_apply_facing(delta)
	if flash > 0.0:
		flash -= delta
		modulate = Color(1.6, 0.7, 0.7)
	else:
		modulate = Color.WHITE


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
	for k in ["down", "up", "left", "right"]:
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
	var key := Art.pick_facing(aim_dir, facing_sprites)
	facing_key = key
	var tex: Texture2D = null
	if attacking:
		var ak := Art.cardinal_from_dir(aim_dir)
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
	var moving := velocity.length() > 28.0 and dash_timer <= 0.0 and not attacking
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
	Art.apply_tex(body_sprite, tex, true)


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
		var mdelta := get_global_mouse_position() - global_position
		if mdelta.length() > 16.0:
			aim_dir = mdelta.normalized()
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
	enemies.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var idx := enemies.find(current_target)
	idx = clampi(idx, 0, enemies.size() - 1)
	idx = (idx + (1 if x > 0.0 else -1) + enemies.size()) % enemies.size()
	current_target = enemies[idx]
	set_meta("flick_lock", 0.25)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 99999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
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
	var dmg := w.damage * Skills.axe_damage_mult(Game.skill_level("great_axe"))
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
	_swing_flash()


func _swing_flash() -> void:
	var poly := Polygon2D.new()
	poly.color = Color(0.95, 0.85, 0.4, 0.45)
	var r := AXE_RANGE
	var pts := PackedVector2Array([Vector2.ZERO])
	var start := aim_dir.angle() - AXE_ARC
	var steps := 8
	for i in steps + 1:
		var a := start + AXE_ARC * 2.0 * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	add_child(poly)
	var tw := get_tree().create_timer(0.12)
	tw.timeout.connect(poly.queue_free)


func _can_hit(node: Node2D, max_range: float, check_arc: bool) -> bool:
	if not is_instance_valid(node):
		return false
	var to: Vector2 = node.global_position - global_position
	var dist := to.length()
	if dist > max_range or dist < 0.001:
		return false
	if check_arc and absf(aim_dir.angle_to(to.normalized())) > AXE_ARC:
		return false
	var dungeon := get_tree().current_scene
	if dungeon and dungeon.get("data") is Dictionary:
		var grid: PackedByteArray = dungeon.data.get("grid", PackedByteArray())
		if not grid.is_empty() and not DungeonGen.world_has_los(grid, global_position, node.global_position):
			return false
	return true


func _hit_in_arc(dmg: float, max_range: float, check_arc: bool = true, slam := false) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and _can_hit(e, max_range, check_arc) and e.has_method("take_damage"):
			var st := 0.0
			if slam:
				st = 0.25 if bool(e.get("is_boss")) else 0.5
			e.take_damage(dmg, self, st)
	for b in get_tree().get_nodes_in_group("hittable"):
		if b is Node2D and _can_hit(b, max_range, check_arc) and b.has_method("take_damage"):
			b.take_damage(dmg, self)


func _try_slam() -> bool:
	if slam_cd > 0.0:
		return false
	if Game.run == null or Game.run.weapon == null:
		return false
	slam_cd = SLAM_CD
	attack_cd = maxf(attack_cd, 0.4)
	Sfx.play("slam")
	var dmg := _weapon().damage * 1.6 * Skills.axe_damage_mult(Game.skill_level("great_axe"))
	if Game.run:
		dmg *= Game.run.dmg_mult * Game.run.slam_dmg_mult
		if Game.run.shrine_buff_t > 0.0:
			dmg *= 1.2
	_hit_in_arc(dmg, SLAM_RADIUS, false, true)
	var ring := Polygon2D.new()
	ring.color = Color(0.9, 0.7, 0.2, 0.35)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * SLAM_RADIUS)
	ring.polygon = pts
	add_child(ring)
	get_tree().create_timer(0.18).timeout.connect(ring.queue_free)
	Game.grant_xp("great_axe", 10.0)
	return true


func _try_interact() -> void:
	var best: Interactable = null
	var best_d := 72.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable:
			var d: float = global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	if best:
		best.interact(self)


func start_channel(node: Node, duration: float) -> void:
	channeling = node
	channel_t = 0.0
	channel_need = duration
	last_pos = global_position


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


func take_damage(amount: float) -> void:
	if iframe > 0.0:
		return
	if not Game.in_dungeon or Game.run == null:
		return
	interrupt_channel()
	flash = 0.12
	iframe = 0.08
	Sfx.play("hurt")
	var n := FloatNum.new()
	n.global_position = global_position + Vector2(0, -40)
	var taken := amount
	if Game.run:
		var def := Game.run.total_defense()
		taken = amount * (100.0 / (100.0 + def))
	n.setup(taken)
	if get_parent():
		get_parent().add_child(n)
	Game.hitstop(0.045)
	Game.damage_player(amount)


func begin_death() -> void:
	if dying:
		return
	dying = true
	interrupt_channel()
	velocity = Vector2.ZERO
	rotation = 0.35
	modulate = Color(0.55, 0.45, 0.48)
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
		return
	Game.heal_player(it.heal)
	Game.bag_changed.emit()


func _regen(delta: float) -> void:
	if Game.run == null or not Game.in_dungeon:
		return
	if Game.run.hp <= 0.0:
		return
	Game.run.hp = minf(Game.run.max_hp, Game.run.hp + REGEN * delta)


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
