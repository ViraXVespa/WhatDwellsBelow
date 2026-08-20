extends Node3D

const V3 := preload("res://archives/art_experiment/scripts/view3d/v3.gd")
const Player3D := preload("res://archives/art_experiment/scripts/view3d/player_3d.gd")
const Interact3D := preload("res://archives/art_experiment/scripts/view3d/interact_3d.gd")

const W := 40
const H := 28
const FX0 := 4
const FX1 := 35
const FY0 := 4
const FY1 := 23

var cam: Camera3D
var walls: StaticBody3D


func _ready() -> void:
	V3.add_world(self, false)
	_build_ground()
	walls = V3.wall_body(self, "PlazaWalls")
	_outer_walls()
	_fence_and_trees()
	_buildings()
	_props()
	var player = Player3D.new()
	player.position = Vector3(20.0, 0.0, 14.0)
	add_child(player)
	cam = Camera3D.new()
	add_child(cam)
	V3.apply_cam(cam)
	V3.follow_cam(cam, player.global_position)
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(LoadoutUI.new())
	add_child(AnvilUI.new())


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D and cam:
		V3.follow_cam(cam, (p as Node3D).global_position)


func _build_ground() -> void:
	var grass_p: Array = []
	var ga_p: Array = []
	var gb_p: Array = []
	var yard := Rect2i(5, 5, 30, 18)
	for y in H:
		for x in W:
			var pos := V3.tile_center(x, y)
			if yard.has_point(Vector2i(x, y)):
				if (x * 3 + y) % 7 == 0:
					gb_p.append(pos)
				else:
					ga_p.append(pos)
			else:
				grass_p.append(pos)
	if not grass_p.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "plaza_grass.png"), grass_p, 0.0))
	if not ga_p.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "plaza_ground.png"), ga_p, 0.0))
	if not gb_p.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "plaza_ground_b.png"), gb_p, 0.0))


func _outer_walls() -> void:
	V3.add_box(walls, Vector3(float(W), 2.0, 1.0), Vector3(float(W) * 0.5, 1.0, 0.5))
	V3.add_box(walls, Vector3(float(W), 2.0, 1.0), Vector3(float(W) * 0.5, 1.0, float(H) - 0.5))
	V3.add_box(walls, Vector3(1.0, 2.0, float(H)), Vector3(0.5, 1.0, float(H) * 0.5))
	V3.add_box(walls, Vector3(1.0, 2.0, float(H)), Vector3(float(W) - 0.5, 1.0, float(H) * 0.5))


func _place_cutout(path: String, foot: Vector2, scale: float) -> Sprite3D:
	var tex := Art.load_tex(path)
	if tex == null:
		return null
	var h := float(tex.get_height()) / V3.PX * scale
	var s := V3.sprite(tex, h, false)
	V3.plant(s, foot)
	add_child(s)
	return s


func _fence_and_trees() -> void:
	var fence := Art.load_tex(V3.a("props", "fence.png"))
	var gate := Art.load_tex(V3.a("props", "gate.png"))
	var tree := Art.load_tex(V3.a("props", "tree.png"))
	var bush := Art.load_tex(V3.a("props", "bush.png"))
	var gx := 20
	for x in range(FX0, FX1 + 1):
		if absi(x - gx) <= 1:
			continue
		_fence_seg(Vector2(float(x) + 0.5, float(FY0) + 0.55), fence, true)
		_fence_seg(Vector2(float(x) + 0.5, float(FY1) + 0.55), fence, true)
	for y in range(FY0 + 1, FY1):
		_fence_seg(Vector2(float(FX0) + 0.5, float(y) + 0.55), fence, false)
		_fence_seg(Vector2(float(FX1) + 0.5, float(y) + 0.55), fence, false)
	if gate:
		var ng := V3.sprite(gate, float(gate.get_height()) / V3.PX, false)
		V3.plant(ng, Vector2(float(gx) + 0.5, float(FY0) + 0.85))
		add_child(ng)
		V3.block_px(walls, Vector2(ng.position.x, ng.position.z), Vector2(110, 22), Vector2(0, -8))
		var sg := V3.sprite(gate, float(gate.get_height()) / V3.PX, false)
		V3.plant(sg, Vector2(float(gx) + 0.5, float(FY1) + 0.85))
		add_child(sg)
		V3.block_px(walls, Vector2(sg.position.x, sg.position.z), Vector2(110, 22), Vector2(0, -8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 28:
		var tx: int
		var ty: int
		if rng.randf() < 0.5:
			tx = rng.randi_range(0, 3) if rng.randf() < 0.5 else rng.randi_range(W - 4, W - 1)
			ty = rng.randi_range(0, H - 1)
		else:
			tx = rng.randi_range(0, W - 1)
			ty = rng.randi_range(0, 3) if rng.randf() < 0.5 else rng.randi_range(H - 4, H - 1)
		var pos := Vector2(float(tx) + 0.5 + rng.randf_range(-10, 10) / V3.PX, float(ty) + 0.85)
		var use_tree := tree != null and rng.randf() < 0.55
		var tex: Texture2D = tree if use_tree else bush
		if tex == null:
			continue
		var sc := rng.randf_range(0.85, 1.05) if use_tree else rng.randf_range(0.75, 0.95)
		var spr := V3.sprite(tex, float(tex.get_height()) / V3.PX * sc, true)
		V3.plant(spr, pos)
		add_child(spr)
		V3.block_px(walls, pos, Vector2(18, 14) if use_tree else Vector2(16, 12), Vector2(0, -6), 1.0)
	var banner := Art.load_tex(V3.a("props", "banner.png"))
	if banner:
		var b := V3.sprite(banner, float(banner.get_height()) / V3.PX * 0.95, false)
		V3.plant(b, Vector2(float(gx) + 0.5, float(FY1) - 0.2))
		add_child(b)
		var lab := Label3D.new()
		lab.text = "Welcome to Placeholdia!"
		lab.font_size = 42
		lab.outline_size = 8
		lab.modulate = Color(0.22, 0.14, 0.08)
		lab.outline_modulate = Color(0.95, 0.88, 0.65)
		lab.pixel_size = 0.012
		lab.position = Vector3(0, 1.55, 0.02)
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		b.add_child(lab)


func _fence_seg(foot: Vector2, tex: Texture2D, horiz: bool) -> void:
	if tex == null:
		return
	var s := V3.sprite(tex, float(tex.get_height()) / V3.PX, false)
	V3.plant(s, foot)
	if not horiz:
		s.rotation_degrees.y = 90.0
	add_child(s)
	if horiz:
		V3.block_px(walls, foot, Vector2(72, 14), Vector2(0, -6), 0.9)
	else:
		V3.block_px(walls, foot, Vector2(18, 48), Vector2(0, -6), 0.9)


func _buildings() -> void:
	var guild := _place_cutout(V3.a("buildings", "guild.png"), Vector2(9.4, 11.2), 0.88)
	if guild:
		V3.block_px(walls, Vector2(guild.position.x, guild.position.z), Vector2(150, 42), Vector2(0, -16), 1.6)
	var wing := _place_cutout(V3.a("buildings", "guild_reception.png"), Vector2(15.0, 11.4), 1.0)
	if wing:
		var fp := Vector2(wing.position.x, wing.position.z)
		V3.block_px(walls, fp, Vector2(200, 18), Vector2(0, -110), 1.8)
		V3.block_px(walls, fp, Vector2(18, 90), Vector2(-92, -50), 1.8)
		V3.block_px(walls, fp, Vector2(18, 90), Vector2(92, -50), 1.8)
		V3.block_px(walls, fp, Vector2(70, 16), Vector2(0, -58), 1.4)
	var stall := _place_cutout(V3.a("buildings", "stall.png"), Vector2(28.4, 11.3), 0.92)
	if stall:
		V3.block_px(walls, Vector2(stall.position.x, stall.position.z), Vector2(200, 28), Vector2(0, -12), 1.4)


func _prop(kind: String, xz: Vector2, tex := "", extra: Dictionary = {}) -> void:
	var n = Interact3D.new()
	n.configure(kind, tex, extra)
	n.position = Vector3(xz.x, 0.0, xz.y)
	add_child(n)


func _props() -> void:
	_prop("town_crystal", Vector2(20.0, 9.2), V3.a("props", "crystal.png"))
	_prop("receptionist", Vector2(15.0, 10.55))
	_prop("sign", Vector2(7.2, 12.4), V3.a("props", "sign.png"), {
		"title": "Guild notice",
		"body": "Diver board. Pack food. Mail ore. Don't die with a full bag if you can help it.",
	})
	_prop("vendor", Vector2(28.4, 12.0))
	_prop("anvil", Vector2(8.2, 18.2), V3.a("props", "anvil.png"))
	_prop("sign", Vector2(30.2, 18.4), V3.a("props", "dumpster.png"), {
		"title": "Dumpster",
		"body": "You used to eat from this. Career upgrade pending.",
	})
	_prop("sign", Vector2(18.5, 16.6), V3.a("props", "notice_board.png"), {
		"title": "Notice board",
		"body": "Hold RT / LMB to swing.\nB / Space dash.\nX / Shift slam.\nA / E talk.\nD-pad Up / 1 potion.\nD-pad Left / 2 food.\nStart / Esc pause bag.\nSelect / M map (in the hole).\nLB / RB pause tabs.",
	})
