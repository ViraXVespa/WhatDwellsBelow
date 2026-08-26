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
var tel: TelS
var wake_pending := false
var saw_stairs := false
var boss_low := false
var adrenaline := false
var adrenaline_xp := 1.0
var run_xp := 0.0
var clock := 0.0
var last_kill := -999.0
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
	floors_since_named = 0
	shrine_t = 0.0
	extracted = false
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
	Engine.time_scale = 1.0
	if music and music.has_method("play_dungeon") and str(music.get("kind")) != "dungeon":
		music.play_dungeon()
	get_tree().call_deferred("change_scene_to_file", DUNGEON_SCENE)


func next_floor() -> void:
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
	## classic_2d / art_experiment have no project.godot; they live inside the frozen
	## full_3d_pass snapshot and launch as that independent --path instance.
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var arch := root.path_join("archives").path_join("full_3d_pass")
	if not DirAccess.dir_exists_absolute(arch):
		push_warning("Archive missing: " + arch)
		toast("Archive missing.")
		return
	var pres := "live"
	if id == "classic_2d" or id == "art_experiment":
		pres = id
	var exe := OS.get_executable_path()
	var code := OS.create_process(exe, ["--path", arch, "--", "--wdb-pres=%s" % pres])
	if code == -1:
		push_warning("Could not spawn archive process (web builds cannot).")
		toast("Could not launch archive.")


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
	_act("special", [KEY_R], -1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_act("dash", [KEY_SPACE], JOY_BUTTON_B)
	_act("target_lock", [KEY_Q], JOY_BUTTON_RIGHT_STICK)
	_act("interact", [KEY_E], JOY_BUTTON_A)
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
	_act("anim_back", [KEY_BACKSPACE], JOY_BUTTON_B)
	_ensure("ui_accept")
	_ensure("ui_cancel")
	_ensure("ui_left")
	_ensure("ui_right")
	_ensure("ui_up")
	_ensure("ui_down")
	_joy("ui_accept", JOY_BUTTON_A)
	_joy("ui_cancel", JOY_BUTTON_B)
	_key("ui_accept", KEY_ENTER)
	_key("ui_cancel", KEY_ESCAPE)
	_joy("ui_left", JOY_BUTTON_DPAD_LEFT)
	_joy("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_joy("ui_up", JOY_BUTTON_DPAD_UP)
	_joy("ui_down", JOY_BUTTON_DPAD_DOWN)


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
