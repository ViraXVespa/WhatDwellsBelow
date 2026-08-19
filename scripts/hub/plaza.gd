extends Node2D

const TILE := 64


func _ready() -> void:
	_build_ground()
	_walls()
	_props()
	var player := Player.new()
	player.position = Vector2(10 * TILE, 12 * TILE)
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(LoadoutUI.new())
	add_child(InventoryUI.new())
	add_child(AnvilUI.new())


func _build_ground() -> void:
	var vis := Node2D.new()
	vis.z_index = -2
	add_child(vis)
	vis.set_script(preload("res://scripts/hub/plaza_draw.gd"))
	vis.queue_redraw()


func _walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	var rects := [
		Rect2(0, 0, 24 * TILE, TILE),
		Rect2(0, 17 * TILE, 24 * TILE, TILE),
		Rect2(0, 0, TILE, 18 * TILE),
		Rect2(23 * TILE, 0, TILE, 18 * TILE),
		Rect2(3 * TILE, 3 * TILE, 5 * TILE, 3 * TILE),
		Rect2(16 * TILE, 3 * TILE, 5 * TILE, 3 * TILE),
		Rect2(3 * TILE, 13 * TILE, 4 * TILE, 2 * TILE),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.position + r.size / 2.0
		body.add_child(cs)


func _props() -> void:
	var crystal := TownCrystal.new()
	crystal.position = Vector2(12 * TILE, 5 * TILE)
	add_child(crystal)
	var guild := SignProp.new()
	guild.position = Vector2(5.5 * TILE, 6.6 * TILE)
	guild.setup("Guild", "The Adventure Guild. Crystal's always open. Dying's a workplace hazard — pack snacks.")
	add_child(guild)
	var vendor := VendorProp.new()
	vendor.position = Vector2(18.5 * TILE, 6.6 * TILE)
	add_child(vendor)
	var anvil := AnvilProp.new()
	anvil.position = Vector2(5 * TILE, 14 * TILE)
	add_child(anvil)
	var dumpster := SignProp.new()
	dumpster.position = Vector2(19 * TILE, 14 * TILE)
	dumpster.setup("Dumpster", "You used to eat from this. Career upgrade pending.")
	add_child(dumpster)
