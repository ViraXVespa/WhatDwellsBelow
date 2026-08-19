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
var facing_key := "down"

var dash_cd_max := DASH_CD
var slam_cd_max := SLAM_CD


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(40, 40)
	cs.shape = sh
	add_child(cs)
	body_sprite = Sprite2D.new()
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.scale = Vector2(0.78, 0.78)
	add_child(body_sprite)
	_load_facings()
	_apply_facing()
	last_pos = global_position


func _physics_process(delta: float) -> void:
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
		velocity = move * SPEED
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and move.length() + aim_dir.length() > 0.0:
			dash_timer = DASH_TIME
			dash_cd = DASH_CD
			iframe = DASH_TIME
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
	_apply_facing()
	if flash > 0.0:
		flash -= delta
		modulate = Color(1.6, 0.7, 0.7)
	else:
		modulate = Color.WHITE


func _load_facings() -> void:
	var paths := {
		"down": "res://assets/sprites/player/down.png",
		"up": "res://assets/sprites/player/up.png",
		"left": "res://assets/sprites/player/left.png",
		"right": "res://assets/sprites/player/right.png",
	}
	for k in paths:
		if ResourceLoader.exists(paths[k]):
			facing_sprites[k] = load(paths[k])
	if facing_sprites.is_empty():
		facing_sprites["down"] = Art.body(Vector2i(64, 64), Color(0.24, 0.49, 0.72), Color(0.94, 0.84, 0.38))


func _apply_facing() -> void:
	var key := "down"
	if absf(aim_dir.x) > absf(aim_dir.y):
		key = "right" if aim_dir.x > 0.0 else "left"
	else:
		key = "down" if aim_dir.y >= 0.0 else "up"
	if key == facing_key and body_sprite.texture != null:
		return
	facing_key = key
	if facing_sprites.has(key):
		body_sprite.texture = facing_sprites[key]
	elif facing_sprites.has("down"):
		body_sprite.texture = facing_sprites["down"]


func _cooldowns(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	iframe = maxf(0.0, iframe - delta)
	if Game.run:
		Game.run.potion_cd = maxf(0.0, Game.run.potion_cd - delta)


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
	var w := _weapon()
	attack_cd = w.attack_period
	var dmg := w.damage
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to: Vector2 = e.global_position - global_position
		var dist := to.length()
		if dist > AXE_RANGE or dist < 0.001:
			continue
		if absf(aim_dir.angle_to(to.normalized())) <= AXE_ARC:
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
	if Game.run:
		Game.run.great_axe_xp_run += 4.0
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


func _try_slam() -> bool:
	if slam_cd > 0.0:
		return false
	slam_cd = SLAM_CD
	attack_cd = maxf(attack_cd, 0.4)
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= SLAM_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(_weapon().damage * 1.6, self)
	var ring := Polygon2D.new()
	ring.color = Color(0.9, 0.7, 0.2, 0.35)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * SLAM_RADIUS)
	ring.polygon = pts
	add_child(ring)
	get_tree().create_timer(0.18).timeout.connect(ring.queue_free)
	if Game.run:
		Game.run.great_axe_xp_run += 10.0
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
	Game.damage_player(amount)


func _use_consumable(family: String) -> void:
	if Game.run == null:
		return
	if family == "potion" and Game.run.potion_cd > 0.0:
		return
	var it := Game.run.consume_family(family)
	if it == null:
		return
	Game.heal_player(it.heal)
	Game.bag_changed.emit()
	if family == "potion":
		Game.run.potion_cd = 8.0


func _regen(delta: float) -> void:
	if Game.run == null or not Game.in_dungeon:
		return
	if Game.run.hp <= 0.0:
		return
	Game.run.hp = minf(Game.run.max_hp, Game.run.hp + REGEN * delta)
	Game.run.mana = minf(Game.run.max_mana, Game.run.mana + 2.0 * delta)


func channel_ratio() -> float:
	if channeling == null or channel_need <= 0.0:
		return 0.0
	return clampf(channel_t / channel_need, 0.0, 1.0)


func dash_ratio() -> float:
	return 1.0 - clampf(dash_cd / DASH_CD, 0.0, 1.0)


func slam_ratio() -> float:
	return 1.0 - clampf(slam_cd / SLAM_CD, 0.0, 1.0)
