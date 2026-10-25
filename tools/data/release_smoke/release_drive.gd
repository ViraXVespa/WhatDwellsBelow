extends Node

## Release smoke driver. Never in the game: `gate.py release` adds it as an autoload in a scratch copy of the
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
	_tunables_ignored()

## Release ignores balance from anywhere but code: the debug override file and an old save's `debug_bal` / `bal_rev`.
## Shares user:// with the dev project, so any real override file is moved aside and put back.
func _tunables_ignored() -> void:
	const OV := "user://debug_tunables.json"
	var keep := OV + ".relsmoke"
	var had := FileAccess.file_exists(OV)
	if had:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OV), ProjectSettings.globalize_path(keep))
	var f := FileAccess.open(OV, FileAccess.WRITE)
	f.store_string(JSON.stringify({"special_mana": 77.0, "dash_cooldown": 3.0}))
	f.close()
	var bal0: Object = App.bal
	var def: Object = (load("res://scripts/data/balance.gd") as GDScript).new()
	App.bal = (load("res://scripts/data/balance.gd") as GDScript).new()
	var data: Dictionary = App.Store.collect()
	var clean := not data.has("debug_bal") and not data.has("bal_rev")
	data["debug_bal"] = {"special_mana": 55.0}
	data["bal_rev"] = 3
	App.Store.apply(data)
	var ok: bool = clean and is_equal_approx(App.bal.special_mana, def.special_mana) and is_equal_approx(App.bal.dash_cooldown, def.dash_cooldown)
	var mana: float = App.bal.special_mana
	App.bal = bal0
	App.Store.apply(App.Store.collect())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OV))
	if had:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(keep), ProjectSettings.globalize_path(OV))
	printerr("REL: tunables_ignored=" + str(ok) + " mana=" + str(mana))

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

## Every node in the tree running a scripts/debug/ script (its own or a base class), whoever added it.
func _debug_nodes(n: Node, out: Array[String]) -> void:
	var s: Script = n.get_script() as Script
	while s != null:
		if s.resource_path.begins_with("res://scripts/debug/"):
			out.append(str(n.get_path()) + " " + s.resource_path)
			break
		s = s.get_base_script()
	for c: Node in n.get_children():
		_debug_nodes(c, out)

func _finish() -> void:
	var dbg: Array[String] = []
	_debug_nodes(get_tree().root, dbg)
	printerr("REL: debug_nodes=" + str(dbg.size()) + (" first=" + dbg[0] if dbg else ""))
	printerr("REL: debug_menu=" + str(App.debug != null) + " playtest=" + str(App.playtest != null) + " anim_browser=" + str(App.anim_browser != null))
	printerr("REL: hub_ok=" + str(_hub_ok) + " dungeon_ok=" + str(_dun_ok) + " step=" + str(_step) + " scene=" + _scene() + " in_dungeon=" + str(App.in_dungeon))
	get_tree().quit(0 if _hub_ok and _dun_ok else 1)
