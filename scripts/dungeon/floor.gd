extends Node2D

const TILE := 64
const ShopUIS := preload("res://scripts/ui/shop_ui.gd")
const GhostShopS := preload("res://scripts/entities/ghost_shop.gd")
const ArtifactChestS := preload("res://scripts/entities/artifact_chest.gd")
const FireTrapS := preload("res://scripts/entities/fire_trap.gd")
const GateDoorS := preload("res://scripts/entities/gate_door.gd")
const PressurePlateS := preload("res://scripts/entities/pressure_plate.gd")
const DungeonLeverS := preload("res://scripts/entities/dungeon_lever.gd")
const CrackedWallS := preload("res://scripts/entities/cracked_wall.gd")

var data: Dictionary
var fog_visited: PackedByteArray
var fog_sprite: Sprite2D
var fog_tex: ImageTexture
var fog_img: Image


func _ready() -> void:
	if Game.run == null:
		Game.go_plaza()
		return
	y_sort_enabled = true
	Sfx.set_music("dungeon")
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
	Game.apply_cam(cam)
	cam.make_current()
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(ExtractUI.new())
	add_child(ShopUIS.new())
	_reveal_around(spawn)
	var loot_n := 0
	if data.has("loot"):
		loot_n = data.loot.size()
	var br_n := 0
	if data.has("breakables"):
		br_n = data.breakables.size()
	print("WDB floor ", Game.run.current_floor, " gather=", data.gather_type, " misc=", data.misc_type, " enemies=", data.enemies.size(), " mines=", data.mines.size(), " loot=", loot_n, " breakables=", br_n, " rooms=", data.rooms.size())


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
	fog_img.fill(Color(0, 0, 0, 1))
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
	if Game.run and data.has("stairs"):
		var st: Vector2i = data.stairs
		if st.x >= 0 and fog_visited[DungeonGen.idx(st.x, st.y)] == 1:
			Game.run.saw_stairs = true


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
	if data.has("clerk_patty"):
		var pp: Vector2i = data.clerk_patty
		if pp.x >= 0:
			var pat := Clerk.new()
			pat.setup("misc", "patty")
			pat.position = _world(pp)
			add_child(pat)
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
	if data.has("breakables"):
		for row in data.breakables:
			var br := Breakable.new()
			br.position = _world(row.pos)
			add_child(br)
			br.setup(String(row.kind))
	if data.has("campfires"):
		for cp in data.campfires:
			var fire := Campfire.new()
			fire.position = _world(cp)
			add_child(fire)
	if data.has("shrines"):
		for sp in data.shrines:
			var sh := FloorShrine.new()
			sh.position = _world(sp)
			add_child(sh)
	if data.has("shop"):
		var sp: Vector2i = data.shop
		if sp.x >= 0:
			var gs = GhostShopS.new()
			gs.position = _world(sp)
			add_child(gs)
	if data.has("chests"):
		for cp in data.chests:
			var ch = ArtifactChestS.new()
			ch.position = _world(cp)
			add_child(ch)
	if data.has("fires"):
		for fp in data.fires:
			var ft = FireTrapS.new()
			ft.position = _world(fp)
			add_child(ft)
	if data.has("gates"):
		for row in data.gates:
			var gd = GateDoorS.new()
			gd.position = _world(row.pos)
			add_child(gd)
			gd.setup(int(row.id))
	if data.has("plates"):
		for row in data.plates:
			var pl = PressurePlateS.new()
			pl.position = _world(row.pos)
			add_child(pl)
			pl.setup(int(row.id))
	if data.has("levers"):
		for row in data.levers:
			var lv = DungeonLeverS.new()
			lv.position = _world(row.pos)
			add_child(lv)
			lv.setup(int(row.id))
	if data.has("cracks"):
		for cp in data.cracks:
			var cw = CrackedWallS.new()
			cw.position = _world(cp)
			add_child(cw)


func _world(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2, t.y * TILE + TILE / 2)
