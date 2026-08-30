extends Node

const T := preload("res://scripts/data/tunables.gd")
const BalanceS := preload("res://scripts/data/balance.gd")
const DebugS := preload("res://scripts/combat/debug_menu.gd")
const SfxS := preload("res://scripts/combat/sfx.gd")
const ProgressS := preload("res://scripts/data/progress.gd")
const TelS := preload("res://scripts/debug/telemetry.gd")
const PauseS := preload("res://scripts/ui/pause_menu.gd")
const RecapS := preload("res://scripts/ui/recap.gd")
const Store := preload("res://scripts/data/save_store.gd")
const PresentS := preload("res://scripts/ui/present.gd")
const MusicS := preload("res://scripts/audio/music.gd")
const AnimS := preload("res://scripts/debug/anim_browser.gd")
const ArchS := preload("res://scripts/ui/archives_ui.gd")
const PlayS := preload("res://scripts/debug/playtest.gd")
const LoaderS := preload("res://scripts/ui/loader.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const Binds := preload("res://scripts/input/binds.gd")
const Pad := preload("res://scripts/input/pad.gd")

var character_type := "male"
var character_chosen := false
var weapon := "great_axe"
var cam_zoom := 1.0
var hud_scale := 1.0
var vol_master := 1.0
var vol_music := 0.7
var vol_sfx := 0.85
var in_dungeon := false
var floor_n := 1
var run_seed := 1
var boss_dead := false
var interact_prompt := ""
var floors_since_named := 99
var quest_named_type := ""
var quest_named_name := ""
var gold := 0
var ore := 0
var wood := 0
var bank_gold := 0
var bank_ore := 0
var bank_wood := 0
var bank_root := 0
var mine_lv := 1
var wood_lv := 1
var mine_xp := 0.0
var wood_xp := 0.0
var pickaxe_q := 1
var hatchet_q := 1
var run_artifacts: Array[String] = []
var shrine_t := 0.0
var toast_msg := ""
var toast_t := 0.0
var ui_open := false
var extracted := false
var clerk_t := -1.0
var mine_hits_landed := 0
var mine_success := 0
var wood_hits_landed := 0
var wood_success := 0
var shop_buys := 0
var shop_spent := 0
var prog: ProgressS
var bal: BalanceS
var sfx_node: Node
var debug
var pause_menu
var recap
var present
var music
var anim_browser
var archives_ui
var playtest
var loader
var _menu_loading := false
var tel: TelS
var wake_pending := false
var saw_stairs := false
var boss_low := false
var run_hp := -1.0
var adrenaline := false
var adrenaline_xp := 1.0
var run_xp := 0.0
var clock := 0.0
var last_kill := -999.0
var last_style := "str"
var kill_times: Array[float] = []
var _seq := 0
var _seq_timer := 0.0
var _seq_down := false

const TITLE_SCENE := "res://scenes/title.tscn"
const FOUNDATION_SCENE := "res://scenes/foundation.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bal = BalanceS.new()
	prog = ProgressS.new()
	Binds.register()
	sfx_node = SfxS.new()
	add_child(sfx_node)
	tel = TelS.new()
	playtest = PlayS.new()
	add_child(playtest)
	debug = DebugS.new()
	add_child(debug)
	pause_menu = PauseS.new()
	add_child(pause_menu)
	recap = RecapS.new()
	add_child(recap)
	present = PresentS.new()
	add_child(present)
	music = MusicS.new()
	add_child(music)
	anim_browser = AnimS.new()
	add_child(anim_browser)
	archives_ui = ArchS.new()
	add_child(archives_ui)
	loader = LoaderS.new()
	add_child(loader)
	if not Smoke.active():
		Store.load_slot("live")
	if "--wdb-debug" in OS.get_cmdline_user_args():
		call_deferred("_open_debug")


func _open_debug() -> void:
	if debug and debug.has_method("show_menu"):
		debug.show_menu()


func save_now() -> void:
	if playtest and bool(playtest.get("live_running")):
		Store.save_slot(str(playtest.slot))
		return
	Store.save_slot("live")


func wipe_save() -> void:
	Store.wipe_slot("live")
	Store.fresh_delver()
	save_now()


func enter_dungeon() -> void:
	if present and str(present.get("_mode")) == "enter":
		return
	if playtest and bool(playtest.get("live_running")):
		_after_enter()
		return
	save_now()
	ui_open = true
	if present and present.has_method("play_enter"):
		get_tree().paused = true
		present.play_enter(Callable(self, "_after_enter"))
	else:
		_after_enter()


func _after_enter() -> void:
	ui_open = false
	begin_run()


func go_title() -> void:
	in_dungeon = false
	ui_open = false
	if present and present.has_method("hide_overlay"):
		present.hide_overlay()
	if music and music.has_method("stop_music"):
		music.stop_music()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)
	call_deferred("wake_web_pad")


func go_foundation() -> void:
	in_dungeon = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", FOUNDATION_SCENE)


func go_camp() -> void:
	in_dungeon = false
	ui_open = false
	interact_prompt = ""
	get_tree().paused = false
	Engine.time_scale = 1.0
	if music and music.has_method("play_hub"):
		music.play_hub()
	get_tree().call_deferred("change_scene_to_file", CAMP_SCENE)
	call_deferred("wake_web_pad")


func play_from_menu() -> void:
	if _menu_loading:
		return
	if playtest and bool(playtest.get("live_running")):
		go_camp()
		return
	_menu_loading = true
	_play_from_menu_async()


func _play_from_menu_async() -> void:
	if loader:
		loader.begin("Placeholdia", "Gathering the square…")
	await _preload_hub()
	if loader:
		loader.set_status("Raising Placeholdia…")
		loader.set_progress(0.96)
	go_camp()
	ui_open = true
	var guard := 0
	while guard < 180:
		guard += 1
		var s := get_tree().current_scene
		if s and str(s.scene_file_path).find("camp") >= 0 and s.is_node_ready():
			break
		await get_tree().process_frame
	if loader:
		loader.set_progress(1.0)
		loader.set_status("The square holds.")
		await get_tree().create_timer(0.12, true, false, true).timeout
		loader.finish()
	_menu_loading = false


func _hub_preload_paths() -> PackedStringArray:
	var paths := PackedStringArray([
		CAMP_SCENE,
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
	var kind := character_type if character_type in ["male", "female"] else "male"
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


func _preload_hub() -> void:
	var paths := _hub_preload_paths()
	var n := paths.size()
	if n <= 0:
		if loader:
			loader.set_progress(0.9)
		return
	var sub := not OS.has_feature("web")
	for i in n:
		var path := paths[i]
		if loader:
			loader.set_status(_hub_status_for(path))
		var err := ResourceLoader.load_threaded_request(path, "", sub)
		if err != OK:
			if loader:
				loader.set_progress(float(i + 1) / float(n) * 0.92)
			continue
		var guard := 0
		while guard < 240:
			guard += 1
			var load_prog: Array = []
			var st := ResourceLoader.load_threaded_get_status(path, load_prog)
			var local := float(load_prog[0]) if load_prog.size() > 0 else 0.0
			if loader:
				loader.set_progress((float(i) + clampf(local, 0.0, 1.0)) / float(n) * 0.92)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				break
			if st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			await get_tree().process_frame
		if loader:
			loader.set_progress(float(i + 1) / float(n) * 0.92)


func _hub_status_for(path: String) -> String:
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


func begin_run() -> void:
	floor_n = maxi(1, prog.start_floor)
	run_seed = randi()
	if run_seed == 0:
		run_seed = 1
	boss_dead = false
	saw_stairs = false
	boss_low = false
	run_xp = 0.0
	adrenaline = false
	last_style = "str"
	floors_since_named = 0
	shrine_t = 0.0
	extracted = false
	run_hp = -1.0
	clerk_t = -1.0
	mine_hits_landed = 0
	mine_success = 0
	wood_hits_landed = 0
	wood_success = 0
	shop_buys = 0
	shop_spent = 0
	ui_open = false
	prog.begin_run_loadout()
	weapon = str(prog.slots.weapon.get("weapon", "great_axe")) if not prog.slots.weapon.is_empty() else "great_axe"
	if playtest == null or not bool(playtest.get("live_running")):
		tel.reset("human", false)
	go_dungeon()


func go_dungeon() -> void:
	in_dungeon = true
	interact_prompt = ""
	get_tree().paused = false
	if playtest == null or not bool(playtest.get("live_running")):
		Engine.time_scale = 1.0
	if music and music.has_method("play_dungeon") and str(music.get("kind")) != "dungeon":
		music.play_dungeon()
	get_tree().call_deferred("change_scene_to_file", DUNGEON_SCENE)
	call_deferred("wake_web_pad")


func next_floor() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		run_hp = float(p.get("hp"))
	floor_n += 1
	prog.deepest = maxi(prog.deepest, floor_n)
	boss_dead = false
	interact_prompt = ""
	shrine_t = 0.0
	ui_open = false
	go_dungeon()


func notify_boss_dead() -> void:
	boss_dead = true
	var s := get_tree().current_scene
	if s and s.has_method("_on_boss_dead"):
		s._on_boss_dead()


func set_character(kind: String) -> void:
	if kind != "male" and kind != "female":
		kind = "male"
	character_type = kind
	character_chosen = true


func gain_gold(n: int) -> void:
	n = maxi(0, n)
	if n <= 0:
		return
	gold += n
	if tel:
		tel.gold_gained += n


func sfx(name: String) -> void:
	if sfx_node and sfx_node.has_method("play"):
		sfx_node.play(name)


func hitstop(sec: float) -> void:
	if playtest and bool(playtest.get("live_running")):
		return
	if sec <= 0.0:
		return
	if Engine.time_scale < 0.5:
		return
	Engine.time_scale = 0.07
	get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func end_run(cond: String, killer := "") -> void:
	if recap and bool(recap.get("open")):
		return
	if not in_dungeon:
		toast("Already on the surface.")
		return
	if playtest and bool(playtest.get("live_running")):
		finish_end(cond, killer)
		return
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("play_exit") and not bool(p.get("exiting")):
		p.play_exit(cond, killer)
		return
	finish_end(cond, killer)


func finish_end(cond: String, killer := "") -> void:
	if recap and bool(recap.get("open")):
		return
	if cond == "dispel":
		sfx("thud")
	elif cond == "death":
		sfx("hurk")
	if tel:
		tel.note_end(cond, killer)
	get_tree().paused = false
	if recap and recap.has_method("play"):
		recap.play(cond)
	else:
		go_camp()


func set_volume(which: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if which == "master":
		vol_master = v
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, v)))
	elif which == "music":
		vol_music = v
		if music and music.has_method("_apply_vol"):
			music._apply_vol()
	else:
		vol_sfx = v
		if sfx_node and sfx_node.has_method("_apply_vol"):
			sfx_node._apply_vol()
		elif sfx_node:
			for c in sfx_node.get_children():
				if c is AudioStreamPlayer:
					(c as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.001, vol_sfx * vol_master))
	if which == "master":
		if music and music.has_method("_apply_vol"):
			music._apply_vol()
		if sfx_node and sfx_node.has_method("_apply_vol"):
			sfx_node._apply_vol()


func set_zoom(z: float) -> void:
	cam_zoom = clampf(z, 1.0, 1.75)
	var p := get_tree().get_first_node_in_group("player")
	if p:
		var rig = p.get("rig")
		if rig and rig.has_method("apply_zoom"):
			rig.apply_zoom(cam_zoom)


func on_kill() -> void:
	last_kill = clock
	kill_times.append(clock)
	while kill_times.size() > 0 and clock - kill_times[0] > bal.adrenaline_window:
		kill_times.remove_at(0)
	if adrenaline:
		adrenaline_xp += bal.adrenaline_xp_stack
	elif kill_times.size() >= int(bal.adrenaline_kills):
		_start_adrenaline()
	var mult := adrenaline_xp if adrenaline else 1.0
	run_xp += bal.xp_per_kill * mult
	if prog:
		var half: float = bal.xp_per_kill * 0.5 * (mult if adrenaline else 1.0)
		if weapon == "staff":
			prog.add_run_xp("staff", half)
			prog.add_run_xp(last_style if last_style == "mag" else "str", half)
		elif weapon == "longbow":
			prog.add_run_xp("bow", half)
			prog.add_run_xp("rng", half)
		else:
			prog.add_run_xp("axe", half)
			prog.add_run_xp("str", half)
		prog.add_run_xp("hp", bal.xp_kill_hp * mult)
		prog.add_run_xp("def", bal.xp_kill_def * mult)
	if tel:
		tel.note_kill()


func _start_adrenaline() -> void:
	adrenaline = true
	adrenaline_xp = 1.0 + bal.adrenaline_xp_stack
	if tel:
		tel.note_adrenaline()
	sfx("warcry")
	if sfx_node and sfx_node.has_method("set_adrenaline"):
		sfx_node.set_adrenaline(true)


func _end_adrenaline() -> void:
	adrenaline = false
	adrenaline_xp = 1.0
	if sfx_node and sfx_node.has_method("set_adrenaline"):
		sfx_node.set_adrenaline(false)


func spawn_floor_item(it: Dictionary, pos := Vector3.INF) -> void:
	if it.is_empty():
		return
	var at := pos
	if not at.is_finite():
		var p := get_tree().get_first_node_in_group("player")
		if p is Node3D:
			at = (p as Node3D).global_position + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
		else:
			at = Vector3.ZERO
	var PickupS := load("res://scripts/world/pickup.gd")
	PickupS.drop_item(it, at)


func toast(msg: String) -> void:
	toast_msg = msg
	toast_t = 2.2


func note_clerk() -> void:
	if clerk_t < 0.0:
		clerk_t = clock
	if tel and tel.clerk_t < 0.0:
		tel.clerk_t = tel.duration


func _process(delta: float) -> void:
	Pad.tick()
	if pad_just("interact"):
		var f := get_viewport().gui_get_focus_owner()
		if f is BaseButton and not (f as BaseButton).disabled:
			(f as BaseButton).pressed.emit()
	clock += delta
	if shrine_t > 0.0:
		shrine_t = maxf(0.0, shrine_t - delta)
	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - delta)
	if tel and in_dungeon:
		var fighting := false
		var p := get_tree().get_first_node_in_group("player")
		if p:
			fighting = int(p.get("atk_state")) != 0 or p.get("lock_target") != null
			if not fighting:
				for e in get_tree().get_nodes_in_group("enemies"):
					if e != null and is_instance_valid(e) and int(e.get("state")) >= 1 and int(e.get("state")) <= 6:
						fighting = true
						break
		tel.tick(delta, fighting)
	if prog:
		prog.tick_food(delta)
	if adrenaline and clock - last_kill > bal.adrenaline_timeout:
		_end_adrenaline()
	_debug_sequence(delta)


func _unhandled_input(event: InputEvent) -> void:
	Pad.note_event(event)


func using_pad() -> bool:
	return Pad.mode


func _debug_sequence(delta: float) -> void:
	var down := _shoulders_down()
	var up := _shoulders_up()
	if _seq == 2 or _seq == 3:
		_seq_timer -= delta
		if _seq_timer <= 0.0:
			_seq = 0
	if _seq == 0 and down:
		_seq = 1
		_seq_down = true
	elif _seq == 1 and up:
		_seq = 2
		_seq_timer = 1.5
	elif _seq == 2 and down:
		_seq = 3
		_seq_timer = 1.5
	elif _seq == 3 and up:
		_seq = 0
		if debug and debug.has_method("toggle"):
			debug.toggle()


func _shoulders_down() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return false
	var d: int = pads[0]
	return (
		Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.55
		and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.55
		and Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER)
		and Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
	)


func _shoulders_up() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return true
	var d: int = pads[0]
	return (
		Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) < 0.25
		and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) < 0.25
		and not Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER)
		and not Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
	)


func launch_archive(id: String) -> void:
	if _menu_loading:
		return
	_menu_loading = true
	_launch_archive_async(id)


func _archive_label(id: String) -> String:
	for e in T.archive_catalog():
		if str(e.get("id", "")) == id:
			return str(e.get("label", id))
	return id


func _launch_archive_async(id: String) -> void:
	## classic_2d / art_experiment have no project.godot; they live inside the frozen
	## full_3d_pass snapshot and launch as that independent --path instance.
	var heading := _archive_label(id)
	if loader:
		loader.begin(heading, "Opening snapshot…")
		loader.set_progress(0.12)
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch := root.path_join("archives").path_join("full_3d_pass")
	if not DirAccess.dir_exists_absolute(arch):
		push_warning("Archive missing: " + arch)
		toast("Archive missing.")
		if loader:
			loader.set_status("Archive missing.")
			loader.set_progress(1.0)
			await get_tree().create_timer(0.35, true, false, true).timeout
			loader.finish()
		_menu_loading = false
		return
	if loader:
		loader.set_status("Handing off the snapshot…")
		loader.set_progress(0.62)
	await get_tree().process_frame
	var pres := "live"
	if id == "classic_2d" or id == "art_experiment":
		pres = id
	var exe := OS.get_executable_path()
	var code := OS.create_process(exe, ["--path", arch, "--", "--wdb-pres=%s" % pres])
	if code == -1:
		push_warning("Could not spawn archive process (web builds cannot).")
		toast("Could not launch archive.")
		if loader:
			loader.set_status("Could not launch archive.")
			loader.set_progress(1.0)
			await get_tree().create_timer(0.45, true, false, true).timeout
			loader.finish()
		_menu_loading = false
		return
	if loader:
		loader.set_status("Snapshot running.")
		loader.set_progress(1.0)
		await get_tree().create_timer(0.28, true, false, true).timeout
		loader.finish()
	_menu_loading = false


func collect_binds() -> Array:
	return Binds.collect()


func apply_binds(rows: Array) -> void:
	Binds.apply(rows)


func reset_binds() -> void:
	Binds.reset()


func wake_web_pad() -> void:
	Pad.wake_web()


func pad_id() -> int:
	return Pad.id()


func pad_stick(lx: int, ly: int, dead := 0.24) -> Vector2:
	return Pad.stick(lx, ly, dead)


func pad_move() -> Vector2:
	return Pad.move()


func pad_aim() -> Vector2:
	return Pad.aim()


func pad_held(action: String) -> bool:
	return Pad.held(action)


func pad_just(action: String) -> bool:
	return Pad.just(action)


func pause_just() -> bool:
	return Pad.pause_just()


func swallow_close_pad() -> void:
	Pad.swallow_close()


func web_buttons() -> PackedFloat32Array:
	return Pad.web_buttons()
