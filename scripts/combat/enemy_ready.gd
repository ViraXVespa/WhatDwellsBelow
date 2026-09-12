extends Object

## Enemy node spawn / label / telegraph setup.

const TelegraphS := preload("res://scripts/combat/telegraph.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")


static func ready(host: CharacterBody3D) -> void:
	host.add_to_group("enemies")
	host.collision_layer = 4
	host.collision_mask = 1
	host.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	host.axis_lock_linear_y = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.48, 1.05, 0.38)
	cs.shape = sh
	cs.position = Vector3(0.0, 0.52, 0.0)
	host.add_child(cs)
	host.spr = Sprite3D.new()
	host.spr.centered = true
	host.spr.shaded = false
	host.spr.double_sided = true
	host.spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	host.spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	host.spr.render_priority = 1
	host.spr = SpriteFilt.decorate(host.spr)
	host.add_child(host.spr)
	host.tag = Label3D.new()
	host.tag.position = Vector3(0.0, 1.55, 0.0)
	host.tag.font_size = 34
	host.tag.outline_size = 10
	host.tag.outline_modulate = Color(0, 0, 0)
	host.tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	host.tag.no_depth_test = true
	host.tag.pixel_size = 0.011
	host.tag.visible = false
	host.add_child(host.tag)
	host.bang = Label3D.new()
	host.bang.text = "!"
	host.bang.position = Vector3(0.0, 1.85, 0.0)
	host.bang.font_size = 64
	host.bang.outline_size = 12
	host.bang.modulate = Color(1.0, 0.92, 0.2)
	host.bang.outline_modulate = Color(0.05, 0.04, 0.02)
	host.bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	host.bang.no_depth_test = true
	host.bang.pixel_size = 0.014
	host.bang.visible = false
	host.add_child(host.bang)
	host.telegraph = TelegraphS.new()
	host.add_child(host.telegraph)
	host.telegraph.hide_now()