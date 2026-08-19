extends Node2D

const TILE := 64

var data: Dictionary
var fog_visited: PackedByteArray
var fog_sprite: Sprite2D
var fog_tex: ImageTexture
var fog_img: Image


func _ready() -> void:
	if Game.run == null:
		Game.go_plaza()
		return
	var seed_value := Game.run.seed_value + Game.run.current_floor * 997
	data = DungeonGen.generate(Game.run.current_floor, seed_value)
	fog_visited = PackedByteArray()
	fog_visited.resize(data.w * data.h)
	fog_visited.fill(0)
	_draw_tiles()
	_collisions()
	_fog()
	_spawn_entities()
	var player := Player.new()
	var spawn: Vector2i = data.spawn
	player.position = Vector2(spawn.x * TILE + TILE / 2, spawn.y * TILE + TILE / 2)
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(ExtractUI.new())
	add_child(InventoryUI.new())
	_reveal_around(spawn)
	var loot_n := 0
	if data.has("loot"):
		loot_n = data.loot.size()
	print("WDB floor ", Game.run.current_floor, " gather=", data.gather_type, " misc=", data.misc_type, " enemies=", data.enemies.size(), " mines=", data.mines.size(), " loot=", loot_n, " rooms=", data.rooms.size())


func _draw_tiles() -> void:
	var vis := Node2D.new()
	vis.name = "Tiles"
	vis.z_index = -2
	vis.set_script(preload("res://scripts/dungeon/tile_draw.gd"))
	vis.set("grid", data.grid)
	vis.set("w", data.w)
	vis.set("h", data.h)
	add_child(vis)


func _collisions() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	var marked := {}
	for y in h:
		for x in w:
			if grid[DungeonGen.idx(x, y)] != DungeonGen.FLOOR:
				continue
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var wx: int = x + n.x
				var wy: int = y + n.y
				var key := Vector2i(wx, wy)
				if wx < 0 or wy < 0 or wx >= w or wy >= h:
					continue
				if grid[DungeonGen.idx(wx, wy)] != DungeonGen.WALL:
					continue
				if marked.has(key):
					continue
				marked[key] = true
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = Vector2(TILE, TILE)
				cs.shape = sh
				cs.position = Vector2(wx * TILE + TILE / 2, wy * TILE + TILE / 2)
				body.add_child(cs)


func _fog() -> void:
	fog_img = Image.create(data.w, data.h, false, Image.FORMAT_RGBA8)
	fog_img.fill(Color(0.02, 0.02, 0.04, 0.88))
	fog_tex = ImageTexture.create_from_image(fog_img)
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = fog_tex
	fog_sprite.centered = false
	fog_sprite.scale = Vector2(TILE, TILE)
	fog_sprite.z_index = 20
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fog_sprite)


func _reveal_around(tile: Vector2i) -> void:
	var r := 5
	var dirty := false
	for y in range(tile.y - r, tile.y + r + 1):
		for x in range(tile.x - r, tile.x + r + 1):
			if x < 0 or y < 0 or x >= data.w or y >= data.h:
				continue
			if Vector2(x, y).distance_to(Vector2(tile)) > r + 0.2:
				continue
			var i := DungeonGen.idx(x, y)
			if fog_visited[i] == 1:
				continue
			fog_visited[i] = 1
			fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
			dirty = true
	if dirty:
		fog_tex.update(fog_img)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var t := Vector2i(int(p.position.x / TILE), int(p.position.y / TILE))
	_reveal_around(t)


func _spawn_entities() -> void:
	var crystal := FloorCrystal.new()
	crystal.position = _world(data.crystal)
	add_child(crystal)
	var st := Stairs.new()
	st.position = _world(data.stairs)
	st.setup(Game.run.current_floor >= DungeonGen.SLICE_MAX_FLOOR)
	add_child(st)
	if data.get("boss", false):
		var boss := Enemy.new()
		boss.position = _world(data.boss_pos)
		add_child(boss)
		boss.setup("tank", Game.run.current_floor, true)
	var g := Clerk.new()
	g.setup("gather", data.gather_type)
	g.position = _world(data.clerk_gather)
	add_child(g)
	var m := Clerk.new()
	m.setup("misc", data.misc_type)
	m.position = _world(data.clerk_misc)
	add_child(m)
	for mp in data.mines:
		var node := MiningNode.new()
		node.position = _world(mp)
		add_child(node)
	for e in data.enemies:
		var en := Enemy.new()
		en.position = _world(e.pos)
		add_child(en)
		en.setup(e.role, Game.run.current_floor)
	if data.has("loot"):
		for lp in data.loot:
			var stash := LootStash.new()
			stash.position = _world(lp)
			add_child(stash)


func _world(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2, t.y * TILE + TILE / 2)
