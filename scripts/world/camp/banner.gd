extends Object

## Split from camp.gd: _banner, _banner_pole.

## Art, height and pole feet: layout_spec.gd BANNER (Layout.banner_poles() for the overlay).
const Spec := preload("res://scripts/world/camp/layout_spec.gd")

static func _banner(host: Node3D) -> void:
	var root := Node3D.new()
	root.position = host._layout.spot_pos("Banner")
	host.add_child(root)
	var pole: Vector3 = Spec.BANNER["pole"]
	for x: float in [-float(Spec.BANNER["pole_x"]), float(Spec.BANNER["pole_x"])]:
		_banner_pole(root, Vector3(x, pole.y * 0.5, 0.0), pole)
	var spr := Sprite3D.new()
	var path: String = Spec.BANNER["tex"]
	if ResourceLoader.exists(path):
		spr.texture = load(path)
	elif ResourceLoader.exists("res://assets/sprites/props/banner.png"):
		spr.texture = load("res://assets/sprites/props/banner.png")
	spr.centered = true
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if spr.texture:
		spr.pixel_size = float(Spec.BANNER["h"]) / float(maxi(1, spr.texture.get_height()))
	spr.position = Vector3(0.0, float(Spec.BANNER["h"]) * 0.5, 0.0)
	root.add_child(spr)
	# Same hard mark as the player (camp_build.mark_props); kept out of the bake.
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	load("res://scripts/graphics/actor_lit.gd").bind(root, spr)

static func _banner_pole(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var pole := StaticBody3D.new()
	pole.collision_layer = 1
	pole.position = pos
	root.add_child(pole)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	pole.add_child(cs)
