extends CharacterBody3D

const V3 := preload("res://scripts/view3d/v3.gd")
const ProjS := preload("res://scripts/view3d/projectile_3d.gd")

enum Phase { CHASE, WINDUP, LUNGE, RECOVER }

var role := "bruiser"
var hp := 30.0
var max_hp := 30.0
var move_speed := 70.0 / 64.0
var contact_damage := 10.0
var attack_cd := 0.0
var attack_period := 1.35
var range_melee := 78.0 / 64.0
var lunge_range := 130.0 / 64.0
var windup_time := 0.48
var lunge_time := 0.20
var recover_time := 0.45
var lunge_speed := 420.0 / 64.0
var shoot_cd := 0.0
var flash := 0.0
var rng := RandomNumberGenerator.new()
var prefer_left := true
var stuck_t := 0.0
var phase: int = Phase.CHASE
var phase_t := 0.0
var lunge_dir := Vector2.DOWN
var hit_this_lunge := false
var body_sprite: Sprite3D
var hp_lab: Label3D
var sprites: Dictionary = {}
var walk_frames: Dictionary = {}
var walk_t := 0.0
var walk_i := 0
const WALK_FPS := 8.0
const BODY_H := 1.12
var facing := "down"
var aim := Vector2.DOWN
var is_boss := false
var aware := false
var last_seen := Vector3.ZERO
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
			move_speed = 55.0 / 64.0
			contact_damage = 11.0 + floor_number * 1.6
			attack_period = 1.15
			windup_time = 0.55
			lunge_time = 0.14
			recover_time = 0.4
		"tank":
			hp = 100.0 + floor_number * 22.0
			move_speed = 36.0 / 64.0
			contact_damage = 18.0 + floor_number * 2.2
			attack_period = 1.7
			range_melee = 86.0 / 64.0
			lunge_range = 110.0 / 64.0
			windup_time = 0.72
			lunge_time = 0.18
			recover_time = 0.7
			lunge_speed = 340.0 / 64.0
		_:
			hp = 62.0 + floor_number * 16.0
			move_speed = 68.0 / 64.0
			contact_damage = 16.0 + floor_number * 2.0
			attack_period = 1.25
			range_melee = 78.0 / 64.0
			lunge_range = 140.0 / 64.0
			windup_time = 0.42
			lunge_time = 0.22
			recover_time = 0.4
			lunge_speed = 460.0 / 64.0
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
	lunge_speed = 400.0 / 64.0
	range_melee = 96.0 / 64.0
	if body_sprite:
		V3.apply_sprite_tex(body_sprite, body_sprite.texture, BODY_H * 1.22)
	var tag := Label3D.new()
	tag.text = "GUARDIAN"
	tag.position = Vector3(0, 1.85, 0)
	tag.font_size = 28
	tag.outline_size = 6
	tag.modulate = Color(0.95, 0.78, 0.25)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.012
	tag.no_depth_test = true
	add_child(tag)
	_refresh_hp()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	axis_lock_linear_y = true
	V3.add_cyl(self, 0.28, 0.7, Vector3(0, 0.35, 0))


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
			var path := "res://assets/3d/enemies/%s/%s_%s.png" % [folder, pose, dir]
			if ResourceLoader.exists(path):
				sprites["%s_%s" % [pose, dir]] = load(path)
	for dir in ["down", "up", "left", "right"]:
		var frames: Array = []
		for i in 8:
			var wp := "res://assets/3d/enemies/%s/walk_%s_%d.png" % [folder, dir, i]
			if ResourceLoader.exists(wp):
				frames.append(load(wp))
		if not frames.is_empty():
			walk_frames[dir] = frames


func _build_visual() -> void:
	var tex: Texture2D = sprites.get("idle_down", null)
	if tex == null:
		var col := Color(0.72, 0.22, 0.22)
		if role == "ranged":
			col = Color(0.28, 0.62, 0.32)
		elif role == "tank":
			col = Color(0.28, 0.32, 0.72)
		tex = Art.body(Vector2i(64, 64), col, col.lightened(0.3))
	body_sprite = V3.sprite(tex, BODY_H, true)
	add_child(body_sprite)
	hp_lab = Label3D.new()
	hp_lab.position = Vector3(0, 1.35, 0)
	hp_lab.font_size = 22
	hp_lab.outline_size = 6
	hp_lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_lab.pixel_size = 0.011
	hp_lab.no_depth_test = true
	add_child(hp_lab)
	_apply_sprite()
	_refresh_hp()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if stagger_t > 0.0:
		stagger_t -= delta
		velocity = velocity.move_toward(Vector3.ZERO, V3.u(800.0) * delta)
		move_and_slide()
		global_position.y = 0.0
		_refresh_hp()
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	if flash > 0.0:
		flash -= delta
	var player := _player()
	if player == null:
		return
	var to := V3.xz(player.global_position) - V3.xz(global_position)
	var dist := to.length()
	var los := _has_los(player)
	if _world_is_safe(player.global_position):
		los = false
	if los and dist < V3.u(460.0):
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
	if body_sprite:
		if flash > 0.0:
			body_sprite.modulate = Color(1.5, 1.5, 1.5)
		elif phase == Phase.WINDUP:
			var pulse := 0.85 + 0.15 * sin(phase_t * 28.0)
			body_sprite.modulate = Color(1.15, pulse, pulse)
		else:
			body_sprite.modulate = Color.WHITE
	_refresh_hp()
	global_position.y = 0.0


func _ai_ranged(delta: float, player: Node3D, to: Vector2, dist: float, los: bool) -> void:
	match phase:
		Phase.CHASE:
			if not aware and not los:
				velocity = Vector3.ZERO
				move_and_slide()
				return
			var chase_to := to if los else (V3.xz(last_seen) - V3.xz(global_position))
			var steer := _steer(chase_to, los)
			if los and dist < V3.u(140.0):
				velocity = Vector3(-to.x, 0.0, -to.y).normalized() * move_speed
			elif (los and dist > V3.u(220.0)) or not los:
				velocity = Vector3(steer.x, 0.0, steer.y) * move_speed
			else:
				velocity = Vector3.ZERO
			velocity = _block_safe_step(velocity)
			if los and dist < V3.u(420.0) and dist > V3.u(70.0) and shoot_cd <= 0.0:
				phase = Phase.WINDUP
				phase_t = 0.0
				lunge_dir = aim
				velocity = Vector3.ZERO
			move_and_slide()
			_stuck(delta)
		Phase.WINDUP:
			velocity = Vector3.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= windup_time:
				if player and not _world_is_safe(player.global_position):
					_shoot(lunge_dir)
				phase = Phase.LUNGE
				phase_t = 0.0
		Phase.LUNGE:
			velocity = Vector3.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= lunge_time:
				phase = Phase.RECOVER
				phase_t = 0.0
		Phase.RECOVER:
			velocity = Vector3.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= recover_time:
				phase = Phase.CHASE
				shoot_cd = attack_period


func _ai_melee(delta: float, player: Node3D, to: Vector2, dist: float, los: bool) -> void:
	match phase:
		Phase.CHASE:
			if not aware and not los:
				velocity = Vector3.ZERO
				move_and_slide()
				return
			var chase_to := to if los else (V3.xz(last_seen) - V3.xz(global_position))
			var steer := _steer(chase_to, los)
			if los and dist <= range_melee and attack_cd <= 0.0:
				phase = Phase.WINDUP
				phase_t = 0.0
				lunge_dir = aim
				velocity = Vector3.ZERO
			else:
				velocity = Vector3(steer.x, 0.0, steer.y) * move_speed
			velocity = _block_safe_step(velocity)
			move_and_slide()
			_stuck(delta)
		Phase.WINDUP:
			velocity = Vector3.ZERO
			move_and_slide()
			phase_t += delta
			if phase_t >= windup_time:
				phase = Phase.LUNGE
				phase_t = 0.0
				hit_this_lunge = false
		Phase.LUNGE:
			velocity = _block_safe_step(Vector3(lunge_dir.x, 0.0, lunge_dir.y) * lunge_speed)
			move_and_slide()
			phase_t += delta
			if not hit_this_lunge and V3.xz(global_position).distance_to(V3.xz(player.global_position)) <= V3.u(46.0):
				if player.has_method("take_damage"):
					player.take_damage(contact_damage, V3.xz(global_position))
				hit_this_lunge = true
			if phase_t >= lunge_time:
				phase = Phase.RECOVER
				phase_t = 0.0
				velocity = Vector3.ZERO
		Phase.RECOVER:
			velocity = Vector3.ZERO
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
	var planar := Vector2(get_real_velocity().x, get_real_velocity().z)
	var moving := pose == "idle" and planar.length() > V3.u(18.0)
	var wdir := facing
	if not walk_frames.has(wdir):
		wdir = Art.cardinal_from_dir(aim)
	if moving and walk_frames.has(wdir):
		var frames: Array = walk_frames[wdir]
		walk_t += delta
		walk_i = int(walk_t * WALK_FPS) % frames.size()
		V3.apply_sprite_tex(body_sprite, frames[walk_i], BODY_H * (1.22 if is_boss else 1.0))
		return
	walk_t = 0.0
	walk_i = 0
	var key := "%s_%s" % [pose, facing]
	if sprites.has(key):
		V3.apply_sprite_tex(body_sprite, sprites[key], BODY_H * (1.22 if is_boss else 1.0))
		return
	var idle_key := "idle_%s" % facing
	if sprites.has(idle_key):
		V3.apply_sprite_tex(body_sprite, sprites[idle_key], BODY_H * (1.22 if is_boss else 1.0))


func _steer(to_player: Vector2, los: bool) -> Vector2:
	if to_player.length() < 0.001:
		return Vector2.ZERO
	var desired := to_player.normalized()
	if los:
		return desired
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(desired.x, 0.0, desired.y) * V3.u(56.0))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return desired
	var n: Vector3 = hit.get("normal", Vector3.UP)
	n.y = 0.0
	if n.length() < 0.1:
		n = Vector3(-desired.x, 0.0, -desired.y)
	n = n.normalized()
	var tangent := Vector2(-n.z, n.x)
	if prefer_left:
		tangent = -tangent
	if tangent.dot(desired) < 0.0:
		tangent = -tangent
	return (tangent * 0.85 + Vector2(n.x, n.z) * 0.25).normalized()


func _has_los(target: Node3D) -> bool:
	var dungeon := get_tree().current_scene
	if dungeon and dungeon.get("data") is Dictionary:
		var grid: PackedByteArray = dungeon.data.get("grid", PackedByteArray())
		if not grid.is_empty() and not V3.los(grid, global_position, target.global_position):
			return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.45, 0), target.global_position + Vector3(0, 0.45, 0))
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col = hit.get("collider")
	return col == target or (col is Node and (col as Node).is_in_group("player"))


func _shoot(dir: Vector2) -> void:
	var p = ProjS.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(dir.x, 0.45, dir.y) * 0.45
	p.setup(dir, contact_damage)


func _stuck(delta: float) -> void:
	var real_v := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if Vector2(velocity.x, velocity.z).length() > V3.u(10.0) and real_v < V3.u(12.0):
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
	V3.spawn_float(get_parent(), global_position, amount)
	if _from is Node3D:
		var src := _from as Node3D
		last_seen = src.global_position
		var k := V3.xz(global_position) - V3.xz(src.global_position)
		if k.length() > 0.01:
			var kn := k.normalized()
			velocity = Vector3(kn.x, 0.0, kn.y) * V3.u(220.0)
	Game.hitstop(0.05)
	if hp <= 0.0:
		_die()
	else:
		_refresh_hp()


func _refresh_hp() -> void:
	if hp_lab == null:
		return
	hp_lab.text = "%d/%d" % [int(hp), int(max_hp)]
	var ratio := 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	hp_lab.modulate = Color(0.92, 0.58, 0.18) if ratio <= 0.35 else Color(0.95, 0.35, 0.32)


func _world_is_safe(world: Vector3) -> bool:
	var dungeon := get_tree().current_scene
	if dungeon == null or not (dungeon.get("data") is Dictionary):
		return false
	var rooms = dungeon.data.get("safe_rooms", [])
	var t := Vector2i(int(world.x), int(world.z))
	for r in rooms:
		if r is Rect2i and (r as Rect2i).has_point(t):
			return true
	return false


func _block_safe_step(vel: Vector3) -> Vector3:
	if vel.length() < 0.01:
		return vel
	var next := global_position + vel.normalized() * V3.u(28.0)
	if _world_is_safe(next) and not _world_is_safe(global_position):
		return Vector3.ZERO
	return vel


func _die() -> void:
	if Game.run:
		var gold_amt := rng.randi_range(3, 12) + Game.run.current_floor
		var drop_at := V3.xz(global_position)
		if is_boss:
			gold_amt = rng.randi_range(40, 70) + Game.run.current_floor * 8
			Game.grant_xp("great_axe", 40.0)
			var drop := LootGen.roll_gear("great_axe", rng)
			Game.give_or_drop(drop, drop_at)
			var art_s = load("res://scripts/data/artifacts.gd")
			for _i in 2:
				if rng.randf() < 0.5:
					var art: Dictionary = art_s.pick(rng, Game.run.artifact_ids)
					Game.give_artifact(str(art.id))
		else:
			Game.grant_xp("great_axe", 8.0)
			if rng.randf() < 0.16:
				var fam := "great_axe" if rng.randf() < 0.65 else "pickaxe"
				var drop := LootGen.roll_gear(fam, rng)
				Game.give_or_drop(drop, drop_at)
		Game.add_run_gold(gold_amt)
	queue_free()


func _player() -> Node3D:
	var n := get_tree().get_first_node_in_group("player")
	return n as Node3D
