class_name Enemy
extends CharacterBody2D

enum Phase { CHASE, WINDUP, LUNGE, RECOVER }

var role := "bruiser"
var hp := 30.0
var max_hp := 30.0
var move_speed := 70.0
var contact_damage := 10.0
var attack_cd := 0.0
var attack_period := 1.35
var range_melee := 78.0
var lunge_range := 130.0
var windup_time := 0.48
var lunge_time := 0.20
var recover_time := 0.45
var lunge_speed := 420.0
var shoot_cd := 0.0
var flash := 0.0
var rng := RandomNumberGenerator.new()
var prefer_left := true
var stuck_t := 0.0
var phase: int = Phase.CHASE
var phase_t := 0.0
var lunge_dir := Vector2.DOWN
var hit_this_lunge := false
var body_sprite: Sprite2D
var hp_bg: ColorRect
var hp_fg: ColorRect
var sprites: Dictionary = {}
var walk_frames: Dictionary = {}
var walk_t := 0.0
var walk_i := 0
const WALK_FPS := 8.0
var facing := "down"
var aim := Vector2.DOWN
var is_boss := false
var aware := false
var last_seen := Vector2.ZERO
var lost_t := 0.0
var stagger_t := 0.0


func setup(p_role: String, floor_number: int, p_boss: bool = false) -> void:
	role = p_role
	is_boss = p_boss
	rng.randomize()
	prefer_left = rng.randf() < 0.5
	match role:
		"ranged":
			hp = 48.0 + floor_number * 10.0
			move_speed = 55.0
			contact_damage = 11.0 + floor_number * 1.6
			attack_period = 1.15
			windup_time = 0.55
			lunge_time = 0.14
			recover_time = 0.4
		"tank":
			hp = 100.0 + floor_number * 22.0
			move_speed = 36.0
			contact_damage = 18.0 + floor_number * 2.2
			attack_period = 1.7
			range_melee = 86.0
			lunge_range = 110.0
			windup_time = 0.72
			lunge_time = 0.18
			recover_time = 0.7
			lunge_speed = 340.0
		_:
			hp = 62.0 + floor_number * 16.0
			move_speed = 68.0
			contact_damage = 16.0 + floor_number * 2.0
			attack_period = 1.25
			range_melee = 78.0
			lunge_range = 140.0
			windup_time = 0.42
			lunge_time = 0.22
			recover_time = 0.4
			lunge_speed = 460.0
	max_hp = hp
	_load_sprites()
	_build_visual()
	if is_boss:
		_apply_boss()


func _apply_boss() -> void:
	add_to_group("boss")
	hp = 320.0 + float(Game.run.current_floor) * 70.0 if Game.run else 400.0
	max_hp = hp
	contact_damage = 26.0 + (float(Game.run.current_floor) if Game.run else 3.0) * 2.0
	windup_time = 0.62
	lunge_time = 0.24
	recover_time = 0.55
	lunge_speed = 400.0
	range_melee = 96.0
	if body_sprite:
		body_sprite.scale = Vector2(1.22, 1.22)
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			(c.shape as RectangleShape2D).size = Vector2(52, 52)
	var tag := Label.new()
	tag.text = "GUARDIAN"
	tag.position = Vector2(-48, -70)
	tag.size = Vector2(96, 18)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.95, 0.78, 0.25))
	tag.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	tag.add_theme_constant_override("outline_size", 4)
	add_child(tag)
	_refresh_hp_bar()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(32, 36)
	cs.shape = sh
	cs.position = Vector2.ZERO
	add_child(cs)


func _folder() -> String:
	if role == "tank":
		return "tank"
	if role == "ranged":
		return "ranged"
	return "bruiser"


func _load_sprites() -> void:
	var folder := _folder()
	for pose in ["idle", "windup", "strike"]:
		for dir in Art.FACING_KEYS:
			var path := "res://assets/sprites/enemies/%s/%s_%s.png" % [folder, pose, dir]
			if ResourceLoader.exists(path):
				sprites["%s_%s" % [pose, dir]] = load(path)
	for dir in ["down", "up", "left", "right"]:
		var frames: Array = []
		for i in 8:
			var wp := "res://assets/sprites/enemies/%s/walk_%s_%d.png" % [folder, dir, i]
			if ResourceLoader.exists(wp):
				frames.append(load(wp))
		if not frames.is_empty():
			walk_frames[dir] = frames


func _build_visual() -> void:
	body_sprite = Art.make_sprite(null, 0.82)
	body_sprite.name = "Body"
	add_child(body_sprite)
	_apply_sprite()
	_build_hp_bar()
	if body_sprite.texture == null:
		var col := Color(0.72, 0.22, 0.22)
		if role == "ranged":
			col = Color(0.28, 0.62, 0.32)
		elif role == "tank":
			col = Color(0.28, 0.32, 0.72)
		Art.apply_tex(body_sprite, Art.body(Vector2i(64, 64), col, col.lightened(0.3)))


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if stagger_t > 0.0:
		stagger_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		_refresh_hp_bar()
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	if flash > 0.0:
		flash -= delta
	var player := _player()
	if player == null:
		return
	var to: Vector2 = player.global_position - global_position
	var dist := to.length()
	var los := _has_los(player)
	if los and dist < 460.0:
		aware = true
		last_seen = player.global_position
		lost_t = 0.0
	elif aware:
		lost_t += delta
		if lost_t > 2.2:
			aware = false
	if los and to.length() > 0.01 and phase == Phase.CHASE:
		aim = to.normalized()
		_update_facing(aim)
	if role == "ranged":
		_ai_ranged(delta, player, to, dist, los)
	else:
		_ai_melee(delta, player, to, dist, los)
	_apply_sprite(delta)
	if flash > 0.0:
		modulate = Color(1.5, 1.5, 1.5)
	elif phase == Phase.WINDUP:
		var pulse := 0.85 + 0.15 * sin(phase_t * 28.0)
		modulate = Color(1.15, pulse, pulse)
	else:
		modulate = Color.WHITE
	_refresh_hp_bar()


func _ai_ranged(delta: float, _player: Player, to: Vector2, dist: float, los: bool) -> void:
	match phase:
		Phase.CHASE:
			if not aware and not los:
				velocity = Vector2.ZERO
				move_and_slide()
				return
			var chase_to := to if los else (last_seen - global_position)
			var steer := _steer(chase_to, los)
			if los and dist < 140.0:
				velocity = -to.normalized() * move_speed
			elif (los and dist > 220.0) or not los:
				velocity = steer * move_speed
			else:
				velocity = Vector2.ZERO
			if los and dist < 420.0 and dist > 70.0 and shoot_cd <= 0.0:
				phase = Phase.WINDUP
				phase_t = 0.0
				lunge_dir = aim
				velocity = Vector2.ZERO
			move_and_slide()
			_stuck(delta)
		Phase.WINDUP:
			velocity = Vector2.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= windup_time:
				_shoot(lunge_dir)
				phase = Phase.LUNGE
				phase_t = 0.0
		Phase.LUNGE:
			velocity = Vector2.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= lunge_time:
				phase = Phase.RECOVER
				phase_t = 0.0
		Phase.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= recover_time:
				phase = Phase.CHASE
				shoot_cd = attack_period


func _ai_melee(delta: float, player: Player, to: Vector2, dist: float, los: bool) -> void:
	match phase:
		Phase.CHASE:
			if not aware and not los:
				velocity = Vector2.ZERO
				move_and_slide()
				return
			var chase_to := to if los else (last_seen - global_position)
			var steer := _steer(chase_to, los)
			if los and dist <= range_melee and attack_cd <= 0.0:
				phase = Phase.WINDUP
				phase_t = 0.0
				lunge_dir = aim
				velocity = Vector2.ZERO
			else:
				velocity = steer * move_speed
			move_and_slide()
			_stuck(delta)
		Phase.WINDUP:
			velocity = Vector2.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= windup_time:
				phase = Phase.LUNGE
				phase_t = 0.0
				hit_this_lunge = false
		Phase.LUNGE:
			velocity = lunge_dir * lunge_speed
			move_and_slide()
			phase_t += delta
			if not hit_this_lunge and global_position.distance_to(player.global_position) <= 46.0:
				player.take_damage(contact_damage, global_position)
				hit_this_lunge = true
			if phase_t >= lunge_time:
				phase = Phase.RECOVER
				phase_t = 0.0
				velocity = Vector2.ZERO
		Phase.RECOVER:
			velocity = Vector2.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= recover_time:
				phase = Phase.CHASE
				attack_cd = attack_period


func _update_facing(dir: Vector2) -> void:
	facing = Art.pick_facing(dir, sprites, _pose_name() + "_")


func _pose_name() -> String:
	match phase:
		Phase.WINDUP:
			return "windup"
		Phase.LUNGE:
			return "strike"
		_:
			return "idle"


func _apply_sprite(delta := 0.016) -> void:
	if body_sprite == null:
		return
	var pose := _pose_name()
	var moving := pose == "idle" and get_real_velocity().length() > 18.0
	var wdir := facing
	if not walk_frames.has(wdir):
		wdir = Art.cardinal_from_dir(aim)
	if moving and walk_frames.has(wdir):
		var frames: Array = walk_frames[wdir]
		walk_t += delta
		walk_i = int(walk_t * WALK_FPS) % frames.size()
		Art.apply_tex(body_sprite, frames[walk_i], true)
		return
	walk_t = 0.0
	walk_i = 0
	var key := "%s_%s" % [pose, facing]
	if sprites.has(key):
		Art.apply_tex(body_sprite, sprites[key], true)
		return
	var idle_key := "idle_%s" % facing
	if sprites.has(idle_key):
		Art.apply_tex(body_sprite, sprites[idle_key], true)


func _steer(to_player: Vector2, los: bool) -> Vector2:
	if to_player.length() < 0.001:
		return Vector2.ZERO
	var desired := to_player.normalized()
	if los:
		return desired
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + desired * 56.0)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return desired
	var n: Vector2 = hit.get("normal", Vector2.UP)
	if n.length() < 0.1:
		n = -desired
	var tangent := Vector2(-n.y, n.x)
	if prefer_left:
		tangent = -tangent
	if tangent.dot(desired) < 0.0:
		tangent = -tangent
	return (tangent * 0.85 + n * 0.25).normalized()


func _has_los(target: Node2D) -> bool:
	var dungeon := get_tree().current_scene
	if dungeon and dungeon.get("data") is Dictionary:
		var grid: PackedByteArray = dungeon.data.get("grid", PackedByteArray())
		if not grid.is_empty() and not DungeonGen.world_has_los(grid, global_position, target.global_position):
			return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col = hit.get("collider")
	return col == target or (col is Node and (col as Node).is_in_group("player"))


func _shoot(dir: Vector2) -> void:
	var p := Projectile.new()
	p.global_position = global_position + dir * 28.0
	p.setup(dir, contact_damage)
	get_parent().add_child(p)


func _stuck(delta: float) -> void:
	var real_v := get_real_velocity().length()
	if velocity.length() > 10.0 and real_v < 12.0:
		stuck_t += delta
		if stuck_t > 0.3:
			prefer_left = not prefer_left
			stuck_t = 0.0
	else:
		stuck_t = 0.0


func take_damage(amount: float, _from: Node = null, stagger := 0.0) -> void:
	hp -= amount
	flash = 0.08
	aware = true
	if stagger > 0.0:
		stagger_t = maxf(stagger_t, stagger)
	if is_boss and Game.run and hp / max_hp <= 0.25:
		Game.run.guardian_low = true
	var n := FloatNum.new()
	n.global_position = global_position + Vector2(0, -36)
	n.setup(amount)
	if get_parent():
		get_parent().add_child(n)
	if _from is Node2D:
		var src := _from as Node2D
		last_seen = src.global_position
		var k := (global_position - src.global_position).normalized()
		velocity = k * 220.0
	Game.hitstop(0.05)
	if hp <= 0.0:
		_die()
	else:
		_refresh_hp_bar()


func _build_hp_bar() -> void:
	var w := 42.0 if not is_boss else 56.0
	var y := -46.0 if not is_boss else -80.0
	hp_bg = ColorRect.new()
	hp_bg.size = Vector2(w, 5)
	hp_bg.position = Vector2(-w * 0.5, y)
	hp_bg.color = Color(0.08, 0.08, 0.1, 0.92)
	hp_bg.z_index = 12
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bg)
	hp_fg = ColorRect.new()
	hp_fg.size = Vector2(w, 5)
	hp_fg.position = Vector2(-w * 0.5, y)
	hp_fg.color = Color(0.82, 0.22, 0.2)
	hp_fg.z_index = 13
	hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_fg)


func _refresh_hp_bar() -> void:
	if hp_bg == null or hp_fg == null:
		return
	var w: float = hp_bg.size.x
	var ratio := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	hp_fg.size = Vector2(w * ratio, 5)
	hp_fg.color = Color(0.92, 0.58, 0.18) if ratio <= 0.35 else Color(0.82, 0.22, 0.2)


func _die() -> void:
	if Game.run:
		var gold_amt := rng.randi_range(3, 12) + Game.run.current_floor
		if is_boss:
			gold_amt = rng.randi_range(40, 70) + Game.run.current_floor * 8
			Game.grant_xp("great_axe", 40.0)
			var drop := LootGen.roll_gear("great_axe", rng)
			Game.give_or_drop(drop, global_position)
			if rng.randf() < 0.5:
				var art_s = load("res://scripts/data/artifacts.gd")
				var art: Dictionary = art_s.pick(rng, Game.run.artifact_ids)
				Game.give_artifact(str(art.id))
		else:
			Game.grant_xp("great_axe", 8.0)
			if rng.randf() < 0.16:
				var fam := "great_axe" if rng.randf() < 0.65 else "pickaxe"
				var drop := LootGen.roll_gear(fam, rng)
				Game.give_or_drop(drop, global_position)
		Game.add_run_gold(gold_amt)
	queue_free()


func _player() -> Player:
	var n := get_tree().get_first_node_in_group("player")
	return n as Player
