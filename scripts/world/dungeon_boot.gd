extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const EnemyS := preload("res://scripts/combat/enemy.gd")
const Roster := preload("res://scripts/combat/roster.gd")
const DoorS := preload("res://scripts/world/boss_door.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const UiS := preload("res://scripts/ui/progress_ui.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const DungeonStream := preload("res://scripts/world/dungeon_stream.gd")
const DungeonProps := preload("res://scripts/world/dungeon_props.gd")
const CrystalNet := preload("res://scripts/world/crystal_net.gd")


static func ready_floor(host: Node) -> void:
	App.in_dungeon = true
	if App.present and App.present.has_method("hide_overlay"):
		App.present.hide_overlay()
	CrystalNet.arrive()
	host.data = Gen.generate(App.floor_n, App.run_seed, App.bal)
	if not host.data.get("ok", false):
		host.data = Gen.generate(App.floor_n, App.run_seed + 17, App.bal)
	host.visited = PackedByteArray()
	host.visited.resize(int(host.data.w) * int(host.data.h))
	host.visited.fill(0)
	host._build_travel()
	host._world()
	host._collision_walls()
	host._build_visuals()
	host._spawns()
	host._hud()
	host._map()
	host._reveal_around(host.data.spawn, int(App.bal.fog_radius) + 2)
	if host.player:
		host._reveal_around(host._world_cell(host.player.global_position), int(App.bal.fog_radius) + 2)
	DungeonStream.tick(host, 1.0)
	Smoke.attach_dungeon(host)


static func process_floor(host: Node, delta: float) -> void:
	host.frame_acc += delta
	host.frame_n += 1
	if host.frame_acc >= 0.5:
		host.frame_acc = 0.0
		host.frame_n = 0
	if host.player:
		var t: Vector2i = Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))
		var grew: bool = host._reveal_around(t, int(App.bal.fog_radius))
		host._tick_pressure(delta, grew)
		DungeonStream.tick(host, delta)
		CrystalNet.guard(host)
		if grew:
			host.fog_dirty = true
	host._note_verge()
	host._tick_plates()
	if host.fog_dirty or (host.map_layer and host.map_layer.visible):
		host._redraw_map()
		CrystalNet.paint(host)
		host.fog_dirty = false
	if App.pause_just() if App.has_method("pause_just") else (Input.is_action_just_pressed("pause") or App.pad_just("pause")):
		if App.debug and App.debug.get("open"):
			pass
		elif App.recap and App.recap.get("open"):
			pass
		elif App.ui_open and host.ui and host.ui.has_method("close_ui") and host.ui.visible:
			host.ui.close_ui()
			if App.has_method("swallow_close_pad"):
				App.swallow_close_pad()
		elif App.pause_menu and App.pause_menu.has_method("toggle"):
			App.pause_menu.toggle()
	if Input.is_action_just_pressed("map_view") or App.pad_just("map_view"):
		if host.map_layer:
			host.map_layer.visible = not host.map_layer.visible
			if host.map_layer.visible:
				host._redraw_map()
				CrystalNet.paint(host)
	if host.stairs:
		host.stairs.refresh()
	host._refresh_hint()


static func spawns(host: Node) -> void:
	host.floor_rng.seed = App.run_seed * 10007 + App.floor_n * 9176
	host.spawn_jobs.clear()
	host.player = PlayerS.new()
	var land: Vector2i = CrystalNet.landing_cell(host)
	host.player.position = Vector3(float(land.x) + 1.5, 0.0, float(land.y) + 0.5)
	host.add_child(host.player)
	host._place_doors()
	var st: Vector2i = host.data.stairs
	host.stairs = SpotS.new()
	host.stairs.setup("stairs", Vector3(float(st.x) + 0.5, 0.0, float(st.y) + 0.5), not App.boss_dead)
	host.add_child(host.stairs)
	CrystalNet.place_floor(host)
	var pool: PackedStringArray = Roster.floor_types(App.floor_n)
	DungeonStream.queue_initial(host, pool)
	var boss: Node = EnemyS.new()
	var bp: Vector2i = host.data.boss
	boss.position = Vector3(float(bp.x) + 0.5, 0.0, float(bp.y) + 0.5)
	host.add_child(boss)
	boss.setup_boss(str(host.data.boss_title), App.floor_n)
	boss.group_id = host.next_group
	host.next_group += 1
	if App.boss_dead:
		host._on_boss_dead()
	DungeonProps.spawn_world(host)
	DungeonStream.queue_ambushes(host, pool)
	CrystalNet.silence_on(host)
	host.ui = UiS.new()
	host.add_child(host.ui)


static func place_doors(host: Node) -> void:
	host.doors.clear()
	var openings: Array = host.data.get("openings", [])
	if openings.is_empty():
		var boss_r: Dictionary = {}
		for r: Variant in host.data.get("rooms", []):
			if str(r.get("kind", "")) == "boss":
				boss_r = r
				break
		if not boss_r.is_empty():
			openings = Gen.boss_openings(host.data.grid, int(host.data.w), int(host.data.h), boss_r)
	if openings.is_empty():
		var c: Vector2i = host.data.door
		openings = [Gen.make_opening("s", [c])]
	for o: Variant in openings:
		if o.is_empty():
			continue
		var d: Node = DoorS.new()
		d.setup_opening(o)
		host.add_child(d)
		host.doors.append(d)
	host.door = host.doors[0] if not host.doors.is_empty() else null


static func on_boss_dead(host: Node) -> void:
	App.boss_dead = true
	CrystalNet.note_boss()
	for d: Variant in host.doors:
		if d and d.has_method("open_door"):
			d.open_door()
	if host.door and host.door.has_method("open_door"):
		host.door.open_door()
	for n: Node in host.get_tree().get_nodes_in_group("interact"):
		if n.has_method("refresh"):
			n.refresh()
	if host._cleared:
		return
	host._cleared = true
	var chest: Node = SpotS.new()
	var bp: Vector2i = host._free_near(host.data.boss)
	var gate: bool = bool(host.data.get("gate_master", false)) or Gen.is_gate_master(App.floor_n)
	chest.setup("chest" if gate else "base_chest", host._cell_pos(bp), false)
	host.add_child(chest)
	host._mark_cell(bp)
