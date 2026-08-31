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
const AppFlow := preload("res://scripts/app_flow.gd")
const AppRun := preload("res://scripts/app_run.gd")

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
	AppFlow.enter_dungeon(self)


func _after_enter() -> void:
	ui_open = false
	begin_run()


func go_title() -> void:
	AppFlow.go_title(self)


func go_foundation() -> void:
	AppFlow.go_foundation(self)


func go_camp() -> void:
	AppFlow.go_camp(self)


func play_from_menu() -> void:
	AppFlow.play_from_menu(self)


func _play_from_menu_async() -> void:
	await AppFlow.play_from_menu_async(self)


func begin_run() -> void:
	AppRun.begin_run(self)


func go_dungeon() -> void:
	AppRun.go_dungeon(self)


func next_floor() -> void:
	AppRun.next_floor(self)


func notify_boss_dead() -> void:
	AppRun.notify_boss_dead(self)


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
	AppRun.end_run(self, cond, killer)


func finish_end(cond: String, killer := "") -> void:
	AppRun.finish_end(self, cond, killer)


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
	AppRun.on_kill(self)


func spawn_floor_item(it: Dictionary, pos := Vector3.INF) -> void:
	AppRun.spawn_floor_item(self, it, pos)


func toast(msg: String) -> void:
	toast_msg = msg
	toast_t = 2.2


func note_clerk() -> void:
	if clerk_t < 0.0:
		clerk_t = clock
	if tel and tel.clerk_t < 0.0:
		tel.clerk_t = tel.duration


func _in_world() -> bool:
	return get_tree().get_first_node_in_group("player") != null


func _process(delta: float) -> void:
	Pad.tick()
	if _in_world() and not ui_open:
		var vp := get_viewport()
		if vp and vp.gui_get_focus_owner() != null:
			vp.gui_release_focus()
	elif (ui_open or not _in_world()) and pad_just("interact"):
		var f := get_viewport().gui_get_focus_owner()
		if f is BaseButton and not (f as BaseButton).disabled:
			(f as BaseButton).pressed.emit()
	AppRun.tick(self, delta)


func _unhandled_input(event: InputEvent) -> void:
	Pad.note_event(event)


func using_pad() -> bool:
	return Pad.mode


func launch_archive(id: String) -> void:
	AppFlow.launch_archive(self, id)


func _launch_archive_async(id: String) -> void:
	await AppFlow.launch_archive_async(self, id)


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
