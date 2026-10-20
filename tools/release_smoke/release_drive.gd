extends Node

## Release smoke driver. Never in the game: run_release_smoke.py adds it as an autoload in a scratch copy of the
## project only. It plays the shipped path with no debug code (title, hub, dungeon) and prints REL: lines.

var _t := 0.0
var _step := 0
var _hub_ok := false
var _dun_ok := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	printerr("REL: dbg_on=" + str(App.Dbg.on()) + " debug_menu=" + str(App.debug != null) + " playtest=" + str(App.playtest != null)
		+ " anim_browser=" + str(App.anim_browser != null) + " tel=" + str(App.tel != null)
		+ " debug_dir=" + str(ResourceLoader.exists("res://scripts/debug/smoke.gd")))

func _scene() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s else ""

func _process(delta: float) -> void:
	_t += delta
	if _step == 0 and _t > 2.0:
		_step = 1
		App.play_from_menu()
	elif _step == 1 and _scene() == App.CAMP_SCENE:
		_hub_ok = true
		_step = 2
		_t = 0.0
	elif _step == 2 and _t > 2.0:
		_step = 3
		App.go_dungeon()  # headless: enter_dungeon waits on frame_post_draw, which a dummy renderer never draws
	elif _step == 3 and bool(App.in_dungeon) and get_tree().current_scene != null and get_tree().current_scene.get("data") != null:
		_dun_ok = true
		_step = 4
		_t = 0.0
	elif _step == 4 and _t > 3.0:
		_finish()
	elif _t > 120.0:
		_finish()

func _finish() -> void:
	printerr("REL: debug_menu=" + str(App.debug != null) + " playtest=" + str(App.playtest != null) + " anim_browser=" + str(App.anim_browser != null))
	printerr("REL: hub_ok=" + str(_hub_ok) + " dungeon_ok=" + str(_dun_ok) + " step=" + str(_step) + " scene=" + _scene() + " in_dungeon=" + str(App.in_dungeon))
	get_tree().quit(0 if _hub_ok and _dun_ok else 1)
