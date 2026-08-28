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

const PAD := {
	"interact": JOY_BUTTON_A,
	"dash": JOY_BUTTON_B,
	"target_lock": JOY_BUTTON_RIGHT_STICK,
	"pause": JOY_BUTTON_START,
	"map_view": JOY_BUTTON_BACK,
	"potion": JOY_BUTTON_DPAD_UP,
	"food": JOY_BUTTON_DPAD_LEFT,
	"tab_left": JOY_BUTTON_LEFT_SHOULDER,
	"tab_right": JOY_BUTTON_RIGHT_SHOULDER,
}

var _pad_was: Dictionary = {}
var _pad_edge: Dictionary = {}
var _eat_pause := false

const TITLE_SCENE := "res://scenes/title.tscn"
const FOUNDATION_SCENE := "res://scenes/foundation.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bal = BalanceS.new()
	prog = ProgressS.new()
	_register_input()
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
	if not _phase_smoke():
		Store.load_slot("live")
	if "--wdb-debug" in OS.get_cmdline_user_args():
		call_deferred("_open_debug")


func _open_debug() -> void:
	if debug and debug.has_method("show_menu"):
		debug.show_menu()


func _phase_smoke() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--wdb-phase") and s.find("smoke") >= 0:
			return true
	return false


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
			var prog: Array = []
			var st := ResourceLoader.load_threaded_get_status(path, prog)
			var local := float(prog[0]) if prog.size() > 0 else 0.0
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
	_pad_tick()
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


const BIND_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"attack", "special", "dash", "target_lock", "interact", "pause",
	"tab_left", "tab_right",
	"map_view", "potion", "food",
	"anim_model_prev", "anim_model_next", "anim_idle", "anim_play",
	"anim_list_up", "anim_list_down", "anim_back",
]


func collect_binds() -> Array:
	var out: Array = []
	for a in BIND_ACTIONS:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			var row := {"action": a}
			if e is InputEventKey:
				var k := e as InputEventKey
				row["type"] = "key"
				row["code"] = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			elif e is InputEventJoypadButton:
				row["type"] = "joy"
				row["code"] = (e as InputEventJoypadButton).button_index
			elif e is InputEventJoypadMotion:
				var m := e as InputEventJoypadMotion
				row["type"] = "axis"
				row["code"] = m.axis
				row["value"] = m.axis_value
			elif e is InputEventMouseButton:
				row["type"] = "mouse"
				row["code"] = (e as InputEventMouseButton).button_index
			else:
				continue
			out.append(row)
	return out


func apply_binds(rows: Array) -> void:
	if rows.is_empty():
		return
	var seen := {}
	for row in rows:
		if not (row is Dictionary):
			continue
		var a := str(row.get("action", ""))
		if a == "" or BIND_ACTIONS.find(a) < 0:
			continue
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
		if not seen.has(a):
			InputMap.action_erase_events(a)
			seen[a] = true
		var ev := _bind_event(row)
		if ev:
			InputMap.action_add_event(a, ev)
	_apply_pc_control_defaults()


func _bind_event(row: Dictionary) -> InputEvent:
	var t := str(row.get("type", ""))
	if t == "key":
		var e := InputEventKey.new()
		e.physical_keycode = int(row.get("code", 0))
		return e
	if t == "joy":
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(row.get("code", 0))
		return jb
	if t == "axis":
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(row.get("code", 0))
		jm.axis_value = float(row.get("value", 1.0))
		return jm
	if t == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(row.get("code", 1))
		return mb
	return null


func reset_binds() -> void:
	for a in BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
	_register_input()


func _register_input() -> void:
	for extra in ["weapon_1", "weapon_2", "weapon_3"]:
		if InputMap.has_action(extra):
			InputMap.erase_action(extra)
	for a in BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
	_act("move_left", [KEY_A, KEY_LEFT], -1, JOY_AXIS_LEFT_X, -1.0)
	_act("move_right", [KEY_D, KEY_RIGHT], -1, JOY_AXIS_LEFT_X, 1.0)
	_act("move_up", [KEY_W, KEY_UP], -1, JOY_AXIS_LEFT_Y, -1.0)
	_act("move_down", [KEY_S, KEY_DOWN], -1, JOY_AXIS_LEFT_Y, 1.0)
	_act("aim_left", [], -1, JOY_AXIS_RIGHT_X, -1.0)
	_act("aim_right", [], -1, JOY_AXIS_RIGHT_X, 1.0)
	_act("aim_up", [], -1, JOY_AXIS_RIGHT_Y, -1.0)
	_act("aim_down", [], -1, JOY_AXIS_RIGHT_Y, 1.0)
	_act("attack", [], -1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_act("special", [], -1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_mouse("special", MOUSE_BUTTON_RIGHT)
	_act("dash", [KEY_SPACE], JOY_BUTTON_B)
	_act("target_lock", [KEY_Q], JOY_BUTTON_RIGHT_STICK)
	_act("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER], JOY_BUTTON_A)
	_act("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	_act("tab_left", [KEY_BRACKETLEFT], JOY_BUTTON_LEFT_SHOULDER)
	_act("tab_right", [KEY_BRACKETRIGHT], JOY_BUTTON_RIGHT_SHOULDER)
	_act("map_view", [KEY_M], JOY_BUTTON_BACK)
	_act("potion", [KEY_F], JOY_BUTTON_DPAD_UP)
	_act("food", [KEY_C], JOY_BUTTON_DPAD_LEFT)
	_act("anim_model_prev", [KEY_COMMA], JOY_BUTTON_LEFT_SHOULDER)
	_act("anim_model_next", [KEY_PERIOD], JOY_BUTTON_RIGHT_SHOULDER)
	_act("anim_idle", [KEY_I], JOY_BUTTON_RIGHT_STICK)
	_act("anim_play", [KEY_P])
	_act("anim_list_up", [KEY_PAGEUP], -1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_act("anim_list_down", [KEY_PAGEDOWN], -1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_act("anim_back", [KEY_BACKSPACE, KEY_ESCAPE], JOY_BUTTON_B)
	_ensure("ui_accept")
	_ensure("ui_cancel")
	_ensure("ui_left")
	_ensure("ui_right")
	_ensure("ui_up")
	_ensure("ui_down")
	_joy("ui_accept", JOY_BUTTON_A)
	_joy("ui_cancel", JOY_BUTTON_B)
	_key("ui_accept", KEY_ENTER)
	_key("ui_accept", KEY_KP_ENTER)
	_key("ui_cancel", KEY_ESCAPE)
	_joy("ui_left", JOY_BUTTON_DPAD_LEFT)
	_joy("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_joy("ui_up", JOY_BUTTON_DPAD_UP)
	_joy("ui_down", JOY_BUTTON_DPAD_DOWN)
	_key("ui_left", KEY_LEFT)
	_key("ui_left", KEY_A)
	_key("ui_right", KEY_RIGHT)
	_key("ui_right", KEY_D)
	_key("ui_up", KEY_UP)
	_key("ui_up", KEY_W)
	_key("ui_down", KEY_DOWN)
	_key("ui_down", KEY_S)
	if OS.has_feature("web"):
		var rt := InputEventJoypadButton.new()
		rt.button_index = 7
		InputMap.action_add_event("attack", rt)
		var lt := InputEventJoypadButton.new()
		lt.button_index = 6
		InputMap.action_add_event("special", lt)
	_apply_pc_control_defaults()


func _apply_pc_control_defaults() -> void:
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_left", KEY_LEFT)
	_ensure_key("move_right", KEY_D)
	_ensure_key("move_right", KEY_RIGHT)
	_ensure_key("move_up", KEY_W)
	_ensure_key("move_up", KEY_UP)
	_ensure_key("move_down", KEY_S)
	_ensure_key("move_down", KEY_DOWN)
	_ensure_key("interact", KEY_E)
	_ensure_key("interact", KEY_ENTER)
	_ensure_key("interact", KEY_KP_ENTER)
	_strip_key("special", KEY_R)
	_ensure_mouse("special", MOUSE_BUTTON_RIGHT)
	_ensure_key("pause", KEY_ESCAPE)
	_ensure_key("anim_back", KEY_ESCAPE)
	_ensure_key("anim_back", KEY_BACKSPACE)
	_ensure_key("ui_accept", KEY_ENTER)
	_ensure_key("ui_accept", KEY_KP_ENTER)
	_ensure_key("ui_cancel", KEY_ESCAPE)
	_ensure_key("ui_left", KEY_LEFT)
	_ensure_key("ui_left", KEY_A)
	_ensure_key("ui_right", KEY_RIGHT)
	_ensure_key("ui_right", KEY_D)
	_ensure_key("ui_up", KEY_UP)
	_ensure_key("ui_up", KEY_W)
	_ensure_key("ui_down", KEY_DOWN)
	_ensure_key("ui_down", KEY_S)


func _ensure_key(name: String, keycode: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for e in InputMap.action_get_events(name):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				return
	_key(name, keycode)


func _ensure_mouse(name: String, btn: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for e in InputMap.action_get_events(name):
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == btn:
			return
	_mouse(name, btn)


func _strip_key(name: String, keycode: int) -> void:
	if not InputMap.has_action(name):
		return
	for e in InputMap.action_get_events(name):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				InputMap.action_erase_event(name, e)


func _act(name: String, keys: Array, button: int = -1, axis: int = -1, axis_value: float = 0.0) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	if button >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(name, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_value
		InputMap.action_add_event(name, jm)


func _mouse(name: String, btn: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	InputMap.action_add_event(name, e)


func _ensure(name: String) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.5)


func _joy(name: String, button: int) -> void:
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	InputMap.action_add_event(name, jb)


func _key(name: String, keycode: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(name, e)


func wake_web_pad() -> void:
	get_viewport().gui_release_focus()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			var c = document.getElementById('canvas');
			if (!c) return;
			c.tabIndex = 0;
			c.focus();
		})();
	""", true)


func pad_id() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


func pad_stick(lx: int, ly: int, dead := 0.24) -> Vector2:
	var id := pad_id()
	if id < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(id, lx), Input.get_joy_axis(id, ly))
	return v if v.length() >= dead else Vector2.ZERO


func pad_move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 0.01:
		return v
	return pad_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)


func pad_aim() -> Vector2:
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() > 0.01:
		return v
	return pad_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


func pad_held(action: String) -> bool:
	if Input.is_action_pressed(action):
		return true
	var id := pad_id()
	if id >= 0:
		if action == "attack" and Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) > 0.45:
			return true
		if action == "special" and Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT) > 0.45:
			return true
		if PAD.has(action) and Input.is_joy_button_pressed(id, int(PAD[action])):
			return true
	return false


func pad_just(action: String) -> bool:
	return bool(_pad_edge.get(action, false))


func pause_just() -> bool:
	if _eat_pause:
		return false
	return Input.is_action_just_pressed("pause") or pad_just("pause")


func swallow_close_pad() -> void:
	# B closes windows and is also dash. Eat the press and the held-through
	# release so closing a window never starts a dash (or other combat input).
	# Escape is both Back and Pause — eat it until released so a menu back
	# cannot reopen pause on the same hold.
	for action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock", "pause"]:
		_pad_edge[action] = false
		_pad_was[action] = true
	_eat_pause = true


func _pad_blocked(action: String) -> bool:
	if not ui_open:
		return false
	return action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock"]


func _pad_tick() -> void:
	_pad_edge.clear()
	var names: Array = PAD.keys()
	names.append_array(["attack", "special"])
	for action in names:
		var key := str(action)
		var now := pad_held(key)
		if _pad_blocked(key):
			_pad_edge[key] = false
		else:
			_pad_edge[key] = now and not bool(_pad_was.get(key, false))
		_pad_was[key] = now
	if _eat_pause:
		var held := Input.is_action_pressed("pause") or Input.is_action_pressed("ui_cancel")
		if not held:
			var id := pad_id()
			if id >= 0:
				held = Input.is_joy_button_pressed(id, JOY_BUTTON_START) or Input.is_joy_button_pressed(id, JOY_BUTTON_B)
		if not held:
			_eat_pause = false


func web_buttons() -> PackedFloat32Array:
	if not OS.has_feature("web"):
		return PackedFloat32Array()
	var raw := str(JavaScriptBridge.eval("""
		(function () {
			var pads = navigator.getGamepads ? navigator.getGamepads() : [];
			for (var i = 0; i < pads.length; i++) {
				if (!pads[i] || !pads[i].buttons) continue;
				return JSON.stringify(pads[i].buttons.map(function (b) { return b.value; }));
			}
			return "[]";
		})();
	""", true))
	var parsed: Variant = JSON.parse_string(raw)
	var out := PackedFloat32Array()
	if parsed is Array:
		for v in parsed:
			out.append(float(v))
	return out