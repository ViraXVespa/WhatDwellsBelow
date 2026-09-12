extends Object

## Player spawn / sprite / collision setup.

const T := preload("res://scripts/data/tunables.gd")
const CamRig := preload("res://scripts/world/camera_rig.gd")
const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const AimLineS := preload("res://scripts/combat/aim_line.gd")
const PlayerAnim := preload("res://scripts/world/player_anim.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")


static func ready(host: CharacterBody3D) -> void:
	host.add_to_group("player")
	host.collision_layer = 2
	host.collision_mask = 1
	host.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	host.axis_lock_linear_y = true
	add_body_shape(host)
	PlayerAnim.load_sprites(host)
	host.body = make_sprite(host, 2)
	host.body.visible = false
	host.add_child(host.body)
	host.aura = make_sprite(host, 3)
	host.aura.visible = false
	host.aura.modulate = Color(1.0, 0.45, 0.12, 0.0)
	host.aura.pixel_size = 0.018
	host.add_child(host.aura)
	host.rig = CamRig.new()
	host.rig.name = "CamRig"
	host.add_child(host.rig)
	if host.rig.has_method("follow"):
		host.rig.follow(host.global_position)
	host.telegraph = TelegraphS.new()
	host.add_child(host.telegraph)
	host.telegraph.hide_now()
	host.aim_line = AimLineS.new()
	host.add_child(host.aim_line)
	host.max_hp = App.bal.player_max_hp + App.prog.gear_hp() + App.prog.skill_hp()
	if App.run_hp >= 0.0:
		host.hp = clampf(App.run_hp, 0.0, host.max_hp)
	else:
		host.hp = host.max_hp
	PlayerAnim.apply_tex(host, PlayerAnim.pose_tex(host, "down"))
	PlayerAnim.apply_facing(host, 0.016)
	if host.body:
		host.body.visible = true

static func make_sprite(_host: CharacterBody3D, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.centered = true
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.alpha_scissor_threshold = 0.4
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.render_priority = prio
	return SpriteFilt.decorate(s)

static func add_body_shape(host: CharacterBody3D) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = T.PLAYER_BODY
	cs.shape = sh
	cs.position = Vector3(0.0, T.PLAYER_BODY.y * 0.5, 0.08)
	host.add_child(cs)