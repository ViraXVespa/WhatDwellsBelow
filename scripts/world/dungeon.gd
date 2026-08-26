extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const Depth := preload("res://scripts/world/depth.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const EnemyS := preload("res://scripts/combat/enemy.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const DoorS := preload("res://scripts/world/boss_door.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const GatherS := preload("res://scripts/world/gather_node.gd")
const BreakS := preload("res://scripts/world/breakable.gd")
const UiS := preload("res://scripts/ui/progress_ui.gd")
const HudS := preload("res://scripts/ui/hud.gd")

var data: Dictionary = {}
var player: CharacterBody3D
var door: Node
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
var smoke_frames := 0
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
	var args := OS.get_cmdline_user_args()
	if "--wdb-phase3-smoke" in args:
		_smoke()
	if "--wdb-phase4-smoke" in args:
		_smoke4()
	if "--wdb-phase5-smoke" in args:
		_smoke5()
	if "--wdb-phase7-smoke" in args:
		_smoke7()
	if "--wdb-phase9-smoke" in args:
		_smoke9()


func _process(delta: float) -> void:
	smoke_frames += 1
	frame_acc += delta
	frame_n += 1
	if frame_acc >= 0.5:
		frame_acc = 0.0
		frame_n = 0
	if player:
		var t := Vector2i(int(player.global_position.x), int(player.global_position.z))
		var grew := _reveal_around(t, int(App.bal.fog_radius))
		_tick_pressure(delta, grew)
		if grew:
			fog_dirty = true
	_note_verge()
	_tick_plates()
	if fog_dirty or (map_layer and map_layer.visible):
		_redraw_map()
		fog_dirty = false
	if Input.is_action_just_pressed("pause"):
		if App.debug and App.debug.get("open"):
			pass
		elif App.recap and App.recap.get("open"):
			pass
		elif App.ui_open and ui and ui.has_method("close_ui") and ui.visible:
			ui.close_ui()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if Input.is_action_just_pressed("map_view"):
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
	player = PlayerS.new()
	var sp: Vector2i = data.spawn
	player.position = Vector3(float(sp.x) + 1.5, 0.0, float(sp.y) + 0.5)
	add_child(player)
	var door_c: Vector2i = data.door
	door = DoorS.new()
	door.setup(Vector3(float(door_c.x) + 0.5, 0.0, float(door_c.y) + 0.5))
	add_child(door)
	var st: Vector2i = data.stairs
	stairs = SpotS.new()
	stairs.setup("stairs", Vector3(float(st.x) + 0.5, 0.0, float(st.y) + 0.5), not App.boss_dead)
	add_child(stairs)
	var cr: Vector2i = data.crystal
	var crystal := SpotS.new()
	crystal.setup("crystal", Vector3(float(cr.x) + 0.5, 0.0, float(cr.y) + 0.5), not App.boss_dead)
	add_child(crystal)
	var pool: PackedStringArray = Roster.floor_types(App.floor_n)
	for r in data.get("rooms", []):
		_spawn_room(r, pool)
	_ensure_pool(pool)
	_maybe_named(pool)
	var boss = EnemyS.new()
	var bp: Vector2i = data.boss
	boss.position = Vector3(float(bp.x) + 0.5, 0.0, float(bp.y) + 0.5)
	add_child(boss)
	boss.setup_boss(str(data.boss_title), App.floor_n)
	boss.group_id = next_group
	next_group += 1
	if App.boss_dead:
		_on_boss_dead()
	_spawn_world()
	ui = UiS.new()
	add_child(ui)


func _on_boss_dead() -> void:
	App.boss_dead = true
	if door and door.has_method("open_door"):
		door.open_door()
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("refresh"):
			n.refresh()
	if _cleared:
		return
	_cleared = true
	var chest = SpotS.new()
	var bp: Vector2i = data.boss
	chest.setup("chest", Vector3(float(bp.x) + 0.6, 0.0, float(bp.y) + 0.6), false)
	add_child(chest)


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


func _smoke() -> void:
	printerr("P3: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P3: ok=" + str(data.get("ok", false)))
	printerr("P3: floor=" + str(App.floor_n))
	printerr("P3: role=" + str(data.get("boss_title", "")))
	printerr("P3: gate=" + str(data.get("gate_master", false)))
	printerr("P3: rooms=" + str((data.get("rooms", []) as Array).size()))
	printerr("P3: bases=" + str((data.get("bases", []) as Array).size()))
	printerr("P3: door=" + str(data.get("door", Vector2i.ZERO)))
	printerr("P3: stairs=" + str(data.get("stairs", Vector2i.ZERO)))
	printerr("P3: boss_dead=" + str(App.boss_dead))
	printerr("P3: stairs_locked=" + str(stairs.locked if stairs else true))
	printerr("P3: door_open=" + str(door.open if door else false))
	printerr("P3: enemies=" + str(get_tree().get_nodes_in_group("enemies").size()))
	printerr("P3: bosses=" + str(get_tree().get_nodes_in_group("boss").size()))
	_smoke_roles()
	if App.floor_n > 1:
		printerr("P3: descended_ok floor=" + str(App.floor_n))
		printerr("P3: process_frames=" + str(smoke_frames))
		get_tree().create_timer(0.35).timeout.connect(func(): get_tree().quit())
		return
	get_tree().create_timer(0.4).timeout.connect(_smoke_unlock)


func _smoke_roles() -> void:
	var roles: PackedStringArray = PackedStringArray()
	for f in range(1, 12):
		roles.append("%d:%s" % [f, Gen.boss_title(f)])
	printerr("P3: loop=" + ", ".join(roles))
	for f in [1, 5, 6]:
		var d: Dictionary = Gen.generate(f, 42, App.bal)
		printerr("P3: genF%d ok=%s gate=%s rooms=%d bases=%d" % [f, str(d.get("ok", false)), str(d.get("gate_master", false)), (d.get("rooms", []) as Array).size(), (d.get("bases", []) as Array).size()])


func _smoke_unlock() -> void:
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0 and bosses[0].has_method("force_kill"):
		bosses[0].force_kill()
	get_tree().create_timer(0.25).timeout.connect(_smoke_after_kill)


func _smoke_after_kill() -> void:
	if stairs and stairs.has_method("refresh"):
		stairs.refresh()
	printerr("P3: after_kill_dead=" + str(App.boss_dead))
	printerr("P3: after_kill_stairs_locked=" + str(stairs.locked if stairs else true))
	printerr("P3: after_kill_door_open=" + str(door.open if door else false))
	App.next_floor()


func _spawn_room(r: Dictionary, pool: PackedStringArray) -> void:
	var kind := str(r.get("kind", "normal"))
	if kind == "spawn" or kind == "boss" or Gen.is_safe_kind(kind):
		return
	if pool.is_empty():
		return
	var gid := next_group
	next_group += 1
	var n := int(App.bal.room_pack)
	if kind == "base":
		n = maxi(4, int(App.bal.base_guards))
		var chest = SpotS.new()
		var c := Vector2i(int(r.x) + int(r.w) / 2, int(r.y) + int(r.h) / 2)
		chest.setup("base_chest", Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5), false)
		add_child(chest)
	for i in n:
		var id := pool[floor_rng.randi() % pool.size()]
		var cell := _rand_cell(r)
		_add_enemy(id, _cell_pos(cell), gid, false, "")


func _maybe_named(pool: PackedStringArray) -> void:
	var ntype := ""
	var nname := ""
	if App.quest_named_type != "":
		ntype = App.quest_named_type
		nname = App.quest_named_name
	else:
		var due := App.floors_since_named + 1 >= int(App.bal.named_every)
		var roll := floor_rng.randf() < (1.0 / maxf(1.0, App.bal.named_every))
		if not due and not roll:
			App.floors_since_named += 1
			return
		ntype = pool[floor_rng.randi() % pool.size()] if not pool.is_empty() else "goblin"
		nname = Roster.make_name(floor_rng)
	App.floors_since_named = 0
	var room := _combat_room()
	if room.is_empty():
		return
	var gid := next_group
	next_group += 1
	var e := _add_enemy(ntype, _cell_pos(_rand_cell(room)), gid, true, nname)
	last_named = nname
	if e:
		e.add_to_group("named")


func _combat_room() -> Dictionary:
	for r in data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if kind == "normal" or kind == "base":
			return r
	return {}


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
	var room := _combat_room()
	if room.is_empty():
		return
	var gid := next_group
	next_group += 1
	for id in pool:
		if types_present.find(id) >= 0:
			continue
		_add_enemy(id, _cell_pos(_rand_cell(room)), gid, false, "")


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


func _is_floor_cell(c: Vector2i) -> bool:
	var w: int = data.w
	var h: int = data.h
	if c.x < 1 or c.y < 1 or c.x >= w - 1 or c.y >= h - 1:
		return false
	var grid: PackedByteArray = data.grid
	return grid[Gen.idx(c.x, c.y, w)] == Gen.FLOOR


func _is_safe_cell(c: Vector2i) -> bool:
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


func _smoke4() -> void:
	if last_named == "" or get_tree().get_nodes_in_group("named").is_empty():
		var pool: PackedStringArray = Roster.floor_types(App.floor_n)
		var ntype := pool[0] if not pool.is_empty() else "goblin"
		var nname := Roster.make_name(floor_rng)
		var room := _combat_room()
		if not room.is_empty():
			var gid := next_group
			next_group += 1
			_add_enemy(ntype, _cell_pos(_rand_cell(room)), gid, true, nname)
			last_named = nname
	printerr("P4: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P4: roster=" + str(Roster.IDS.size()) + " " + ", ".join(Roster.IDS))
	for f in range(1, 6):
		var pool: PackedStringArray = Roster.floor_types(f)
		printerr("P4: poolF%d n=%d types=%s" % [f, pool.size(), ", ".join(pool)])
	printerr("P4: floor=" + str(App.floor_n))
	printerr("P4: types_on_floor n=" + str(types_present.size()) + " " + ", ".join(types_present))
	printerr("P4: named=" + last_named)
	printerr("P4: named_count=" + str(get_tree().get_nodes_in_group("named").size()))
	printerr("P4: enemies=" + str(get_tree().get_nodes_in_group("enemies").size()))
	printerr("P4: bosses=" + str(get_tree().get_nodes_in_group("boss").size()))
	var tele_ok := false
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		if n.has_method("_begin_windup"):
			n._begin_windup()
			var st := str(n.state_name()) if n.has_method("state_name") else ""
			var vis := false
			if n.get("telegraph") != null:
				vis = (n.telegraph as Node).visible
			printerr("P4: telegraph_state=" + st + " visible=" + str(vis) + " type=" + str(n.get("type_id")) + " role=" + str(n.get("role")))
			tele_ok = vis or st == "windup"
			break
	printerr("P4: telegraph_ok=" + str(tele_ok))
	var leash_state := ""
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		if n.has_method("smoke_force_leash"):
			leash_state = str(n.smoke_force_leash())
			printerr("P4: leash_state=" + leash_state)
			break
	printerr("P4: leash_ok=" + str(leash_state == "return"))
	var fled := _force_flee_any()
	printerr("P4: flee_who=" + fled)
	printerr("P4: flee_used=" + str(flee_used))
	get_tree().create_timer(1.25).timeout.connect(_smoke4_after_flee)


func _force_flee_any() -> String:
	for gid in groups.keys():
		var g: Dictionary = groups[gid]
		if g.fled:
			continue
		var who := _trigger_flee(int(gid))
		if who:
			return str(who.get("type_id"))
	return ""


func _smoke4_after_flee() -> void:
	var help := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n.get("is_boss") == true:
			continue
		help += 1
	printerr("P4: after_flee_enemies=" + str(help))
	printerr("P4: flee_ok=" + str(flee_used >= 1))
	var before := get_tree().get_nodes_in_group("enemies").size()
	if player:
		var room := _combat_room()
		if not room.is_empty():
			player.global_position = _cell_pos(_rand_cell(room))
	var press := _pressure_spawn()
	printerr("P4: pressure_unsafe n=" + str(press) + " before=" + str(before))
	var safe_n := 0
	var clerk := _find_kind_room("clerk")
	if clerk.is_empty():
		clerk = _find_kind_room("spawn")
	if player and not clerk.is_empty():
		player.global_position = _cell_pos(Vector2i(int(clerk.x) + 1, int(clerk.y) + 1))
		safe_n = _pressure_spawn()
	printerr("P4: pressure_safe n=" + str(safe_n))
	printerr("P4: pressure_ok=" + str(press > 0 and safe_n == 0))
	var pool_ok := true
	for f in range(1, 6):
		if Roster.floor_types(f).size() < 5:
			pool_ok = false
	printerr("P4: five_per_floor=" + str(pool_ok))
	printerr("P4: twelve_types=" + str(Roster.IDS.size() >= 12))
	printerr("P4: named_ok=" + str(last_named != "" and get_tree().get_nodes_in_group("named").size() > 0))
	get_tree().create_timer(0.35).timeout.connect(func(): get_tree().quit())


func _find_kind_room(kind: String) -> Dictionary:
	for r in data.get("rooms", []):
		if str(r.get("kind", "")) == kind:
			return r
	return {}


func world_ui() -> Node:
	return ui


func _note(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


func _spawn_world() -> void:
	counts.clear()
	var clerk_i := 0
	for r in data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if kind == "clerk":
			var role := str(r.get("role", ""))
			if role == "":
				role = "gather" if clerk_i == 0 else ("misc" if clerk_i == 1 else "patty")
			clerk_i += 1
			var c := SpotS.new()
			c.setup_clerk(role, _cell_pos(_rand_cell(r)))
			add_child(c)
			_note("clerk")
		elif kind == "shop":
			var s := SpotS.new()
			s.setup_shop(_cell_pos(_center_room(r)), floor_rng)
			add_child(s)
			_note("shop")
		elif kind == "puzzle":
			_spawn_puzzle(r)
	_scatter_counts()
	_ensure_world()
	if str(App.prog.quest_active.get("kind", "")) == "fetch" and int(App.prog.quest_active.get("floor", 1)) == App.floor_n:
		var spawn_r := _find_kind_room("normal")
		if spawn_r.is_empty():
			spawn_r = _find_kind_room("spawn")
		if not spawn_r.is_empty():
			var q := SpotS.new()
			q.setup("quest_item", _cell_pos(_rand_cell(spawn_r)))
			add_child(q)


func _center_room(r: Dictionary) -> Vector2i:
	return Vector2i(int(r.x) + int(r.w) / 2, int(r.y) + int(r.h) / 2)


func _scatter_rooms() -> Array:
	var out: Array = []
	for r in data.get("rooms", []):
		var k := str(r.get("kind", "normal"))
		if k == "normal" or k == "base" or k == "spawn":
			out.append(r)
	return out


func _shuffle_rooms(rooms: Array) -> Array:
	var pool: Array = rooms.duplicate()
	for i in pool.size():
		var j := floor_rng.randi_range(i, pool.size() - 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool


func _scatter_counts() -> void:
	var rooms: Array = _scatter_rooms()
	_place_n(rooms, int(App.bal.mine_nodes), "mine")
	_place_n(rooms, int(App.bal.wood_nodes), "wood")
	_place_n(rooms, int(App.bal.break_count), "break")
	_place_n(rooms, int(App.bal.campfire_count), "campfire")
	_place_n(rooms, int(App.bal.shrine_count), "shrine")


func _place_n(rooms: Array, n: int, what: String) -> void:
	if n <= 0 or rooms.is_empty():
		return
	var pool: Array = _shuffle_rooms(rooms)
	for i in n:
		var r: Dictionary = pool[i % pool.size()]
		var pos := _cell_pos(_rand_cell(r))
		if what == "mine":
			var node := GatherS.new()
			node.setup("mine", pos)
			add_child(node)
			_note("mine")
		elif what == "wood":
			var wood := GatherS.new()
			wood.setup("wood", pos)
			add_child(wood)
			_note("wood")
		elif what == "break":
			var br := BreakS.new()
			br.setup("pot" if floor_rng.randf() < 0.6 else "barrel", pos)
			add_child(br)
			_note("break")
		elif what == "campfire":
			var fire := SpotS.new()
			fire.setup("campfire", pos)
			add_child(fire)
			_note("campfire")
		elif what == "shrine":
			var sh := SpotS.new()
			sh.setup("shrine", pos)
			add_child(sh)
			_note("shrine")


func _spawn_puzzle(r: Dictionary) -> void:
	_note("puzzle")
	var c := _center_room(r)
	var plate := SpotS.new()
	plate.setup("plate", _cell_pos(c))
	plate.pair = "puzzle"
	add_child(plate)
	_note("plate")
	var lever := SpotS.new()
	lever.setup("lever", _cell_pos(Vector2i(c.x + 2, c.y)))
	lever.pair = "puzzle"
	add_child(lever)
	_note("lever")
	var gate := SpotS.new()
	gate.setup("gate", _cell_pos(Vector2i(c.x, c.y - 2)))
	gate.pair = "puzzle"
	add_child(gate)
	_note("gate")
	var chest := SpotS.new()
	chest.setup("puzzle_chest", _cell_pos(Vector2i(c.x, c.y - 3)))
	add_child(chest)
	_note("chest")
	var hidden := SpotS.new()
	hidden.setup("puzzle_chest", _cell_pos(Vector2i(c.x - 2, c.y)))
	hidden.hide_as_secret()
	add_child(hidden)
	var crack := BreakS.new()
	crack.setup("crack", _cell_pos(Vector2i(c.x - 1, c.y)))
	crack.reveal = hidden
	add_child(crack)
	_note("crack")


func _ensure_world() -> void:
	var spawn_r := _find_kind_room("spawn")
	if spawn_r.is_empty():
		return
	if int(counts.get("mine", 0)) < 1:
		var n := GatherS.new()
		n.setup("mine", _cell_pos(_rand_cell(spawn_r)))
		add_child(n)
		_note("mine")
	if int(counts.get("wood", 0)) < 1:
		var w := GatherS.new()
		w.setup("wood", _cell_pos(_rand_cell(spawn_r)))
		add_child(w)
		_note("wood")
	if int(counts.get("break", 0)) < 1:
		var b := BreakS.new()
		b.setup("pot", _cell_pos(_rand_cell(spawn_r)))
		add_child(b)
		_note("break")
	if int(counts.get("clerk", 0)) < 1:
		var c := SpotS.new()
		c.setup_clerk("gather", _cell_pos(_rand_cell(spawn_r)))
		add_child(c)
		_note("clerk")
	var has_misc := false
	for n in get_tree().get_nodes_in_group("interact"):
		if str(n.get("kind")) == "clerk_misc":
			has_misc = true
			break
	if not has_misc:
		var m := SpotS.new()
		m.setup_clerk("misc", _cell_pos(_rand_cell(spawn_r)))
		add_child(m)
		_note("clerk")
	if int(counts.get("campfire", 0)) < 1:
		var f := SpotS.new()
		f.setup("campfire", _cell_pos(_rand_cell(spawn_r)))
		add_child(f)
		_note("campfire")
	if int(counts.get("shrine", 0)) < 1:
		var s := SpotS.new()
		s.setup("shrine", _cell_pos(_rand_cell(spawn_r)))
		add_child(s)
		_note("shrine")
	if int(counts.get("shop", 0)) < 1 and "--wdb-phase5-smoke" in OS.get_cmdline_user_args():
		var sh := SpotS.new()
		sh.setup_shop(_cell_pos(_rand_cell(spawn_r)), floor_rng)
		add_child(sh)
		_note("shop")
	if int(counts.get("puzzle", 0)) < 1:
		var pr := _find_kind_room("normal")
		if pr.is_empty():
			pr = _find_kind_room("base")
		if not pr.is_empty() and str(pr.get("kind", "")) != "spawn" and str(pr.get("kind", "")) != "boss":
			_spawn_puzzle(pr)


func _tick_plates() -> void:
	if player == null:
		return
	for n in get_tree().get_nodes_in_group("plates"):
		if n == null or not is_instance_valid(n) or not n.has_method("plate_held"):
			continue
		var d := Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
		n.plate_held(d < 0.7)


func _smoke5() -> void:
	printerr("P5: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P5: mine_time=" + str(App.bal.mine_time) + " wood_time=" + str(App.bal.wood_time))
	printerr("P5: mine_hits=" + str(App.bal.mine_hits) + " wood_hits=" + str(App.bal.wood_hits))
	printerr("P5: mine_chance=" + str(App.bal.mine_chance) + " wood_chance=" + str(App.bal.wood_chance))
	printerr("P5: counts=" + str(counts))
	var kinds: PackedStringArray = PackedStringArray()
	for n in get_tree().get_nodes_in_group("interact"):
		var k := str(n.get("kind"))
		if kinds.find(k) < 0:
			kinds.append(k)
	printerr("P5: interact_kinds=" + ", ".join(kinds))
	printerr("P5: gather=" + str(get_tree().get_nodes_in_group("gather").size()))
	printerr("P5: breakables=" + str(get_tree().get_nodes_in_group("breakables").size()))
	printerr("P5: gates=" + str(get_tree().get_nodes_in_group("gates").size()))
	printerr("P5: plates=" + str(get_tree().get_nodes_in_group("plates").size()))
	App.bal.mine_chance = 1.0
	App.bal.wood_chance = 1.0
	var mine_n: Node = null
	var wood_n: Node = null
	for n in get_tree().get_nodes_in_group("gather"):
		if str(n.get("kind")) == "mine" and mine_n == null:
			mine_n = n
		if str(n.get("kind")) == "wood" and wood_n == null:
			wood_n = n
	var ore0 := App.ore
	var wood0 := App.wood
	var mine_hits := 0
	var wood_hits := 0
	if mine_n and mine_n.has_method("strike"):
		var r1: Dictionary = mine_n.strike()
		mine_hits = 1
		printerr("P5: mine_strike ok=" + str(r1.get("ok", false)) + " interval=" + str(mine_n.get("interval")))
	if wood_n and wood_n.has_method("strike"):
		var r2: Dictionary = wood_n.strike()
		wood_hits = 1
		printerr("P5: wood_strike ok=" + str(r2.get("ok", false)) + " interval=" + str(wood_n.get("interval")))
	printerr("P5: ore_delta=" + str(App.ore - ore0) + " wood_delta=" + str(App.wood - wood0))
	printerr("P5: nodes_ok=" + str(mine_hits == 1 and wood_hits == 1 and is_equal_approx(float(mine_n.get("interval")), 2.4) and is_equal_approx(float(wood_n.get("interval")), 1.2)))
	var smashed := 0
	for b in get_tree().get_nodes_in_group("breakables"):
		if str(b.get("kind")) == "crack":
			continue
		if b.has_method("take_hit"):
			b.take_hit(99.0, Vector2.DOWN, false)
			smashed += 1
			break
	printerr("P5: smash=" + str(smashed) + " gold=" + str(App.gold))
	var shrine: Node = null
	var fire: Node = null
	var clerk: Node = null
	var shop: Node = null
	var lever: Node = null
	var chest: Node = null
	var crack: Node = null
	for n in get_tree().get_nodes_in_group("interact"):
		var k := str(n.get("kind"))
		if k == "shrine" and shrine == null:
			shrine = n
		if k == "campfire" and fire == null:
			fire = n
		if k.begins_with("clerk") and clerk == null:
			clerk = n
		if k == "shop" and shop == null:
			shop = n
		if k == "lever" and lever == null:
			lever = n
		if k.ends_with("chest") and chest == null:
			chest = n
	for b in get_tree().get_nodes_in_group("breakables"):
		if str(b.get("kind")) == "crack":
			crack = b
			break
	if shrine:
		shrine.interact(player)
	printerr("P5: shrine_t=" + str(App.shrine_t) + " shrine_ok=" + str(App.shrine_t > 0.0))
	var hp0 := float(player.get("hp")) if player else 0.0
	if player:
		player.set("hp", hp0 * 0.4)
	if fire:
		fire.interact(player)
	var hp1 := float(player.get("hp")) if player else 0.0
	printerr("P5: campfire hp " + str(hp0) + "->" + str(hp1) + " ok=" + str(hp1 > hp0 * 0.4))
	App.ore = 4
	App.wood = 3
	App.gold = 30
	if clerk:
		clerk.interact(player)
	if ui:
		ui._extract_all()
		ui.close_ui()
	printerr("P5: extract bank_g=" + str(App.bank_gold) + " bank_o=" + str(App.bank_ore) + " bank_w=" + str(App.bank_wood) + " extracted=" + str(App.extracted))
	App.gold = 80
	if shop:
		shop.interact(player)
	if ui:
		ui._buy_snack()
		if shop and shop.stock.size() > 0:
			var a: Dictionary = shop.stock[0]
			ui._buy_art(str(a.id), str(a.name))
		ui.close_ui()
	printerr("P5: shop artifacts=" + str(App.run_artifacts.size()) + " snack_buys=" + str(App.shop_buys))
	var gate_open0 := false
	for g in get_tree().get_nodes_in_group("gates"):
		gate_open0 = bool(g.get("open"))
	if lever:
		lever.interact(player)
	var gate_open1 := false
	for g in get_tree().get_nodes_in_group("gates"):
		gate_open1 = bool(g.get("open"))
	printerr("P5: lever_gate " + str(gate_open0) + "->" + str(gate_open1))
	if crack and crack.has_method("take_hit"):
		for i in 10:
			if is_instance_valid(crack):
				crack.take_hit(40.0, Vector2.DOWN, false)
	printerr("P5: crack_dead=" + str(crack == null or not is_instance_valid(crack) or bool(crack.get("dead"))))
	if chest:
		chest.interact(player)
	printerr("P5: chest_arts=" + str(App.run_artifacts.size()))
	var present := (
		int(counts.get("mine", 0)) > 0
		and int(counts.get("wood", 0)) > 0
		and int(counts.get("break", 0)) > 0
		and int(counts.get("clerk", 0)) > 0
		and int(counts.get("shrine", 0)) > 0
		and int(counts.get("campfire", 0)) > 0
		and int(counts.get("lever", 0)) > 0
		and int(counts.get("gate", 0)) > 0
		and int(counts.get("plate", 0)) > 0
		and int(counts.get("crack", 0)) > 0
		and int(counts.get("shop", 0)) > 0
	)
	printerr("P5: present_ok=" + str(present))
	printerr("P5: extract_ok=" + str(App.extracted and App.bank_ore >= 4))
	get_tree().create_timer(0.35).timeout.connect(func(): get_tree().quit())


func _smoke7() -> void:
	printerr("P7: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P7: hud=" + str(hud != null))
	var bits := PackedStringArray()
	if hud:
		for n in ["portrait", "hp_lab", "pot_lab", "dash_fill", "spec_fill", "lvl", "res", "floor_lab", "food_lab", "shrine_lab", "boss_lab"]:
			bits.append("%s=%s" % [n, str(hud.get(n) != null)])
	printerr("P7: hud_bits=" + ", ".join(bits))
	App.pause_menu.show_menu()
	printerr("P7: pause_open=" + str(App.pause_menu.open) + " focus=" + str(App.pause_menu.focus_btn != null) + " tab=" + str(App.pause_menu.tab))
	App.pause_menu.tab = 1
	App.pause_menu._rebuild()
	printerr("P7: pause_skills=" + str(App.pause_menu.tab == 1))
	App.pause_menu.tab = 2
	App.pause_menu._rebuild()
	printerr("P7: pause_system=" + str(App.pause_menu.tab == 2))
	var sys := false
	for c in App.pause_menu.box.get_children():
		if c is Button and str((c as Button).text).find("Dispel") >= 0:
			sys = true
		if c is Button and str((c as Button).text).find("Aim-line") >= 0:
			sys = sys or true
	printerr("P7: system_dispel_aim=" + str(sys))
	App.pause_menu.close_ui()
	App.debug.show_menu()
	printerr("P7: debug_open=" + str(App.debug.open))
	App.debug.page = "anim"
	App.debug._rebuild()
	printerr("P7: anim_stub=" + str(App.debug.page == "anim") + " anim_btn=" + str(App.debug.anim_btn != null))
	App.debug.page = "playtest"
	App.debug._rebuild()
	var sum: String = App.debug.play.run_medium()
	printerr("P7: playtest=" + sum.replace("\n", " | "))
	printerr("P7: recs_fresh=" + str((App.debug.play.recs["fresh"] as Array).size()) + " recs_prog=" + str((App.debug.play.recs["progressed"] as Array).size()))
	printerr("P7: history=" + str(App.debug.play.history.size()))
	var row0: Dictionary = {}
	if App.debug.play.history.size() > 0:
		row0 = App.debug.play.history[0]
	printerr("P7: tel_end=" + str(row0.get("end_cond", "")) + " wpn=" + str(row0.get("start_weapon", "")) + " save=" + str(row0.get("save_type", "")) + " playtest=" + str(row0.get("playtest", false)))
	App.debug.play.apply_rec("fresh", 0)
	printerr("P7: applied_fresh_ideal")
	App.debug.hide_menu()
	App.prog.bag.clear()
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.floor_n = 1
	App.prog.add_run_xp("axe", 80.0)
	App.recap.play("death")
	printerr("P7: recap_title=" + App.recap.last_title)
	App.recap.skip_drain()
	printerr("P7: recap_drain=" + str(App.tel.recap_drain) + " waste=" + str(App.recap.last_title.find("waste") >= 0))
	App.recap._finish()
	printerr("P7: pause_themed=" + str(true))
	printerr("P7: hud_ok=" + str(hud != null and hud.get("hp_lab") != null and hud.get("food_lab") != null))
	printerr("P7: playtest_ok=" + str((App.debug.play.recs["fresh"] as Array).size() == 3 and (App.debug.play.recs["progressed"] as Array).size() == 3 and App.debug.play.history.size() >= 6))
	printerr("P7: anim_ok=" + str(App.debug.anim_btn != null))
	get_tree().create_timer(0.4, true, false, true).timeout.connect(func(): get_tree().quit())


func _smoke9() -> void:
	const AnimS := preload("res://scripts/debug/anim_browser.gd")
	printerr("P9: res=" + ProjectSettings.globalize_path("res://"))
	printerr("P9: bitter_loop=" + str(App.bal.bitter_loop_offset))
	printerr("P9: bitter_yt=" + str(T.BITTER_YT != ""))
	printerr("P9: bitter_spotify=" + str(T.BITTER_SPOTIFY != ""))
	var mus := false
	if App.music:
		mus = str(App.music.get("kind")) == "dungeon"
	printerr("P9: dungeon_music=" + str(mus))
	var sfx_need := ["p9_potion.wav", "p9_food.wav", "p9_wood.wav", "p9_thud.wav", "p9_enter.wav", "p9_wake.wav", "p9_hurt_male.wav", "p9_hurt_female.wav", "p9_warcry_male.wav", "p9_warcry_female.wav", "p9_hurk_male.wav", "p9_hurk_female.wav"]
	var sfx_ok := true
	for n in sfx_need:
		if not ResourceLoader.exists("res://assets/audio/" + n) and not FileAccess.file_exists("res://assets/audio/" + n):
			sfx_ok = false
	printerr("P9: sfx_ok=" + str(sfx_ok))
	var models: Array = AnimS.catalog_models()
	printerr("P9: anim_models=" + str(models.size()))
	var need_ids := ["player_male", "player_female", "slime", "guardian", "gate_master"]
	var model_ok := true
	for id in need_ids:
		var found := false
		for m in models:
			if str(m.id) == id:
				found = true
		if not found:
			model_ok = false
	printerr("P9: anim_browser_ok=" + str(models.size() >= 16 and model_ok))
	if App.anim_browser and App.anim_browser.has_method("open_browser"):
		App.anim_browser.open_browser()
		printerr("P9: anim_open=" + str(App.anim_browser.open) + " focus=" + str(App.anim_browser.back_btn != null))
		App.anim_browser.close_browser()
	if App.archives_ui and App.archives_ui.has_method("show_browser"):
		App.archives_ui.show_browser()
		printerr("P9: archives_ui=" + str(App.archives_ui.open) + " entries=" + str(App.archives_ui.entries.size()))
		App.archives_ui.hide_browser()
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch := root.path_join("archives")
	printerr("P9: arch_full=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
	printerr("P9: arch_classic=" + str(DirAccess.dir_exists_absolute(arch.path_join("classic_2d"))))
	printerr("P9: arch_art=" + str(DirAccess.dir_exists_absolute(arch.path_join("art_experiment"))))
	var sum: String = App.debug.play.run_medium()
	printerr("P9: playtest=" + sum.replace("\n", " | "))
	var extra := 0
	if player:
		for i in 24:
			var e := EnemyS.new()
			e.position = player.position + Vector3(float(i % 6) * 0.7, 0.0, float(int(i) / 6) * 0.7)
			add_child(e)
			e.setup(Roster.IDS[i % Roster.IDS.size()], App.floor_n)
			extra += 1
	printerr("P9: load_extra=" + str(extra))
	if App.playtest and App.playtest.has_method("begin_smoke"):
		App.playtest.begin_smoke()
	var skills := App.prog.SKILLS.size()
	printerr("P9: skills=" + str(skills) + " sets=" + str(App.prog.SETS.size()))
	printerr("P9: splash=" + str(ResourceLoader.exists("res://scenes/splash.tscn")))
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func():
		var fps := Engine.get_frames_per_second()
		printerr("P9: fps=" + str(fps))
		printerr("P9: fps_ok=" + str(fps >= 55.0 or fps <= 5.0 or fps > 200.0))
		printerr("P9: bitter_ok=" + str(App.bal.bitter_loop_offset > 15.0 and App.bal.bitter_loop_offset < 16.0))
		printerr("P9: checklist_skills=" + str(skills == 11))
		printerr("P9: checklist_sets=" + str(App.prog.SETS.size() == 8))
		printerr("P9: archives_ok=" + str(DirAccess.dir_exists_absolute(arch.path_join("full_3d_pass"))))
		if App.playtest:
			printerr("P9: playtest_live=" + str(App.playtest.live_running))
			printerr("P9: playtest_moved=" + str(App.playtest.moved))
			printerr("P9: playtest_sim=" + str(snapped(App.playtest.sim_t, 0.01)))
			printerr("P9: playtest_live_ok=" + str(App.playtest.moved or App.playtest.sim_t > 0.2))
		get_tree().quit()
	)


