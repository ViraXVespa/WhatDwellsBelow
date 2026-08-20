extends Node2D

const TILE := 64


func _ready() -> void:
	_build_ground()
	_walls()
	_buildings()
	_props()
	var player := Player.new()
	player.position = Vector2(10 * TILE, 12 * TILE)
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	Game.apply_cam(cam)
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
	body.name = "PlazaWalls"
	body.collision_layer = 1
	add_child(body)
	for r in [
		Rect2(0, 0, 24 * TILE, TILE),
		Rect2(0, 17 * TILE, 24 * TILE, TILE),
		Rect2(0, 0, TILE, 18 * TILE),
		Rect2(23 * TILE, 0, TILE, 18 * TILE),
	]:
		_add_wall_rect(body, r)


func _add_wall_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)


func _buildings() -> void:
	# UV of the solid base on the sprite (not roof / awning air).
	_place_building(
		"res://assets/sprites/buildings/guild.png",
		Rect2(3 * TILE, 3 * TILE, 5 * TILE, 3 * TILE),
		Rect2(0.14, 0.50, 0.72, 0.48)
	)
	_place_building(
		"res://assets/sprites/buildings/stall.png",
		Rect2(16 * TILE, 3 * TILE, 5 * TILE, 3 * TILE),
		Rect2(0.08, 0.52, 0.84, 0.46)
	)


func _place_building(path: String, slot: Rect2, foot_uv: Rect2) -> void:
	var tex := Art.load_tex(path)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sz: Vector2 = tex.get_size()
	var s := slot.size.x / sz.x
	spr.scale = Vector2(s, s)
	spr.position = Vector2(slot.position.x, slot.position.y + slot.size.y - sz.y * s)
	add_child(spr)
	var vis := sz * s
	var walls := get_node("PlazaWalls") as StaticBody2D
	if walls:
		_add_wall_rect(
			walls,
			Rect2(
				spr.position.x + vis.x * foot_uv.position.x,
				spr.position.y + vis.y * foot_uv.position.y,
				vis.x * foot_uv.size.x,
				vis.y * foot_uv.size.y
			)
		)


func _props() -> void:
	var crystal := TownCrystal.new()
	crystal.position = Vector2(12 * TILE, 5 * TILE)
	add_child(crystal)
	var guild := SignProp.new()
	guild.position = Vector2(5.5 * TILE, 6.6 * TILE)
	var guild_body := "Welcome to Placeholdia, pop. whoever showed up. Real city's still in permitting. Crystal's open. Dying's a workplace hazard — pack snacks."
	if Game.save and not Game.save.has_dived:
		guild_body = "First time? Eh, I'm sure you'll be able to figure it out.\n\n" + guild_body
	guild.setup("Guild", guild_body)
	add_child(guild)
	var vendor := VendorProp.new()
	vendor.position = Vector2(18.5 * TILE, 6.6 * TILE)
	add_child(vendor)
	var anvil := AnvilProp.new()
	anvil.position = Vector2(5 * TILE, 14 * TILE)
	add_child(anvil)
	var dumpster := SignProp.new()
	dumpster.position = Vector2(19 * TILE, 14 * TILE)
	dumpster.setup("Dumpster", "You used to eat from this. Career upgrade pending.", "res://assets/sprites/props/dumpster.png")
	add_child(dumpster)
