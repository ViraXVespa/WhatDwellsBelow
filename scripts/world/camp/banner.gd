extends Object

## Split from camp.gd: _banner, _banner_pole.

static func _banner(host: Node3D) -> void:
	var root := Node3D.new()
	root.position = host._layout.spot_pos("Banner")
	host.add_child(root)
	_banner_pole(root, Vector3(-1.45, 1.1, 0.0))
	_banner_pole(root, Vector3(1.45, 1.1, 0.0))
	var spr := Sprite3D.new()
	var path := "res://assets/sprites/props/welcome_banner.png"
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
		spr.pixel_size = 4.4 / float(maxi(1, spr.texture.get_height()))
	spr.position = Vector3(0.0, 2.2, 0.0)
	root.add_child(spr)

static func _banner_pole(root: Node3D, pos: Vector3) -> void:
	var pole := StaticBody3D.new()
	pole.collision_layer = 1
	pole.position = pos
	root.add_child(pole)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.28, 2.2, 0.28)
	cs.shape = sh
	pole.add_child(cs)
