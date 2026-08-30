extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const Depth := preload("res://scripts/world/depth.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const EnemyS := preload("res://scripts/combat/enemy.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const DoorS := preload("res://scripts/world/boss_door.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const UiS := preload("res://scripts/ui/progress_ui.gd")
const HudS := preload("res://scripts/ui/hud.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const DungeonStream := preload("res://scripts/world/dungeon_stream.gd")
const DungeonProps := preload("res://scripts/world/dungeon_props.gd")

var data: Dictionary = {}
var player: CharacterBody3D
var door: Node
var doors: Array = []
var stairs: Node
var visited: PackedByteArray
var fog_dirty := true
var floor_mm: MultiMeshInstance3D
var hint: Label
var prompt: Label
var fps_lab: Label
var hud: CanvasLayer
var map_layer: CanvasLayer
var map_img: Image
var map_tex: ImageTexture
var map_rect: TextureRect
var frame_acc := 0.0
var frame_n := 0
var walls: StaticBody3D
var _cleared := false
var groups: Dictionary = {}
var next_group := 1
var flee_used := 0
var types_present: PackedStringArray = PackedStringArray()
var idle_t := 0.0
var noreveal_t := 0.0
var pressure_cd_t := 0.0
var last_named := ""
var floor_rng := RandomNumberGenerator.new()
var ui: CanvasLayer
var toast_lab: Label
var shrine_lab: Label
var counts: Dictionary = {}
var occupied: Dictionary = {}
const PROP_GAP := 2
const SPAWN_CLEAR := 16
var spawn_jobs: Array = []
var stream_t := 0.0
var stream_all := false


func _ready() -> void:
	App.in_dungeon = true
	if App.present and App.present.has_method("hide_overlay"):
		App.present.hide_overlay()
	data = Gen.generate(App.floor_n, App.run_seed, App.bal)
	if not data.get("ok", false):
		data = Gen.generate(App.floor_n, App.run_seed + 17, App.bal)
	visited = PackedByteArray()
	visited.resize(int(data.w) * int(data.h))
	visited.fill(0)
	_world()
	_collision_walls()
	_build_visuals()
	_spawns()
	_hud()
	_map()
	_reveal_around(data.spawn, int(App.bal.fog_radius) + 2)
	DungeonStream.tick(self, 1.0)
	Smoke.attach_dungeon(self)


func _process(delta: float) -> void:
	frame_acc += delta
	frame_n += 1
	if frame_acc >= 0.5:
		frame_acc = 0.0
		frame_n = 0
	if player:
		var t := Vector2i(int(player.global_position.x), int(player.global_position.z))
		var grew := _reveal_around(t, int(App.bal.fog_radius))
		_tick_pressure(delta, grew)
		DungeonStream.tick(self, delta)
		if grew:
			fog_dirty = true
	_note_verge()
	_tick_plates()
	if fog_dirty or (map_layer and map_layer.visible):
		_redraw_map()
		fog_dirty = false
	if App.pause_just() if App.has_method("pause_just") else (Input.is_action_just_pressed("pause") or App.pad_just("pause")):
		if App.debug and App.debug.get("open"):
			pass
		elif App.recap and App.recap.get("open"):
			pass
		elif App.ui_open and ui and ui.has_method("close_ui") and ui.visible:
			ui.close_ui()
			if App.has_method("swallow_close_pad"):
				App.swallow_close_pad()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if Input.is_action_just_pressed("map_view") or App.pad_just("map_view"):
		if map_layer:
			map_layer.visible = not map_layer.visible
			if map_layer.visible:
				_redraw_map()
	if stairs:
		stairs.refresh()
	_refresh_hint()


func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.68, 0.74)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 0.65
	sun.light_color = Color(0.82, 0.88, 0.95)
	sun.shadow_enabled = false
	add_child(sun)


func _collision_walls() -> void:
	walls = StaticBody3D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	var used := {}
	for y in h:
		for x in w:
			if grid[Gen.idx(x, y, w)] != Gen.WALL or used.has(Vector2i(x, y)):
				continue
			var x1 := x
			while x1 + 1 < w and grid[Gen.idx(x1 + 1, y, w)] == Gen.WALL and not used.has(Vector2i(x1 + 1, y)):
				x1 += 1
			var y1 := y
			var row_ok := true
			while row_ok:
				for xx in range(x, x1 + 1):
					if y1 + 1 >= h or grid[Gen.idx(xx, y1 + 1, w)] != Gen.WALL or used.has(Vector2i(xx, y1 + 1)):
						row_ok = false
						break
				if row_ok:
					y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					used[Vector2i(xx, yy)] = true
			var sx := float(x1 - x + 1)
			var sz := float(y1 - y + 1)
			_box(walls, Vector3(sx, T.WALL_H, sz), Vector3(float(x) + sx * 0.5, T.WALL_H * 0.5, float(y) + sz * 0.5))


func _box(host: StaticBody3D, size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	host.add_child(cs)


func _build_visuals() -> void:
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	var floors: Array = []
	var wallp: Array = []
	for y in h:
		for x in w:
			if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
				floors.append(Vector3(float(x) + 0.5, T.FLOOR_Y, float(y) + 0.5))
			else:
				var near := false
				for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + n.x
					var ny: int = y + n.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if grid[Gen.idx(nx, ny, w)] == Gen.FLOOR:
						near = true
				if near:
					wallp.append(Vector3(float(x) + 0.5, T.WALL_H * 0.5, float(y) + 0.5))
	floor_mm = _mm_planes(floors, "res://assets/tiles/foundation_floor.png", Color(0.18, 0.2, 0.24))
	add_child(floor_mm)
	add_child(_mm_boxes(wallp, "res://assets/tiles/foundation_wall.png", Color(0.22, 0.22, 0.26)))


func _mm_planes(positions: Array, tex_path: String, fallback: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var p: Vector3 = positions[i]
		var xf := Transform3D.IDENTITY
		xf.origin = p
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.albedo_color = Color(0.75, 0.82, 0.9)
	else:
		mat.albedo_color = fallback
	inst.material_override = mat
	return inst


func _mm_boxes(positions: Array, tex_path: String, fallback: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(T.TILE, T.WALL_H, T.TILE)
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var p: Vector3 = positions[i]
		var xf := Transform3D.IDENTITY
		xf.origin = p
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = fallback
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	inst.material_override = mat
	return inst


func _spawns() -> void:
	floor_rng.seed = App.run_seed * 10007 + App.floor_n * 9176
	spawn_jobs.clear()
	player = PlayerS.new()
	var sp: Vector2i = data.spawn
	player.position = Vector3(float(sp.x) + 1.5, 0.0, float(sp.y) + 0.5)
	add_child(player)
	_place_doors()
	var st: Vector2i = data.stairs
	stairs = SpotS.new()
	stairs.setup("stairs", Vector3(float(st.x) + 0.5, 0.0, float(st.y) + 0.5), not App.boss_dead)
	add_child(stairs)
	var cr: Vector2i = data.crystal
	var crystal := SpotS.new()
	crystal.setup("crystal", Vector3(float(cr.x) + 0.5, 0.0, float(cr.y) + 0.5), not App.boss_dead)
	add_child(crystal)
	var pool: PackedStringArray = Roster.floor_types(App.floor_n)
	DungeonStream.queue_initial(self, pool)
	var boss = EnemyS.new()
	var bp: Vector2i = data.boss
	boss.position = Vector3(float(bp.x) + 0.5, 0.0, float(bp.y) + 0.5)
	add_child(boss)
	boss.setup_boss(str(data.boss_title), App.floor_n)
	boss.group_id = next_group
	next_group += 1
	if App.boss_dead:
		_on_boss_dead()
	DungeonProps.spawn_world(self)
	DungeonStream.queue_ambushes(self, pool)
	ui = UiS.new()
	add_child(ui)


func _place_doors() -> void:
	doors.clear()
	var openings: Array = data.get("openings", [])
	if openings.is_empty():
		var boss_r := {}
		for r in data.get("rooms", []):
			if str(r.get("kind", "")) == "boss":
				boss_r = r
				break
		if not boss_r.is_empty():
			openings = Gen.boss_openings(data.grid, int(data.w), int(data.h), boss_r)
	if openings.is_empty():
		var c: Vector2i = data.door
		openings = [Gen.make_opening("s", [c])]
	for o in openings:
		if o.is_empty():
			continue
		var d := DoorS.new()
		d.setup_opening(o)
		add_child(d)
		doors.append(d)
	door = doors[0] if not doors.is_empty() else null


func _on_boss_dead() -> void:
	App.boss_dead = true
	for d in doors:
		if d and d.has_method("open_door"):
			d.open_door()
	if door and door.has_method("open_door"):
		door.open_door()
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("refresh"):
			n.refresh()
	if _cleared:
		return
	_cleared = true
	var chest = SpotS.new()
	var bp: Vector2i = _free_near(data.boss)
	var gate := bool(data.get("gate_master", false)) or Gen.is_gate_master(App.floor_n)
	chest.setup("chest" if gate else "base_chest", _cell_pos(bp), false)
	add_child(chest)
	_mark_cell(bp)


func _reveal_around(c: Vector2i, rad: int) -> bool:
	var w: int = data.w
	var h: int = data.h
	var r2 := rad * rad
	var grew := false
	for y in range(maxi(0, c.y - rad), mini(h, c.y + rad + 1)):
		for x in range(maxi(0, c.x - rad), mini(w, c.x + rad + 1)):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= r2:
				var i := Gen.idx(x, y, w)
				if visited[i] == 0:
					visited[i] = 1
					grew = true
	return grew


func _hud() -> void:
	hud = HudS.new()
	add_child(hud)
	App.interact_prompt = ""
	hint = null
	prompt = null
	fps_lab = null
	toast_lab = null
	shrine_lab = null


func _refresh_hint() -> void:
	if hud and hud.has_method("refresh"):
		hud.refresh(player, self)
	if hud and hud.has_method("bind_map") and map_tex:
		hud.bind_map(map_tex)


func _map() -> void:
	map_layer = CanvasLayer.new()
	map_layer.layer = 30
	map_layer.visible = false
	add_child(map_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	map_layer.add_child(dim)
	map_img = Image.create(int(data.w), int(data.h), false, Image.FORMAT_RGBA8)
	map_tex = ImageTexture.create_from_image(map_img)
	map_rect = TextureRect.new()
	map_rect.texture = map_tex
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_rect.position = Vector2(560, 140)
	map_rect.size = Vector2(800, 800)
	map_layer.add_child(map_rect)
	_redraw_map()


func _redraw_map() -> void:
	if map_img == null:
		return
	var w: int = data.w
	var h: int = data.h
	var grid: PackedByteArray = data.grid
	for y in h:
		for x in w:
			var col := Color(0.02, 0.02, 0.03, 1)
			if visited[Gen.idx(x, y, w)] != 0:
				if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
					col = Color(0.22, 0.24, 0.28)
				else:
					col = Color(0.08, 0.08, 0.1)
			map_img.set_pixel(x, y, col)
	_dot(data.crystal, Color(0.3, 0.9, 1.0), true)
	_dot(data.stairs, Color(0.95, 0.75, 0.25), true)
	var marked := false
	for o in data.get("openings", []):
		for raw in o.get("cells", []):
			_dot(Vector2i(raw), Color(0.9, 0.2, 0.15), true)
			marked = true
	if not marked:
		_dot(data.door, Color(0.9, 0.2, 0.15), true)
	for n in get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var k := str(n.get("kind"))
			var cell := Vector2i(int((n as Node3D).global_position.x), int((n as Node3D).global_position.z))
			if k.begins_with("clerk"):
				_dot(cell, Color(0.95, 0.82, 0.35), true)
			elif k == "shop":
				_dot(cell, Color(0.55, 0.85, 1.0), true)
	if player:
		_dot(Vector2i(int(player.global_position.x), int(player.global_position.z)), Color(1, 1, 1), false)
	map_tex.update(map_img)


func _note_verge() -> void:
	if stairs and not bool(stairs.get("locked")):
		App.saw_stairs = true
	for b in get_tree().get_nodes_in_group("boss"):
		if b == null or not is_instance_valid(b):
			continue
		if b.has_method("is_alive") and not b.is_alive():
			continue
		var hp := float(b.get("hp"))
		var mx := maxf(1.0, float(b.get("max_hp")))
		if hp / mx <= 0.3:
			App.boss_low = true


func _dot(p: Vector2i, col: Color, need_seen := false) -> void:
	if p.x < 0 or p.y < 0 or p.x >= data.w or p.y >= data.h:
		return
	if need_seen and visited[Gen.idx(p.x, p.y, data.w)] == 0:
		return
	map_img.set_pixel(p.x, p.y, col)


func _player_cell() -> Vector2i:
	if player == null:
		return Vector2i(int(data.spawn.x), int(data.spawn.y))
	return Vector2i(int(player.global_position.x), int(player.global_position.z))


func _cell_manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _near_spawn(c: Vector2i, rad: int = SPAWN_CLEAR) -> bool:
	return _cell_manhattan(c, data.spawn) < rad


func _away_room() -> Dictionary:
	var best := {}
	var best_d := -1
	for r in data.get("rooms", []):
		var k := str(r.get("kind", "normal"))
		if k == "spawn" or k == "boss":
			continue
		var d := _cell_manhattan(_center_room(r), data.spawn)
		if d < SPAWN_CLEAR:
			continue
		if d > best_d:
			best_d = d
			best = r
	if not best.is_empty():
		return best
	for r in data.get("rooms", []):
		if str(r.get("kind", "")) != "spawn":
			return r
	return {}


func _stream_force_all() -> void:
	DungeonStream.force_all(self)


func _spawn_room(r: Dictionary, pool: PackedStringArray) -> void:
	DungeonStream.activate_room(self, r, pool)


func _maybe_named(pool: PackedStringArray) -> void:
	DungeonStream.queue_named(self, pool)


func _combat_room() -> Dictionary:
	for r in data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if kind != "normal" and kind != "base":
			continue
		if _near_spawn(_center_room(r)):
			continue
		return r
	return _away_room()


func _add_enemy(id: String, pos: Vector3, gid: int, named: bool, nname: String) -> Node:
	var e = EnemyS.new()
	e.position = pos
	add_child(e)
	e.setup(id, App.floor_n, named, nname)
	e.group_id = gid
	if not groups.has(gid):
		groups[gid] = {"max_hp": 0.0, "hp": 0.0, "fled": false}
	groups[gid].max_hp += e.max_hp
	groups[gid].hp += e.max_hp
	if types_present.find(id) < 0:
		types_present.append(id)
	return e


func _ensure_pool(pool: PackedStringArray) -> void:
	DungeonStream.queue_pool(self, pool)


func _rand_cell(r: Dictionary) -> Vector2i:
	var rx := int(r.x)
	var ry := int(r.y)
	var rw := int(r.w)
	var rh := int(r.h)
	for _i in 16:
		var x := floor_rng.randi_range(rx + 1, rx + maxi(2, rw) - 2)
		var y := floor_rng.randi_range(ry + 1, ry + maxi(2, rh) - 2)
		var c := Vector2i(x, y)
		if _is_floor_cell(c):
			return c
	return Vector2i(rx + rw / 2, ry + rh / 2)


func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)


func _world_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x - 0.5)), int(round(p.z - 0.5)))


func _mark_cell(c: Vector2i) -> void:
	if c.x >= 0 and c.y >= 0:
		occupied[c] = true


func _cell_clear(c: Vector2i, gap: int = PROP_GAP) -> bool:
	if not _is_floor_cell(c):
		return false
	for p in occupied.keys():
		var o: Vector2i = p
		if maxi(absi(o.x - c.x), absi(o.y - c.y)) < gap:
			return false
	return true


func _free_cell(r: Dictionary, gap: int = PROP_GAP) -> Vector2i:
	if r.is_empty():
		return Vector2i(-1, -1)
	var rx := int(r.x)
	var ry := int(r.y)
	var rw := int(r.w)
	var rh := int(r.h)
	var opts: Array[Vector2i] = []
	for y in range(ry + 1, ry + maxi(2, rh) - 1):
		for x in range(rx + 1, rx + maxi(2, rw) - 1):
			var c := Vector2i(x, y)
			if _cell_clear(c, gap):
				opts.append(c)
	if not opts.is_empty():
		return opts[floor_rng.randi() % opts.size()]
	opts.clear()
	for y in range(ry + 1, ry + maxi(2, rh) - 1):
		for x in range(rx + 1, rx + maxi(2, rw) - 1):
			var c2 := Vector2i(x, y)
			if _cell_clear(c2, 1):
				opts.append(c2)
	if not opts.is_empty():
		return opts[floor_rng.randi() % opts.size()]
	return _rand_cell(r)


func _free_cell_world(prefer: Dictionary, gap: int = PROP_GAP) -> Vector2i:
	var rooms: Array = []
	if not prefer.is_empty() and str(prefer.get("kind", "")) != "spawn" and not _near_spawn(_center_room(prefer)):
		rooms.append(prefer)
	for r in data.get("rooms", []):
		if r in rooms:
			continue
		if str(r.get("kind", "")) == "spawn" or _near_spawn(_center_room(r)):
			continue
		rooms.append(r)
	for g in [gap, 1]:
		for r in rooms:
			var c := _free_cell(r, g)
			if c.x >= 0 and _cell_clear(c, g) and not _near_spawn(c):
				return c
	var away := _away_room()
	if not away.is_empty():
		return _rand_cell(away)
	return Vector2i(int(data.spawn.x) + 8, int(data.spawn.y) + 8)


func _free_near(center: Vector2i, gap: int = PROP_GAP) -> Vector2i:
	if _cell_clear(center, gap):
		return center
	for rad in range(1, 7):
		var opts: Array[Vector2i] = []
		for y in range(center.y - rad, center.y + rad + 1):
			for x in range(center.x - rad, center.x + rad + 1):
				var c := Vector2i(x, y)
				if _cell_clear(c, gap):
					opts.append(c)
		if not opts.is_empty():
			return opts[floor_rng.randi() % opts.size()]
	for rad in range(1, 7):
		var opts2: Array[Vector2i] = []
		for y in range(center.y - rad, center.y + rad + 1):
			for x in range(center.x - rad, center.x + rad + 1):
				var c2 := Vector2i(x, y)
				if _cell_clear(c2, 1):
					opts2.append(c2)
		if not opts2.is_empty():
			return opts2[floor_rng.randi() % opts2.size()]
	return center


func _seed_occupied() -> void:
	occupied.clear()
	_mark_cell(data.spawn)
	_mark_cell(data.crystal)
	_mark_cell(data.stairs)
	_mark_cell(data.boss)
	_mark_cell(data.door)
	for o in data.get("openings", []):
		for raw in o.get("cells", []):
			_mark_cell(Vector2i(raw))
	if player:
		_mark_cell(_world_cell(player.global_position))
	for n in get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			_mark_cell(_world_cell((n as Node3D).global_position))


func _is_floor_cell(c: Vector2i) -> bool:
	var w: int = data.w
	var h: int = data.h
	if c.x < 1 or c.y < 1 or c.x >= w - 1 or c.y >= h - 1:
		return false
	var grid: PackedByteArray = data.grid
	return grid[Gen.idx(c.x, c.y, w)] == Gen.FLOOR


func _is_safe_cell(c: Vector2i) -> bool:
	if _near_spawn(c, 8):
		return true
	for r in data.get("rooms", []):
		if not Gen.is_safe_kind(str(r.get("kind", ""))):
			continue
		if c.x >= int(r.x) and c.y >= int(r.y) and c.x < int(r.x) + int(r.w) and c.y < int(r.y) + int(r.h):
			return true
	return false


func is_safe_world(p: Vector3) -> bool:
	return _is_safe_cell(Vector2i(int(p.x), int(p.z)))


func note_enemy_hit(e: Node, dmg: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	var gid: int = int(e.get("group_id"))
	if not groups.has(gid):
		return
	var g: Dictionary = groups[gid]
	g.hp = maxf(0.0, float(g.hp) - dmg)
	if g.fled:
		return
	if flee_used >= int(App.bal.flee_per_floor):
		return
	if float(g.hp) <= float(g.max_hp) * (1.0 - App.bal.flee_hp_frac):
		_trigger_flee(gid)


func _trigger_flee(gid: int) -> Node:
	if not groups.has(gid):
		return null
	if groups[gid].fled:
		return null
	var best: Node = null
	var best_spd := -1.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n):
			continue
		if int(n.get("group_id")) != gid:
			continue
		if n.get("is_boss") == true:
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		var spd := float(n.get("move_spd"))
		if spd > best_spd:
			best_spd = spd
			best = n
	if best and best.has_method("start_flee"):
		best.start_flee()
		groups[gid].fled = true
		flee_used += 1
	return best


func spawn_reinforcement(id: String, from: Vector3, gid: int) -> Node:
	var cell := _walkable_near(Vector2i(int(from.x), int(from.z)), 3, false)
	if cell == Vector2i(-1, -1):
		return null
	return _add_enemy(id, _cell_pos(cell), gid, false, "")


func _walkable_near(center: Vector2i, radius: int, allow_safe: bool) -> Vector2i:
	var opts: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var c := Vector2i(x, y)
			if not _is_floor_cell(c):
				continue
			if not allow_safe and _is_safe_cell(c):
				continue
			if absi(x - center.x) + absi(y - center.y) < 2:
				continue
			opts.append(c)
	if opts.is_empty():
		return Vector2i(-1, -1)
	return opts[floor_rng.randi() % opts.size()]


func _tick_pressure(delta: float, grew: bool) -> void:
	if player == null:
		return
	pressure_cd_t = maxf(0.0, pressure_cd_t - delta)
	var moving := player.velocity.length() > 0.25
	if moving:
		idle_t = 0.0
	else:
		idle_t += delta
	if grew:
		noreveal_t = 0.0
	else:
		noreveal_t += delta
	if pressure_cd_t > 0.0:
		return
	if is_safe_world(player.global_position):
		return
	if idle_t >= App.bal.idle_timer or noreveal_t >= App.bal.noreveal_timer:
		_pressure_spawn()
		idle_t = 0.0
		noreveal_t = 0.0
		pressure_cd_t = App.bal.pressure_cd


func _pressure_spawn() -> int:
	if player and is_safe_world(player.global_position):
		return 0
	var pool: PackedStringArray = Roster.floor_types(App.floor_n)
	if pool.is_empty():
		return 0
	var n := int(App.bal.pressure_count)
	var gid := next_group
	next_group += 1
	var spawned := 0
	var origin := Vector2i(int(player.global_position.x), int(player.global_position.z)) if player else Vector2i.ZERO
	for i in n:
		var cell := _walkable_near(origin, int(App.bal.pressure_radius), false)
		if cell == Vector2i(-1, -1):
			continue
		var id := pool[floor_rng.randi() % pool.size()]
		_add_enemy(id, _cell_pos(cell), gid, false, "")
		spawned += 1
	return spawned


func _find_kind_room(kind: String) -> Dictionary:
	for r in data.get("rooms", []):
		if str(r.get("kind", "")) == kind:
			return r
	return {}


func world_ui() -> Node:
	return ui


func _note(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


func _center_room(r: Dictionary) -> Vector2i:
	return Vector2i(int(r.x) + int(r.w) / 2, int(r.y) + int(r.h) / 2)


func _tick_plates() -> void:
	if player == null:
		return
	for n in get_tree().get_nodes_in_group("plates"):
		if n == null or not is_instance_valid(n) or not n.has_method("plate_held"):
			continue
		var d := Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
		n.plate_held(d < 0.7)
