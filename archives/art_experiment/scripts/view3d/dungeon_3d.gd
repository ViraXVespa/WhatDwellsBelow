extends Node3D

const V3 := preload("res://archives/art_experiment/scripts/view3d/v3.gd")
const Player3D := preload("res://archives/art_experiment/scripts/view3d/player_3d.gd")
const Enemy3D := preload("res://archives/art_experiment/scripts/view3d/enemy_3d.gd")
const Interact3D := preload("res://archives/art_experiment/scripts/view3d/interact_3d.gd")
const Solid3D := preload("res://archives/art_experiment/scripts/view3d/solid_3d.gd")
const Area3DS := preload("res://archives/art_experiment/scripts/view3d/area_3d.gd")
const ShopUIS := preload("res://scripts/ui/shop_ui.gd")

var data: Dictionary
var fog_visited: PackedByteArray
var fog_mm: MultiMesh
var fog_index: Dictionary = {}
var cam: Camera3D


func _ready() -> void:
	if Game.run == null:
		Game.go_plaza()
		return
	Sfx.set_music("dungeon")
	var seed_value := Game.run.seed_value + Game.run.current_floor * 997
	data = DungeonGen.generate(Game.run.current_floor, seed_value)
	fog_visited = PackedByteArray()
	fog_visited.resize(data.w * data.h)
	fog_visited.fill(0)
	V3.add_world(self, true)
	_draw_tiles()
	_collisions()
	_fog()
	_spawn_entities()
	var player = Player3D.new()
	var spawn: Vector2i = data.spawn
	player.position = V3.tile_center(spawn.x, spawn.y)
	add_child(player)
	cam = Camera3D.new()
	add_child(cam)
	V3.apply_cam(cam)
	V3.follow_cam(cam, player.global_position)
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
	print("WDB 3D floor ", Game.run.current_floor, " gather=", data.gather_type, " misc=", data.misc_type, " enemies=", data.enemies.size(), " mines=", data.mines.size(), " loot=", loot_n, " breakables=", br_n, " rooms=", data.rooms.size())


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not (p is Node3D):
		return
	var n3: Node3D = p
	if cam:
		V3.follow_cam(cam, n3.global_position)
	var t := Vector2i(int(n3.position.x), int(n3.position.z))
	_reveal_around(t)


func _draw_tiles() -> void:
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	var fa: Array = []
	var fb: Array = []
	var walls: Array = []
	for y in h:
		for x in w:
			var t: int = grid[DungeonGen.idx(x, y)]
			var pos := V3.tile_center(x, y)
			if t == DungeonGen.FLOOR:
				if (x + y) % 5 == 0:
					fb.append(pos)
				else:
					fa.append(pos)
			else:
				var near_floor := false
				for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var wx: int = x + n.x
					var wy: int = y + n.y
					if wx < 0 or wy < 0 or wx >= w or wy >= h:
						continue
					if grid[DungeonGen.idx(wx, wy)] == DungeonGen.FLOOR:
						near_floor = true
						break
				if near_floor:
					walls.append(pos)
	if not fa.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "dungeon_floor.png"), fa, 0.0))
	if not fb.is_empty():
		add_child(V3.tile_mm(V3.a("tiles", "dungeon_floor_b.png"), fb, 0.0))
	if not walls.is_empty():
		add_child(V3.wall_mm(V3.a("tiles", "dungeon_wall.png"), walls))
	var void_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 160.0)
	void_mesh.mesh = plane
	void_mesh.position = Vector3(float(w) * 0.5, -0.04, float(h) * 0.5)
	void_mesh.material_override = V3.mat_color(Color(0.04, 0.045, 0.06))
	add_child(void_mesh)


func _collisions() -> void:
	var body := V3.wall_body(self, "DungeonWalls")
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
				V3.add_box(body, Vector3(1.0, V3.WALL_H, 1.0), Vector3(float(wx) + 0.5, V3.WALL_H * 0.5, float(wy) + 0.5))


func _fog() -> void:
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	var positions: Array = []
	var idx := 0
	for y in h:
		for x in w:
			if grid[DungeonGen.idx(x, y)] != DungeonGen.FLOOR:
				continue
			positions.append(V3.tile_center(x, y, 0.04))
			fog_index[Vector2i(x, y)] = idx
			idx += 1
	if positions.is_empty():
		return
	var inst := V3.tile_mm("", positions, 0.04)
	inst.material_override = V3.mat_color(Color(0.0, 0.0, 0.0, 1.0))
	fog_mm = inst.multimesh
	add_child(inst)


func _reveal_around(tile: Vector2i) -> void:
	var r := 5
	var w: int = data.w
	var h: int = data.h
	for y in range(tile.y - r, tile.y + r + 1):
		for x in range(tile.x - r, tile.x + r + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if Vector2(x, y).distance_to(Vector2(tile)) > r + 0.2:
				continue
			var i := DungeonGen.idx(x, y)
			if fog_visited[i] == 1:
				continue
			fog_visited[i] = 1
			var key := Vector2i(x, y)
			if fog_mm and fog_index.has(key):
				var fi: int = fog_index[key]
				var xf := Transform3D.IDENTITY
				xf.origin = Vector3(0.0, -4.0, 0.0)
				xf.basis = xf.basis.scaled(Vector3(0.001, 0.001, 0.001))
				fog_mm.set_instance_transform(fi, xf)
	if Game.run and data.has("stairs"):
		var st: Vector2i = data.stairs
		if st.x >= 0 and fog_visited[DungeonGen.idx(st.x, st.y)] == 1:
			Game.run.saw_stairs = true


func _spawn_entities() -> void:
	_iact("floor_crystal", data.crystal, V3.a("props", "crystal.png"))
	var st_locked := Game.run.current_floor >= DungeonGen.SLICE_MAX_FLOOR
	_iact("stairs", data.stairs, V3.a("props", "stairs.png"), {"locked": st_locked})
	if data.get("boss", false):
		var boss = Enemy3D.new()
		boss.position = _world(data.boss_pos)
		add_child(boss)
		boss.setup("tank", Game.run.current_floor, true)
	_clerk("gather", data.gather_type, data.clerk_gather)
	_clerk("misc", data.misc_type, data.clerk_misc)
	if data.has("clerk_patty"):
		var pp: Vector2i = data.clerk_patty
		if pp.x >= 0:
			_clerk("misc", "patty", pp)
	for mp in data.mines:
		_iact("mining", mp, V3.a("props", "ore.png"))
	for e in data.enemies:
		var en = Enemy3D.new()
		en.position = _world(e.pos)
		add_child(en)
		en.setup(e.role, Game.run.current_floor)
	if data.has("loot"):
		for lp in data.loot:
			_iact("loot_stash", lp, V3.a("props", "chest.png"))
	if data.has("breakables"):
		for row in data.breakables:
			var br = Solid3D.new()
			br.position = _world(row.pos)
			add_child(br)
			br.setup_breakable(String(row.kind))
	if data.has("campfires"):
		for cp in data.campfires:
			_iact("campfire", cp, V3.a("props", "campfire.png"))
	if data.has("shrines"):
		for sp in data.shrines:
			_iact("shrine", sp)
	if data.has("shop"):
		var sp: Vector2i = data.shop
		if sp.x >= 0:
			_iact("ghost_shop", sp, V3.a("npcs", "shopkeep.png"))
	if data.has("chests"):
		for cp in data.chests:
			_iact("artifact_chest", cp, V3.a("props", "chest.png"))
	if data.has("fires"):
		for fp in data.fires:
			var ft = Area3DS.new()
			ft.position = _world(fp)
			add_child(ft)
			ft.setup_fire()
	if data.has("gates"):
		for row in data.gates:
			var gd = Solid3D.new()
			gd.position = _world(row.pos)
			add_child(gd)
			gd.setup_gate(int(row.id))
	if data.has("plates"):
		for row in data.plates:
			var pl = Area3DS.new()
			pl.position = _world(row.pos)
			add_child(pl)
			pl.setup_plate(int(row.id))
	if data.has("levers"):
		for row in data.levers:
			_iact("lever", row.pos, "", {"lever_id": int(row.id)})
	if data.has("cracks"):
		for cp in data.cracks:
			var cw = Solid3D.new()
			cw.position = _world(cp)
			add_child(cw)
			cw.setup_cracked()


func _world(t: Vector2i) -> Vector3:
	return V3.tile_center(t.x, t.y)


func _iact(kind: String, t: Vector2i, tex := "", extra: Dictionary = {}) -> void:
	var n = Interact3D.new()
	n.configure(kind, tex, extra)
	n.position = _world(t)
	add_child(n)


func _clerk(kind: String, id: String, t: Vector2i) -> void:
	_iact("clerk", t, "", {"clerk_kind": kind, "clerk_id": id})
