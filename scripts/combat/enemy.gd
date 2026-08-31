extends CharacterBody3D

const Combat := preload("res://scripts/combat/combat.gd")
const Depth := preload("res://scripts/world/depth.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")
const Facing := preload("res://scripts/world/facing.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const Threat := preload("res://scripts/combat/threat.gd")
const HpBarS := preload("res://scripts/combat/hp_bar.gd")
const EnemySetup := preload("res://scripts/combat/enemy_setup.gd")
const EnemyAI := preload("res://scripts/combat/enemy_ai.gd")

const ST_IDLE := 0
const ST_CHASE := 1
const ST_HUNT := 2
const ST_RETURN := 3
const ST_WIND := 4
const ST_STRIKE := 5
const ST_REC := 6
const ST_FLEE := 7

var type_id := "goblin"
var combat_lv := 1
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
	EnemySetup.setup(self, id, floor_n, named, given_name)


func setup_boss(title: String, floor_n: int) -> void:
	EnemySetup.setup_boss(self, title, floor_n)


func setup_guard(id: String, floor_n: int) -> void:
	setup(id, floor_n, false, "")


func _mark_post() -> void:
	post = global_position
	last_seen = global_position
	last_pos = global_position


func take_hit(raw: float, from_dir: Vector2, crit: bool) -> void:
	if dead:
		return
	var dmg: float = App.bal.apply_defense(raw, defense)
	dmg *= Threat.received_mult(combat_lv)
	if crit:
		dmg *= App.bal.crit_mult
		flash = 0.16
	else:
		flash = 0.08
	hp = maxf(0.0, hp - dmg)
	HpBarS.pulse(self, hp, max_hp, combat_lv)
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
	HpBarS.pulse(self, 0.0, max_hp, combat_lv)
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


func force_kill() -> void:
	hp = 0.0
	_die()


func is_alive() -> bool:
	return not dead and hp > 0.0


func start_flee() -> void:
	EnemyAI.start_flee(self)


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
	EnemyAI.tick(self, delta)
	move_and_slide()
	global_position.y = 0.0
	EnemyAI.stuck(self, delta)
	_present(delta)


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


func kill_tag() -> String:
	if is_boss:
		var title := str(tag.text) if tag else ""
		return "gate_master" if title.begins_with("Gate Master") else "guardian"
	return type_id


func _drop_loot() -> void:
	var host := get_parent()
	if host == null:
		return
	var gold_n := int(App.bal.enemy_gold_base) + randi() % maxi(1, int(App.bal.enemy_gold_span) + mini(4, App.floor_n))
	if is_boss:
		gold_n += int(App.bal.boss_gold_extra)
	var PickupS := load("res://scripts/world/pickup.gd")
	var g: Node3D = PickupS.new()
	host.add_child(g)
	g.setup("gold", global_position + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), gold_n)
	if is_boss:
		return
	if randf() < App.bal.enemy_gear_chance + App.bal.enemy_gear_floor * float(App.floor_n):
		var rarity := "white"
		if randf() < App.bal.enemy_gear_green:
			rarity = "green"
		var item := App.prog.make_armor(["head", "body", "legs"][randi() % 3], rarity)
		if not App.prog.add_item(item):
			App.spawn_floor_item(item, global_position)
		else:
			App.toast(str(item.name))
			App.sfx("pickup")


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
