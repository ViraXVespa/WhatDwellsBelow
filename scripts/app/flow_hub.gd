extends Object

## Split from app_flow.gd: _warmup_hub, _hub_player, hub_preload_paths....

const Anim := preload("res://scripts/world/player/player_anim.gd")
const LoadTiming := preload("res://scripts/debug/load_timing.gd")
const HitchLog := preload("res://scripts/debug/hitch_log.gd")
const T := preload("res://scripts/data/tunables.gd")
const UiWarm := preload("res://scripts/ui/ui_warm.gd")
const PlayerSetup := preload("res://scripts/world/player/player_setup.gd")
const PlayerTick := preload("res://scripts/world/player/player_tick.gd")
## Loader milestones: each step's share is its expected time on this platform / machine (loader_weights.gd).
const LoadW := preload("res://scripts/ui/loader_weights.gd")
const PLAYER_LAZY: Array[String] = ["res://scripts/world/player/player_act.gd", "res://scripts/world/player/player_lock.gd", "res://scripts/combat/player_hit.gd"]

static func _warmup_hub(host: Node) -> void:
	LoadTiming.mark("warmup_begin")
	if host.loader:
		host.loader.set_status(App.tr("flow_hub.warming_things_up_for_you"))
		if host.loader.has_method("set_solid"):
			host.loader.set_solid(true)
		host.loader.stage(LoadW.at(&"warm_frame"), LoadW.after(&"warm_frame"))
	await host.get_tree().process_frame  # draw the milestone before the blocking warm-up frame
	var scene: Node = host.get_tree().current_scene
	# Everything the first seconds in camp would add (dummy, aim line, telegraph) is built and drawn here, under the loader.
	if scene and scene.has_method("ensure_dummy"):
		scene.ensure_dummy()
	if scene and scene.has_method("warmup"):
		scene.warmup()
	LoadTiming.mark("warmup_frame")
	var p: Node = _hub_player(host, scene)
	if p and p.body:
		p.body.visible = true
	if p:
		var pin: Vector3 = p.global_position
		Anim.warmup_physics(p)
		p.global_position = Vector3(pin.x, 0.0, pin.z)
	LoadW.done(&"warm_frame")
	if host.loader:
		host.loader.stage(LoadW.at(&"warm_ui"), LoadW.after(&"warm_ui"))
	LoadTiming.mark("warmup_gpu")
	await UiWarm.finish(scene)
	LoadTiming.mark("warmup_ui")
	if scene and scene.has_method("warmup_restore"):
		scene.warmup_restore()
	var bench: Node = host.get_node_or_null("HubBench")
	if bench != null and bench.has_method("pin_zoom"):
		bench.pin_zoom()
	if p:
		HitchLog.mark("warmup_play_zoom")
		var texs: Array = Anim.warmup_texs(p)
		LoadTiming.note("warmup_texs", str(texs.size()))
		for tex in texs:
			Anim.apply_tex(p, tex)
			RenderingServer.force_draw()
		var down: Texture2D = Anim.pose_tex(p, "down")
		if down:
			Anim.apply_tex(p, down)
		p.loc_state = Anim.LOC_IDLE
		p.loc_t = 0.0
		p.walk_t = 0.0
		RenderingServer.force_draw()
		PlayerSetup.ensure_combat_fx(p)
		for path: String in PLAYER_LAZY:  # first unlocked player tick loads these (~130 ms on web)
			PlayerTick._gd(path)
		(load("res://scripts/world/interact.gd") as GDScript).warm()  # first interact compiles interact_act.gd (~8 ms)
		(load("res://scripts/world/player/player_combat.gd") as GDScript).update_aim_line(p)
		p.set_physics_process(true)
	LoadW.done(&"warm_ui")
	if host.loader:
		host.loader.stage(LoadW.at(&"settle"), LoadW.END)
	await pump_fps(host, true)
	LoadW.done(&"settle")
	if host.loader:
		host.loader.set_progress(LoadW.END)
	LoadTiming.mark("warmup_end")

static func _hub_player(host: Node, scene: Node) -> Node:
	if scene and ("player" in scene) and scene.player:
		return scene.player
	return host.get_tree().get_first_node_in_group("player")

static func hub_preload_paths(_host: Node) -> PackedStringArray:
	var out := _hub_paths()
	if OS.has_feature("web"):  # the browser plays the music on the web (scripts/audio/web_music.gd); not in the pck
		out.remove_at(out.find("res://assets/audio/music_hub.wav"))
	return out

static func _hub_paths() -> PackedStringArray:
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
	HitchLog.mark("preload_music")
	if host.music and host.music.has_method("preload_dungeon"):
		var t_mus: int = Time.get_ticks_msec()
		host.music.preload_dungeon()
		LoadTiming.note("music_dungeon", "dt=%d" % (Time.get_ticks_msec() - t_mus))
	var paths := hub_preload_paths(host)
	var n: int = paths.size()
	if n <= 0:
		if host.loader:
			host.loader.set_progress(LoadW.after(&"preload"))
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
		HitchLog.mark("preload_" + path.get_file().get_basename())
		var t_file: int = Time.get_ticks_msec()
		ResourceLoader.load(path)
		LoadTiming.note("file", App.tr("flow_hub.dt") % [path.get_file(), Time.get_ticks_msec() - t_file])
		if host.loader:
			host.loader.stage_at(0.0, LoadW.after(&"preload"), float(i + 1) / float(n))
		i += 1
	LoadTiming.mark("preload_end")
	LoadTiming.note("preload_got", str(n))

static func hub_status_for(path: String) -> String:
	if path.ends_with("camp.tscn") or path.ends_with("camp.gd"):
		return App.tr("flow_hub.unfolding_placeholdia")
	if path.find("/player/") >= 0:
		return App.tr("flow_hub.waking_a_delver")
	if path.find("music_hub") >= 0:
		return App.tr("flow_hub.tuning_the_square")
	if path.find("buildings") >= 0 or path.find("banner") >= 0:
		return App.tr("flow_hub.raising_the_guild_row")
	if path.find("tiles") >= 0:
		return App.tr("common.gathering_the_square")
	return App.tr("flow_hub.crossing_the_veil")

static func pump_fps(host: Node, hub: bool) -> void:
	var t_settle: int = Time.get_ticks_msec()
	await (load("res://scripts/graphics/dyn_res.gd") as GDScript).warm(host)
	var good: int = 0
	var steady: int = 0
	var n: int = 0
	var last_dt: int = 0
	var prev_dt: int = -1
	var cap: int = int(T.WARM_HUB_FRAMES_MAX) if hub else int(T.WARM_FRAMES_MAX)
	while n < cap:
		var t0: int = Time.get_ticks_usec()
		RenderingServer.force_draw()
		await host.get_tree().process_frame
		last_dt = int((Time.get_ticks_usec() - t0) / 1000.0)
		n += 1
		if hub and host.loader and bool(host.loader.get("open")):
			# Time-based: frame counts differ by platform (a few short frames on desktop, ~6 slow ones on web).
			host.loader.stage_at(LoadW.at(&"settle"), LoadW.END, float(Time.get_ticks_msec() - t_settle) / LoadW.expect(&"settle"))
		good = good + 1 if last_dt <= 17 else 0
		steady = steady + 1 if prev_dt >= 0 and absi(last_dt - prev_dt) <= int(T.WARM_STEADY_MS) else 0
		prev_dt = last_dt
		# Hub stays covered until two frames are on the 60 FPS budget. A slow plateau is not a reveal.
		# Other pumps still accept a steady slow device so the bar cannot sit there.
		var settled: bool = good >= 2
		if not hub and steady >= int(T.WARM_STEADY_N):
			settled = true
		if settled:
			break
	var ok_s: String = "1" if good >= 2 else "0"
	if hub:
		LoadTiming.note("warm_frames", str(n))
		LoadTiming.note("fps_ok", ok_s)
		LoadTiming.note("warm_last_dt", str(last_dt))
		LoadTiming.note("warm_steady", str(steady))
	else:
		LoadTiming.dnote("warm_frames", str(n))
		LoadTiming.dnote("fps_ok", ok_s)
		LoadTiming.dnote("warm_last_dt", str(last_dt))
		LoadTiming.dnote("warm_steady", str(steady))
