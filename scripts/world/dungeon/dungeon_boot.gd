extends Object

const Dbg := preload("res://scripts/app/dbg.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const PlayerS := preload("res://scripts/world/player.gd")
const DoorS := preload("res://scripts/world/boss_door.gd")
const SpotS := preload("res://scripts/world/interact.gd")
const DungeonStream := preload("res://scripts/world/dungeon_stream.gd")
const CrystalNet := preload("res://scripts/world/crystal/net.gd")
const DungeonMinimap := preload("res://scripts/world/dungeon/minimap.gd")

static var _first_tick: bool = true

static func ready_floor(host: Node) -> void:
	_first_tick = true
	Dbg.hitch("dungeon_ready")
	Dbg.lt_dmark("dungeon_enter")
	App.in_dungeon = true
	CrystalNet.arrive()
	host.data = Gen.generate(App.floor_n, App.run_seed, App.bal)
	if not host.data.get("ok", false):
		host.data = Gen.generate(App.floor_n, App.run_seed + 17, App.bal)
	host.visited = PackedByteArray()
	host.visited.resize(int(host.data.w) * int(host.data.h))
	host.visited.fill(0)
	DungeonMinimap.forget()
	Dbg.hitch("dungeon_gen")
	Dbg.lt_dmark("gen")
	Dbg.lt_dnote("gen_ok", str(host.data.get("ok", false)))
	Dbg.lt_dnote("rooms", str((host.data.get("rooms", []) as Array).size()))
	Dbg.lt_dnote("w", str(int(host.data.get("w", 0))))
	Dbg.lt_dnote("h", str(int(host.data.get("h", 0))))
	host._build_travel()
	Dbg.lt_dmark("travel")
	host._world()
	Dbg.lt_dmark("world")
	host._collision_walls()
	Dbg.lt_dmark("collision")
	host._build_visuals()
	Dbg.lt_dmark("visuals")
	host._spawns()
	Dbg.lt_dmark("spawns")
	host._hud()
	Dbg.lt_dmark("hud")
	host._map()
	Dbg.lt_dnote("map", "built")
	Dbg.lt_dmark("map")
	host._reveal_around(host.data.spawn, int(App.bal.fog_radius) + 2)
	if host.player:
		host._reveal_around(host._world_cell(host.player.global_position), int(App.bal.fog_radius) + 2)
	host._redraw_map()
	if host.hud and host.hud.has_method("bind_map") and host.map_tex:
		host.hud.bind_map(host.map_tex)
	Dbg.lt_dmark("reveal")
	var GeoStreamS: GDScript = load("res://scripts/world/dungeon_geo/geo_stream.gd") as GDScript
	GeoStreamS.prime_visible(host)
	Dbg.hitch("dungeon_follow")
	Dbg.lt_dmark("stream")
	var LightRtS: GDScript = load("res://scripts/graphics/light_rt.gd") as GDScript
	LightRtS.reset_floor()
	LightRtS.maintain(host)
	LightRtS.maintain(host)
	(load("res://scripts/graphics/torch_bill.gd") as GDScript).warm(host)
	Dbg.hitch("dungeon_light")
	Dbg.lt_dmark("light")
	if App:
		App.set("_enter_pumped", false)
		App.call_deferred("_pump_enter_async")
	Dbg.smoke_attach("dungeon", host)

static func process_floor(host: Node, delta: float) -> void:
	if _first_tick:
		Dbg.hitch("dungeon_tick")
		var LightRtS: GDScript = load("res://scripts/graphics/light_rt.gd") as GDScript
		LightRtS.maintain(host)
		_first_tick = false
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
		if host.map_layer == null:
			host._map()
			if host.hud and host.hud.has_method("bind_map") and host.map_tex:
				host.hud.bind_map(host.map_tex)
		if host.map_layer:
			host.map_layer.visible = not host.map_layer.visible
			if host.map_layer.visible:
				var MapActS: GDScript = load("res://scripts/world/dungeon/map_act.gd") as GDScript
				MapActS.reset(host)
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
	Dbg.lt_dmark("spawn_player")
	host._place_doors()
	Dbg.lt_dmark("spawn_doors")
	var st: Vector2i = host.data.stairs
	host.stairs = SpotS.new()
	host.stairs.setup("stairs", Vector3(float(st.x) + 0.5, 0.0, float(st.y) + 0.5), not App.boss_dead)
	host.add_child(host.stairs)
	Dbg.lt_dmark("spawn_stairs")
	CrystalNet.place_floor(host)
	Dbg.lt_dmark("spawn_crystals")
	Dbg.lt_dnote("spawn_jobs", "deferred")
	Dbg.lt_dmark("spawn_jobs")
	var bp: Vector2i = host.data.boss
	var boss_job: Dictionary = DungeonStream.new_job(host, "boss", bp, {}, PackedStringArray(), false, str(host.data.boss_role))
	host.spawn_jobs.append(boss_job)
	Dbg.lt_dmark("spawn_boss")
	var SpawnS: GDScript = load("res://scripts/world/dungeon_props/spawn.gd") as GDScript
	SpawnS.spawn_world(host)
	host.set_meta("props_booted", true)
	Dbg.lt_dmark("spawn_props")
	Dbg.lt_dnote("spawn_ambushes", "deferred")
	Dbg.lt_dmark("spawn_ambushes")
	CrystalNet.silence_on(host)
	Dbg.lt_dnote("spawn_ui", "deferred")
	Dbg.lt_dmark("spawn_ui")

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
