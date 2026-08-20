extends Node2D

const TILE := 64
const W := 40
const H := 28
const FX0 := 4
const FX1 := 35
const FY0 := 4
const FY1 := 23


func _ready() -> void:
	y_sort_enabled = true
	_build_ground()
	_walls()
	_fence_and_trees()
	_buildings()
	_props()
	var player := Player.new()
	player.position = Vector2(20 * TILE, 14 * TILE)
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * TILE
	cam.limit_bottom = H * TILE
	player.add_child(cam)
	Game.apply_cam(cam)
	cam.make_current()
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(LoadoutUI.new())
	add_child(AnvilUI.new())


func _build_ground() -> void:
	var vis := Node2D.new()
	vis.z_index = -8
	vis.y_sort_enabled = false
	add_child(vis)
	vis.set_script(preload("res://archives/classic_2d/scripts/hub/plaza_draw.gd"))
	vis.queue_redraw()


func _walls() -> void:
	var body := StaticBody2D.new()
	body.name = "PlazaWalls"
	body.collision_layer = 1
	body.y_sort_enabled = false
	add_child(body)
	# Outer world box so nobody walks into the void.
	for r in [
		Rect2(0, 0, W * TILE, TILE),
		Rect2(0, (H - 1) * TILE, W * TILE, TILE),
		Rect2(0, 0, TILE, H * TILE),
		Rect2((W - 1) * TILE, 0, TILE, H * TILE),
	]:
		_add_wall_rect(body, r)


func _add_wall_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)


func _block(foot: Vector2, size: Vector2, local := Vector2.ZERO) -> void:
	var walls := get_node("PlazaWalls") as StaticBody2D
	if walls == null:
		return
	_add_wall_rect(walls, Rect2(foot + local - size * 0.5, size))


func _place_tex(path: String, foot: Vector2, scale: float) -> Sprite2D:
	var tex := Art.load_tex(path)
	if tex == null:
		return null
	var s := Art.foot_sprite(tex, scale)
	s.position = foot
	add_child(s)
	return s


func _fence_and_trees() -> void:
	var fence := Art.load_tex("res://assets/sprites/props/fence.png")
	var gate := Art.load_tex("res://assets/sprites/props/gate.png")
	var tree := Art.load_tex("res://assets/sprites/props/tree.png")
	var bush := Art.load_tex("res://assets/sprites/props/bush.png")
	var gx := 20
	for x in range(FX0, FX1 + 1):
		if absi(x - gx) <= 1:
			continue
		_fence_seg(Vector2((x + 0.5) * TILE, (FY0 + 0.55) * TILE), fence, true)
		_fence_seg(Vector2((x + 0.5) * TILE, (FY1 + 0.55) * TILE), fence, true)
	for y in range(FY0 + 1, FY1):
		_fence_seg(Vector2((FX0 + 0.5) * TILE, (y + 0.55) * TILE), fence, false)
		_fence_seg(Vector2((FX1 + 0.5) * TILE, (y + 0.55) * TILE), fence, false)
	if gate:
		var ng := Art.foot_sprite(gate, 1.0)
		ng.position = Vector2((gx + 0.5) * TILE, (FY0 + 0.85) * TILE)
		add_child(ng)
		_block(ng.position, Vector2(110, 22), Vector2(0, -8))
		var sg := Art.foot_sprite(gate, 1.0)
		sg.position = Vector2((gx + 0.5) * TILE, (FY1 + 0.85) * TILE)
		add_child(sg)
		_block(sg.position, Vector2(110, 22), Vector2(0, -8))
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
		var pos := Vector2((tx + 0.5) * TILE + rng.randf_range(-10, 10), (ty + 0.85) * TILE)
		var use_tree := tree and rng.randf() < 0.55
		var spr := Art.foot_sprite(tree if use_tree else bush, rng.randf_range(0.85, 1.05) if use_tree else rng.randf_range(0.75, 0.95))
		if spr.texture == null:
			continue
		spr.position = pos
		add_child(spr)
		_block(pos, Vector2(18, 14) if use_tree else Vector2(16, 12), Vector2(0, -6))
	var banner := Art.load_tex("res://assets/sprites/props/banner.png")
	if banner:
		var b := Art.foot_sprite(banner, 0.95)
		b.position = Vector2((gx + 0.5) * TILE, (FY1 - 0.2) * TILE)
		add_child(b)
		var lab := Label.new()
		lab.text = "Welcome to Placeholdia!"
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector2(-150, -92)
		lab.size = Vector2(300, 36)
		lab.rotation = -0.04
		lab.add_theme_font_size_override("font_size", 20)
		lab.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08))
		lab.add_theme_color_override("font_outline_color", Color(0.95, 0.88, 0.65))
		lab.add_theme_constant_override("outline_size", 4)
		b.add_child(lab)


func _fence_seg(foot: Vector2, tex: Texture2D, horiz: bool) -> void:
	if tex == null:
		return
	var s := Art.foot_sprite(tex, 1.0)
	s.position = foot
	add_child(s)
	if horiz:
		_block(foot, Vector2(72, 14), Vector2(0, -6))
	else:
		_block(foot, Vector2(18, 48), Vector2(0, -6))


func _buildings() -> void:
	var guild := _place_tex("res://assets/sprites/buildings/guild.png", Vector2(9.4 * TILE, 11.2 * TILE), 0.88)
	if guild:
		_block(guild.position, Vector2(150, 42), Vector2(0, -16))
	var wing := _place_tex("res://assets/sprites/buildings/guild_reception.png", Vector2(15.0 * TILE, 11.4 * TILE), 1.0)
	if wing:
		# U-shaped walls; south face stays open so you can walk in.
		_block(wing.position, Vector2(200, 18), Vector2(0, -110))
		_block(wing.position, Vector2(18, 90), Vector2(-92, -50))
		_block(wing.position, Vector2(18, 90), Vector2(92, -50))
		_block(wing.position, Vector2(70, 16), Vector2(0, -58))
	var stall := _place_tex("res://assets/sprites/buildings/stall.png", Vector2(28.4 * TILE, 11.3 * TILE), 0.92)
	if stall:
		_block(stall.position, Vector2(200, 28), Vector2(0, -12))


func _props() -> void:
	var crystal := TownCrystal.new()
	crystal.position = Vector2(20 * TILE, 9.2 * TILE)
	add_child(crystal)
	var clerk := Receptionist.new()
	clerk.position = Vector2(15.0 * TILE, 10.55 * TILE)
	add_child(clerk)
	var guild_sign := SignProp.new()
	guild_sign.position = Vector2(7.2 * TILE, 12.4 * TILE)
	guild_sign.setup("Guild notice", "Diver board. Pack food. Mail ore. Don't die with a full bag if you can help it.")
	add_child(guild_sign)
	var vendor := VendorProp.new()
	vendor.position = Vector2(28.4 * TILE, 12.0 * TILE)
	add_child(vendor)
	var anvil := AnvilProp.new()
	anvil.position = Vector2(8.2 * TILE, 18.2 * TILE)
	add_child(anvil)
	var dumpster := SignProp.new()
	dumpster.position = Vector2(30.2 * TILE, 18.4 * TILE)
	dumpster.setup("Dumpster", "You used to eat from this. Career upgrade pending.", "res://assets/sprites/props/dumpster.png")
	add_child(dumpster)
	var board := SignProp.new()
	board.position = Vector2(18.5 * TILE, 16.6 * TILE)
	board.setup(
		"Notice board",
		"Hold RT / LMB to swing.\nB / Space dash.\nX / Shift slam.\nA / E talk.\nD-pad Up / 1 potion.\nD-pad Left / 2 food.\nStart / Esc pause bag.\nSelect / M map (in the hole).\nLB / RB pause tabs.",
		"res://assets/sprites/props/notice_board.png"
	)
	add_child(board)
