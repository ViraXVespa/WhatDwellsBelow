extends Object

## Split from app_flow.gd: _warmup_hub, _hub_player, hub_preload_paths....

const Anim := preload("res://scripts/world/player/player_anim.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")

static func _warmup_hub(host: Node) -> void:
	LoadTiming.mark("warmup_begin")
	if host.loader:
		host.loader.set_status("Warming things up for you...")
		if host.loader.has_method("set_solid"):
			host.loader.set_solid(true)
		host.loader.set_progress(0.94)
	var scene: Node = host.get_tree().current_scene
	if scene and scene.has_method("warmup"):
		scene.warmup()
	LoadTiming.mark("warmup_frame")
	var p: Node = _hub_player(host, scene)
	if p and p.body:
		p.body.visible = true
	if p:
		var pin: Vector3 = p.global_position
		var texs: Array = Anim.warmup_texs(p)
		LoadTiming.note("warmup_texs", str(texs.size()))
		for tex in texs:
			Anim.apply_tex(p, tex)
		Anim.warmup_physics(p)
		p.global_position = Vector3(pin.x, 0.0, pin.z)
		var down: Texture2D = Anim.pose_tex(p, "down")
		if down:
			Anim.apply_tex(p, down)
		p.loc_state = Anim.LOC_IDLE
		p.loc_t = 0.0
		p.walk_t = 0.0
		RenderingServer.force_draw()
		if host.loader:
			host.loader.set_progress(0.97)
	LoadTiming.mark("warmup_gpu")
	if scene and scene.has_method("warmup_restore"):
		scene.warmup_restore()
	await pump_fps(host, true)
	if host.loader:
		host.loader.set_progress(0.98)
	LoadTiming.mark("warmup_end")

static func _hub_player(host: Node, scene: Node) -> Node:
	if scene and ("player" in scene) and scene.player:
		return scene.player
	return host.get_tree().get_first_node_in_group("player")

static func hub_preload_paths(_host: Node) -> PackedStringArray:
	return PackedStringArray([
		"res://assets/sprites/buildings/guild.png",
		"res://assets/sprites/buildings/guild_reception.png",
		"res://assets/sprites/buildings/stall.png",
		"res://assets/sprites/props/welcome_banner.png",
		"res://assets/sprites/props/crystal.png",
		"res://assets/sprites/props/anvil.png",
		"res://assets/sprites/props/notice_board.png",
		"res://assets/sprites/props/dumpster.png",
		"res://assets/sprites/props/sign.png",
		"res://assets/sprites/npcs/vendor.png",
		"res://assets/sprites/npcs/receptionist.png",
		"res://assets/sprites/npcs/shopkeep.png",
		"res://assets/sprites/player/male/idle_down.png",
		"res://assets/sprites/player/male/idle_up.png",
		"res://assets/sprites/player/male/idle_left.png",
		"res://assets/sprites/player/male/idle_right.png",
		"res://assets/fx/dummy.png",
		"res://assets/audio/music_hub.wav",
	])

static func preload_hub(host: Node, _t0: int = 0) -> void:
	var paths := hub_preload_paths(host)
	var n: int = paths.size()
	if n <= 0:
		if host.loader:
			host.loader.set_progress(0.70)
		return
	LoadTiming.mark("preload_begin")
	LoadTiming.note("files", str(n))
	LoadTiming.note("batch", "sync")
	LoadTiming.note("sub_threads", "false")
	LoadTiming.note("web", str(OS.has_feature("web")))
	var i: int = 0
	while i < n:
		var path: String = paths[i]
		if host.loader:
			host.loader.set_status(hub_status_for(path))
		var t_file: int = Time.get_ticks_msec()
		ResourceLoader.load(path)
		LoadTiming.note("file", "%s dt=%d" % [path.get_file(), Time.get_ticks_msec() - t_file])
		if host.loader:
			host.loader.set_progress(0.08 + float(i + 1) / float(n) * 0.62)
		i += 1
	LoadTiming.mark("preload_end")
	LoadTiming.note("preload_got", str(n))

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

static func pump_fps(host: Node, hub: bool) -> void:
	var good: int = 0
	var n: int = 0
	var last_dt: int = 0
	while n < 12:
		var t0: int = Time.get_ticks_usec()
		RenderingServer.force_draw()
		await host.get_tree().process_frame
		last_dt = int((Time.get_ticks_usec() - t0) / 1000)
		n += 1
		if last_dt <= 17:
			good += 1
			if good >= 2:
				break
		else:
			good = 0
	var ok_s: String = "1" if good >= 2 else "0"
	if hub:
		LoadTiming.note("warm_frames", str(n))
		LoadTiming.note("fps_ok", ok_s)
		LoadTiming.note("warm_last_dt", str(last_dt))
	else:
		LoadTiming.dnote("warm_frames", str(n))
		LoadTiming.dnote("fps_ok", ok_s)
		LoadTiming.dnote("warm_last_dt", str(last_dt))
