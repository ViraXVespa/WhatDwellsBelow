extends Object

const T := preload("res://scripts/data/tunables.gd")


static func enter_dungeon(host: Node) -> void:
	if host.present and str(host.present.get("_mode")) == "enter":
		return
	if host.playtest and bool(host.playtest.get("live_running")):
		host._after_enter()
		return
	host.save_now()
	host.ui_open = true
	if host.present and host.present.has_method("play_enter"):
		host.get_tree().paused = true
		host.present.play_enter(Callable(host, "_after_enter"))
	else:
		host._after_enter()


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
	host.ui_open = false
	host.interact_prompt = ""
	host.get_tree().paused = false
	Engine.time_scale = 1.0
	if host.music and host.music.has_method("play_hub"):
		host.music.play_hub()
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
	if host.loader:
		host.loader.begin("Placeholdia", "Gathering the square…")
		host.loader.set_progress(0.08)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await preload_hub(host)
	if host.loader:
		host.loader.set_status("Raising Placeholdia…")
	await _ease_progress(host, 0.72, 0.90, 0.45)
	host.go_camp()
	host.ui_open = true
	var guard := 0
	while guard < 240:
		guard += 1
		var s := host.get_tree().current_scene
		if s and str(s.scene_file_path).find("camp") >= 0 and s.is_node_ready():
			break
		if host.loader:
			host.loader.set_progress(0.91)
		await host.get_tree().process_frame
	if host.loader:
		host.loader.set_status("The square holds.")
	await _ease_progress(host, 0.92, 1.0, 0.40)
	await host.get_tree().create_timer(0.12, true, false, true).timeout
	if host.loader:
		host.loader.finish()
	host._menu_loading = false


static func _ease_progress(host: Node, lo: float, hi: float, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	var span := maxf(sec, 0.05)
	while true:
		var u := clampf(float(Time.get_ticks_msec() - t0) / (span * 1000.0), 0.0, 1.0)
		if host.loader:
			host.loader.set_progress(lerpf(lo, hi, u))
		if u >= 1.0:
			break
		await host.get_tree().process_frame


static func _loader_p(host: Node) -> float:
	if host.loader == null:
		return 0.0
	return clampf(float(host.loader.get("_target")), 0.0, 1.0)


static func hub_preload_paths(host: Node) -> PackedStringArray:
	var paths := PackedStringArray([
		host.CAMP_SCENE,
		"res://scripts/world/camp.gd",
		"res://scripts/world/player.gd",
		"res://scripts/world/interact.gd",
		"res://scripts/ui/progress_ui.gd",
		"res://assets/tiles/plaza_grass.png",
		"res://assets/tiles/plaza_ground.png",
		"res://assets/tiles/plaza_ground_b.png",
		"res://assets/sprites/buildings/guild.png",
		"res://assets/sprites/buildings/guild_reception.png",
		"res://assets/sprites/buildings/stall.png",
		"res://assets/props/banner.png",
		"res://assets/sprites/props/banner.png",
		"res://assets/audio/music_hub.wav",
	])
	var kind: String = host.character_type if host.character_type in ["male", "female"] else "male"
	var dirs := PackedStringArray(["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"])
	for d in dirs:
		paths.append("res://assets/sprites/player/%s/idle_%s.png" % [kind, d])
		for i in 4:
			paths.append("res://assets/sprites/player/%s/walk_%s_%d.png" % [kind, d, i])
	var out := PackedStringArray()
	var seen := {}
	for p in paths:
		if seen.has(p):
			continue
		seen[p] = true
		if ResourceLoader.exists(p):
			out.append(p)
	return out


static func preload_hub(host: Node, _t0: int = 0) -> void:
	var paths := hub_preload_paths(host)
	var n := paths.size()
	if n <= 0:
		if host.loader:
			host.loader.set_progress(0.70)
		return
	var sub := not OS.has_feature("web")
	var i := 0
	while i < n:
		var path := paths[i]
		if host.loader:
			host.loader.set_status(hub_status_for(path))
		var file_p := 0.08 + float(i) / float(n) * 0.62
		if host.loader:
			host.loader.set_progress(file_p)
		var err := ResourceLoader.load_threaded_request(path, "", sub)
		if err != OK:
			if host.loader:
				host.loader.set_progress(0.08 + float(i + 1) / float(n) * 0.62)
			i += 1
			await host.get_tree().process_frame
			continue
		var guard := 0
		var done := false
		while guard < 240 and not done:
			guard += 1
			var load_prog: Array = []
			var st := ResourceLoader.load_threaded_get_status(path, load_prog)
			var local := 0.0
			if load_prog.size() > 0:
				local = float(load_prog[0])
			if host.loader:
				host.loader.set_progress(0.08 + (float(i) + clampf(local, 0.0, 1.0)) / float(n) * 0.62)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				done = true
			elif st == ResourceLoader.THREAD_LOAD_FAILED:
				done = true
			elif st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				done = true
			else:
				await host.get_tree().process_frame
		if host.loader:
			host.loader.set_progress(0.08 + float(i + 1) / float(n) * 0.62)
		i += 1
		await host.get_tree().process_frame


static func hub_status_for(path: String) -> String:
	if path.ends_with("camp.tscn") or path.ends_with("camp.gd"):
		return "Unfolding Placeholdia…"
	if path.find("/player/") >= 0:
		return "Waking a delver…"
	if path.find("music_hub") >= 0:
		return "Tuning the square…"
	if path.find("buildings") >= 0 or path.find("banner") >= 0:
		return "Raising the guild row…"
	if path.find("tiles") >= 0:
		return "Gathering the square…"
	return "Crossing the veil…"


static func launch_archive(host: Node, id: String) -> void:
	if host._menu_loading:
		return
	host._menu_loading = true
	host._launch_archive_async(id)


static func archive_label(id: String) -> String:
	for e in T.archive_catalog():
		if str(e.get("id", "")) == id:
			return str(e.get("label", id))
	return id


static func launch_archive_async(host: Node, id: String) -> void:
	await load("res://scripts/data/archives_launch.gd").run(host, id)
