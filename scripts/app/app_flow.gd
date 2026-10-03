extends Object

const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const AppRunS := preload("res://scripts/app/app_run.gd")

const Hub := preload("res://scripts/app/flow_hub.gd")
static func enter_dungeon(host: Node) -> void:
	if host.present and str(host.present.get("_mode")) == "enter":
		return
	if host.present and bool(host.present.get("_enter_load")):
		return
	if host.present and str(host.present.get("_mode")) == "enter_hold" and bool(host.in_dungeon):
		return
	if host.playtest and bool(host.playtest.get("live_running")):
		AppRunS.ensure_dungeon_packed(host)
		host._after_enter()
		return
	var holding: bool = host.present != null and str(host.present.get("_mode")) == "enter_hold"
	if host.present and host.present.has_method("cover_enter"):
		if not holding:
			host.present.cover_enter()
		host.present.set("_enter_load", true)
		host.ui_open = true
		if host.present.has_method("wait_painted"):
			await host.present.wait_painted()
		host.sfx("enter")
		_close_hub_ui(host)
		host.save_now()
		AppRunS.ensure_dungeon_packed(host)
		host._after_enter()
	elif host.present and host.present.has_method("play_enter"):
		host.save_now()
		host.ui_open = true
		host.get_tree().paused = true
		host.present.play_enter(Callable(host, "_after_enter"))
	else:
		host.save_now()
		host.ui_open = true
		AppRunS.ensure_dungeon_packed(host)
		host._after_enter()

static func _close_hub_ui(host: Node) -> void:
	var scene: Node = host.get_tree().current_scene
	if scene == null:
		return
	var raw: Variant = scene.get("ui")
	if raw is CanvasLayer:
		var ui: CanvasLayer = raw as CanvasLayer
		if ui.has_method("close_ui") and bool(ui.get("open")):
			ui.close_ui()

static func go_title(host: Node) -> void:
	host.in_dungeon = false
	host.ui_open = false
	if host.present and host.present.has_method("hide_overlay"):
		host.present.hide_overlay()
	if host.music and host.music.has_method("stop_music"):
		host.music.stop_music()
	host.get_tree().paused = false
	Engine.time_scale = 1.0
	host.get_tree().call_deferred("change_scene_to_file", host.TITLE_SCENE)
	host.call_deferred("wake_web_pad")

static func go_foundation(host: Node) -> void:
	host.in_dungeon = true
	host.get_tree().paused = false
	Engine.time_scale = 1.0
	host.get_tree().call_deferred("change_scene_to_file", host.FOUNDATION_SCENE)

static func go_camp(host: Node) -> void:
	host.in_dungeon = false
	if host.recap == null or not bool(host.recap.visible):
		host.ui_open = false
	host.interact_prompt = ""
	host.get_tree().paused = false
	Engine.time_scale = 1.0
	if host.music and host.music.has_method("play_hub"):
		host.music.play_hub()
	var packed: Resource = ResourceLoader.load(host.CAMP_SCENE)
	if packed is PackedScene:
		host.get_tree().call_deferred("change_scene_to_packed", packed)
	else:
		host.get_tree().call_deferred("change_scene_to_file", host.CAMP_SCENE)
	host.call_deferred("wake_web_pad")

static func play_from_menu(host: Node) -> void:
	if host._menu_loading:
		return
	if host.playtest and bool(host.playtest.get("live_running")):
		host.go_camp()
		return
	host._menu_loading = true
	host._play_from_menu_async()

static func play_from_menu_async(host: Node) -> void:
	LoadTiming.mark("play_begin")
	if host.loader:
		host.loader.begin("Placeholdia", App.tr("common.gathering_the_square"))
		host.loader.set_progress(0.08)
	await host.get_tree().process_frame
	LoadTiming.mark("loader_paint")
	preload_hub(host)
	if host.loader:
		host.loader.set_status(App.tr("app_flow.raising_placeholdia"))
		host.loader.set_progress(0.90)
	await host.get_tree().process_frame
	LoadTiming.mark("camp_change")
	host.go_camp()
	host.ui_open = true
	var guard := 0
	while guard < 240:
		guard += 1
		var s := host.get_tree().current_scene
		if s and s.is_node_ready() and (str(s.scene_file_path).find("camp") >= 0 or str(s.name) == "Camp"):
			break
		if host.loader:
			host.loader.set_progress(0.91)
		await host.get_tree().process_frame
	LoadTiming.mark("camp_ready")
	LoadTiming.note("camp_wait_frames", str(guard))
	await Hub._warmup_hub(host)
	var scene: Node = host.get_tree().current_scene
	if host.loader:
		host.loader.finish()
	host._menu_loading = false
	if scene and ("player" in scene) and scene.player:
		scene.player.set_physics_process(true)
	LoadTiming.note("camp_ui", "deferred")
	LoadTiming.mark("loader_finish")
	LoadTiming.finish()
	if scene and scene.has_method("ensure_dummy"):
		scene.ensure_dummy()

static func dungeon_load_timing_async(host: Node) -> void:
	host.go_camp()
	var hub_guard: int = 0
	while hub_guard < 240:
		hub_guard += 1
		var hub: Node = host.get_tree().current_scene
		if hub and hub.is_node_ready() and (str(hub.scene_file_path).find("camp") >= 0 or str(hub.name) == "Camp"):
			break
		await host.get_tree().process_frame
	LoadTiming.dnote("hub_wait_frames", str(hub_guard))
	LoadTiming.dmark("hub_ready")
	AppRunS.ensure_dungeon_packed(host)
	LoadTiming.dmark("dungeon_pack")
	LoadTiming.dmark("enter_begin")
	host.save_now()
	LoadTiming.dmark("save")
	host.ui_open = false
	if host.present and host.present.has_method("hide_overlay"):
		host.present.hide_overlay()
	host._after_enter()
	host.floor_n = 1
	host.run_seed = 42
	LoadTiming.dnote("seed", str(host.run_seed))
	LoadTiming.dnote("floor", str(host.floor_n))
	var dun_guard: int = 0
	while dun_guard < 240:
		dun_guard += 1
		var dun: Node = host.get_tree().current_scene
		if dun and dun.is_node_ready() and (str(dun.scene_file_path).find("dungeon") >= 0 or str(dun.name) == "Dungeon"):
			break
		await host.get_tree().process_frame
	LoadTiming.dmark("dungeon_scene")
	LoadTiming.dnote("dungeon_wait_frames", str(dun_guard))
	await pump_fps(host, false)
	if host.present and host.present.has_method("release_enter"):
		host.present.release_enter()
	LoadTiming.dmark("dungeon_ready")
	LoadTiming.finish()

static func pump_fps(host: Node, hub: bool) -> void:
	await Hub.pump_fps(host, hub)

static func preload_hub(host: Node, _t0: int = 0) -> void:
	Hub.preload_hub(host, _t0)

static func launch_archive(host: Node, id: String) -> void:
	if host._menu_loading:
		return
	host._menu_loading = true
	host._launch_archive_async(id)

static func launch_archive_async(host: Node, id: String) -> void:
	await load("res://scripts/data/archives/launch.gd").run(host, id)
