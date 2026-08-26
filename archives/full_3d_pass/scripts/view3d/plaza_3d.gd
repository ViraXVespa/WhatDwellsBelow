extends Node3D

const V3 := preload("res://scripts/view3d/v3.gd")
const Player3D := preload("res://scripts/view3d/player_3d.gd")
const Interact3D := preload("res://scripts/view3d/interact_3d.gd")

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
	cam = V3.attach_cam(self)
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
		add_child(V3.tile_mm(V3.a("tiles", "plaza_grass.png"), grass_p, V3.FLOOR_Y))
	if not ga_p.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "plaza_ground.png"), ga_p, V3.FLOOR_Y))
	if not gb_p.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "plaza_ground_b.png"), gb_p, V3.FLOOR_Y))


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
		V3.block(walls, Vector2(ng.position.x, ng.position.z), Vector2(1.72, 0.34), Vector2(0.0, -0.12))
		var sg := V3.sprite(gate, float(gate.get_height()) / V3.PX, false)
		V3.plant(sg, Vector2(float(gx) + 0.5, float(FY1) + 0.85))
		add_child(sg)
		V3.block(walls, Vector2(sg.position.x, sg.position.z), Vector2(1.72, 0.34), Vector2(0.0, -0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var planted: Array[Vector2] = []
	for i in 28:
		var tx: int
		var ty: int
		if rng.randf() < 0.5:
			tx = rng.randi_range(0, 3) if rng.randf() < 0.5 else rng.randi_range(W - 4, W - 1)
			ty = rng.randi_range(0, H - 1)
		else:
			tx = rng.randi_range(0, W - 1)
			ty = rng.randi_range(0, 3) if rng.randf() < 0.5 else rng.randi_range(H - 4, H - 1)
		var pos := Vector2(float(tx) + 0.5 + rng.randf_range(-0.16, 0.16), float(ty) + 0.85)
		var too_close := false
		for other: Vector2 in planted:
			if pos.distance_to(other) < 1.2:
				too_close = true
				break
		if too_close:
			continue
		var use_tree := tree != null and rng.randf() < 0.55
		var tex: Texture2D = tree if use_tree else bush
		if tex == null:
			continue
		var sc := rng.randf_range(0.85, 1.05) if use_tree else rng.randf_range(0.75, 0.95)
		var spr := V3.sprite(tex, float(tex.get_height()) / V3.PX * sc, true)
		V3.plant(spr, pos)
		add_child(spr)
		planted.append(pos)
		V3.block(walls, pos, Vector2(0.28, 0.22) if use_tree else Vector2(0.25, 0.19), Vector2(0.0, -0.09), 1.0)
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
	var world_h := float(tex.get_height()) / V3.PX
	var s := V3.sprite(tex, world_h, false)
	var world_w: float = float(tex.get_width()) * s.pixel_size
	if world_w > 0.98:
		s.pixel_size *= 0.98 / world_w
		s.position.y = float(tex.get_height()) * s.pixel_size * 0.5 + V3.FEET_LIFT
	var planted := foot
	if horiz:
		planted.y += float(int(foot.x) % 2) * 0.008
	else:
		planted.x += float(int(foot.y) % 2) * 0.008
	V3.plant(s, planted)
	if not horiz:
		s.rotation_degrees.y = 90.0
	add_child(s)
	if horiz:
		V3.block(walls, foot, Vector2(0.98, 0.22), Vector2(0.0, -0.09), 0.9)
	else:
		V3.block(walls, foot, Vector2(0.28, 0.75), Vector2(0.0, -0.09), 0.9)


func _buildings() -> void:
	var guild := _place_cutout(V3.a("buildings", "guild.png"), Vector2(9.4, 11.2), 0.88)
	if guild:
		V3.block(walls, Vector2(guild.position.x, guild.position.z), Vector2(2.34, 0.66), Vector2(0.0, -0.25), 1.6)
	var wing := _place_cutout(V3.a("buildings", "guild_reception.png"), Vector2(15.0, 11.4), 1.0)
	if wing:
		var fp := Vector2(wing.position.x, wing.position.z)
		V3.block(walls, fp, Vector2(3.12, 0.28), Vector2(0.0, -1.72), 1.8)
		V3.block(walls, fp, Vector2(0.28, 1.41), Vector2(-1.44, -0.78), 1.8)
		V3.block(walls, fp, Vector2(0.28, 1.41), Vector2(1.44, -0.78), 1.8)
		V3.block(walls, fp, Vector2(1.09, 0.25), Vector2(0.0, -0.91), 1.4)
	var stall := _place_cutout(V3.a("buildings", "stall.png"), Vector2(28.4, 11.3), 0.92)
	if stall:
		V3.block(walls, Vector2(stall.position.x, stall.position.z), Vector2(3.12, 0.44), Vector2(0.0, -0.19), 1.4)


func _prop(kind: String, xz: Vector2, tex := "", extra: Dictionary = {}) -> void:
	var n = Interact3D.make(kind, tex, extra)
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
