extends CharacterBody3D

const Combat := preload("res://scripts/combat/combat.gd")
const Depth := preload("res://scripts/world/depth.gd")
const FloatS := preload("res://scripts/combat/float_num.gd")
const T := preload("res://scripts/data/tunables.gd")

var hp := 80.0
var max_hp := 80.0
var defense := 0.0
var flash := 0.0
var stagger := 0.0
var knock := Vector3.ZERO
var knock_t := 0.0
var dead := false
var spr: Sprite3D
var is_boss := false
var tag := Label3D.new()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	axis_lock_linear_y = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.5, 1.1, 0.4)
	cs.shape = sh
	cs.position = Vector3(0.0, 0.55, 0.0)
	add_child(cs)
	hp = App.bal.dummy_hp
	max_hp = hp
	defense = App.bal.dummy_defense
	spr = Sprite3D.new()
	spr.centered = true
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.render_priority = 1
	var path := "res://assets/fx/dummy.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		var th := float(maxi(1, spr.texture.get_height()))
		spr.pixel_size = 1.7 / th
	spr.position.y = 0.85
	add_child(spr)
	tag.position = Vector3(0.0, 1.7, 0.0)
	tag.font_size = 36
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.011
	tag.visible = false
	add_child(tag)


func setup_boss(title: String, floor_n: int) -> void:
	is_boss = true
	add_to_group("boss")
	var cycle := int((maxi(1, floor_n) - 1) / 5)
	var mult: float = App.bal.boss_hp_mult * (1.0 + App.bal.cycle_hp * float(cycle))
	if title == "Gate Master":
		mult *= 1.35
	hp = App.bal.dummy_hp * mult
	max_hp = hp
	defense = App.bal.dummy_defense + 8.0 + float(cycle) * 4.0
	spr.pixel_size *= 1.35
	spr.position.y *= 1.2
	spr.modulate = Color(1.15, 0.7, 0.55) if title != "Gate Master" else Color(0.7, 0.55, 1.15)
	tag.text = title
	tag.visible = true
	tag.modulate = Color(1.0, 0.82, 0.35)


func setup_guard() -> void:
	hp = App.bal.dummy_hp * 0.85
	max_hp = hp
	spr.modulate = Color(0.95, 0.55, 0.45)
	tag.text = "Base"
	tag.visible = true
	tag.modulate = Color(0.95, 0.45, 0.35)
	tag.font_size = 28


func force_kill() -> void:
	hp = 0.0
	_die()


func is_alive() -> bool:
	return not dead and hp > 0.0


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
	n.position = global_position + Vector3(0.0, 1.35, 0.0)
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
	collision_layer = 0
	if is_boss:
		App.notify_boss_dead()
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.22)
	tw.finished.connect(queue_free)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if stagger > 0.0:
		stagger -= delta
		velocity = Vector3.ZERO
	elif knock_t > 0.0:
		knock_t -= delta
		velocity = knock
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	global_position.y = 0.0
	if spr:
		Depth.apply(spr, global_position)
		if flash > 0.0:
			flash -= delta
			spr.modulate = Color(1.7, 1.7, 1.7) if flash > 0.0 else Color.WHITE
		else:
			spr.modulate = Color.WHITE
