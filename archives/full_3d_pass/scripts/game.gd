extends Node

const SkillMath := preload("res://scripts/data/skills.gd")

signal run_hp_changed
signal bag_changed
signal gold_changed
signal floor_changed
signal skill_leveled(skill: String, new_level: int)

const DEMO_TOWN := "Placeholdia"
const PATREON_URL := "https://www.patreon.com/cw/ViraXVespa"

var save: SaveData
var run: RunState
var in_dungeon: bool = false
var last_recap: Dictionary = {}

var plaza_scene := "res://archives/classic_2d/scenes/plaza.tscn"
var dungeon_scene := "res://archives/classic_2d/scenes/dungeon_floor.tscn"
var plaza_3d_scene := "res://scenes/plaza_3d.tscn"
var dungeon_3d_scene := "res://scenes/dungeon_3d.tscn"
var plaza_experiment_scene := "res://archives/art_experiment/scenes/plaza.tscn"
var dungeon_experiment_scene := "res://archives/art_experiment/scenes/dungeon.tscn"
var recap_scene := "res://scenes/recap.tscn"
var title_scene := "res://scenes/title.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	save = SaveData.load_or_create()
	randomize()
	var args := OS.get_cmdline_user_args()
	printerr("ISO: res=" + ProjectSettings.globalize_path("res://"))
	printerr("ISO: game_script=" + str(get_script().resource_path if get_script() else "none"))
	printerr("ISO: save_path=" + SaveData.PATH)
	printerr("ISO: presentation=" + str(save.presentation if save else "none"))
	if "--wdb-smoke-3d" in args:
		save.presentation = "live"
		call_deferred("begin_run", {"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)


func presentation() -> String:
	if save == null:
		return "live"
	return save.presentation


func using_3d() -> bool:
	return presentation() != "classic_2d"


func using_experiment_art() -> bool:
	return presentation() == "art_experiment"


func plaza_path() -> String:
	var p := presentation()
	if p == "classic_2d":
		return plaza_scene
	if p == "art_experiment":
		return plaza_experiment_scene
	return plaza_3d_scene


func dungeon_path() -> String:
	var p := presentation()
	if p == "classic_2d":
		return dungeon_scene
	if p == "art_experiment":
		return dungeon_experiment_scene
	return dungeon_3d_scene


func set_presentation(id: String, reload := true) -> void:
	if save == null:
		return
	if id != "live" and id != "classic_2d" and id != "art_experiment":
		id = "live"
	if save.presentation != id:
		save.presentation = id
		save.write()
	if not reload:
		return
	if in_dungeon:
		toast("Look applies on the next floor.", Color(0.85, 0.82, 0.55))
		return
	go_plaza()


func apply_cam(cam: Camera2D) -> void:
	cam.add_to_group("wdb_cam")
	var z := 1.0
	if save:
		z = save.cam_zoom
	cam.zoom = Vector2(z, z)


func set_cam_zoom(z: float) -> void:
	if save == null:
		return
	save.cam_zoom = clampf(z, 1.0, 1.75)
	save.write()
	for n in get_tree().get_nodes_in_group("wdb_cam"):
		if n is Camera2D:
			(n as Camera2D).zoom = Vector2(save.cam_zoom, save.cam_zoom)
		elif n is Camera3D:
			(n as Camera3D).size = (load("res://scripts/view3d/v3.gd") as GDScript).ortho_size()


func go_title() -> void:
	in_dungeon = false
	run = null
	Engine.time_scale = 1.0
	get_tree().paused = false
	Sfx.set_music("hub")
	get_tree().call_deferred("change_scene_to_file", title_scene)


func wipe_save() -> void:
	run = null
	in_dungeon = false
	last_recap = {}
	get_tree().paused = false
	var da := DirAccess.open("user://full_3d_pass")
	if da:
		da.remove("wdb_save.json")
	save = SaveData.load_or_create()
	Engine.time_scale = 1.0
	Sfx.apply_volumes()
	toast("Save cleared. New diver.", Color(0.85, 0.9, 0.7))
	go_title()


func go_plaza() -> void:
	in_dungeon = false
	run = null
	Engine.time_scale = 1.0
	get_tree().paused = false
	if save:
		save.restock_if_broke()
		save.write()
	Sfx.set_music("hub")
	get_tree().call_deferred("change_scene_to_file", plaza_path())


func begin_run(chosen: Dictionary, start_floor: int) -> void:
	if save:
		save.has_dived = true
		save.restock_if_broke()
		save.write()
	run = RunState.new()
	run.setup(save, chosen)
	run.current_floor = maxi(1, start_floor)
	run.visited_deepest = run.current_floor
	if run.current_floor > save.deepest_floor:
		save.deepest_floor = run.current_floor
	in_dungeon = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", dungeon_path())
	floor_changed.emit()


func enter_floor(n: int) -> void:
	if run == null:
		return
	run.current_floor = n
	run.saw_stairs = false
	run.guardian_low = false
	if n > run.visited_deepest:
		run.visited_deepest = n
	if n > save.deepest_floor:
		save.deepest_floor = n
		save.write()
	in_dungeon = true
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", dungeon_path())
	floor_changed.emit()


func next_floor() -> void:
	if run == null:
		return
	if run.current_floor >= DungeonGen.SLICE_MAX_FLOOR:
		return
	enter_floor(run.current_floor + 1)


func end_run(_voluntary: bool) -> void:
	if run == null:
		go_plaza()
		return
	var keep := {}
	var leveled: Array = []
	for sk in ["mining", "great_axe", "smithing", "strength", "defense", "hitpoints"]:
		var k: float = run.xp_run_of(sk) * 0.02
		keep[sk] = k
		var before: int = SkillMath.level_from_xp(save.xp_of(sk))
		save.add_xp(sk, k)
		var after: int = SkillMath.level_from_xp(save.xp_of(sk))
		if after > before:
			leveled.append("%s %d" % [SkillMath.label(sk), after])
	if run.visited_deepest > save.deepest_floor:
		save.deepest_floor = run.visited_deepest
	last_recap = {
		"voluntary": _voluntary,
		"verge": (not _voluntary) and (run.guardian_low or (run.saw_stairs and run.current_floor == run.visited_deepest)),
		"floor": run.visited_deepest,
		"mining_kept": keep.get("mining", 0.0),
		"axe_kept": keep.get("great_axe", 0.0),
		"smithing_kept": keep.get("smithing", 0.0),
		"strength_kept": keep.get("strength", 0.0),
		"defense_kept": keep.get("defense", 0.0),
		"hitpoints_kept": keep.get("hitpoints", 0.0),
		"ore_banked": run.ore_extracted,
		"gold_mailed": run.gold_mailed,
		"gold_lost": run.gold,
		"gear": run.gear_extracted.duplicate(),
		"bag_lost": run.bag_count(),
		"gopher": not run.gear_extracted.is_empty(),
		"awake_levels": leveled,
	}
	save.write()
	run = null
	in_dungeon = false
	last_recap["combat_level"] = combat_level()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", recap_scene)


func add_to_bag(it: ItemData) -> bool:
	if run == null:
		return false
	var ok := run.add_item(it)
	if ok:
		bag_changed.emit()
	return ok


func player_world_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return Vector2.ZERO
	if using_3d() and p is Node3D:
		return Vector2((p as Node3D).global_position.x, (p as Node3D).global_position.z)
	if p is Node2D:
		return (p as Node2D).global_position
	return Vector2.ZERO


func give_or_drop(it: ItemData, world_pos: Vector2) -> bool:
	if add_to_bag(it):
		return true
	toast("Bag full — drop's on the floor.", Color(0.95, 0.72, 0.35))
	spawn_drop(it, world_pos)
	return false


func spawn_drop(it: ItemData, world_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if using_3d() and scene is Node3D:
		var drop3 = (load("res://scripts/view3d/drop_3d.gd") as GDScript).new()
		scene.add_child(drop3)
		drop3.setup(it, Vector3(world_pos.x + randf_range(-0.28, 0.28), 0.2, world_pos.y + randf_range(-0.2, 0.2)))
		return
	var drop = (load("res://archives/classic_2d/scripts/entities/ground_drop.gd") as GDScript).new()
	drop.position = world_pos + Vector2(randf_range(-18, 18), randf_range(-12, 12))
	scene.add_child(drop)
	drop.setup(it)


func hitstop(sec := 0.055) -> void:
	if Engine.time_scale < 0.5:
		return
	Engine.time_scale = 0.07
	get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func damage_player(amount: float) -> void:
	if run == null:
		return
	if run.hp <= 0.0:
		return
	var def := run.total_defense()
	var taken := amount * (100.0 / (100.0 + def))
	run.hp = maxf(0.0, run.hp - taken)
	run_hp_changed.emit()
	if run.hp <= 0.0:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("begin_death"):
			p.begin_death()
		else:
			end_run(false)


func heal_player(amount: float) -> void:
	if run == null:
		return
	run.hp = minf(run.max_hp, run.hp + amount)
	run_hp_changed.emit()


func skill_xp(skill: String) -> float:
	var awake := save.xp_of(skill) if save else 0.0
	var dream := run.xp_run_of(skill) if run else 0.0
	return awake + dream


func skill_level(skill: String) -> int:
	return SkillMath.level_from_xp(skill_xp(skill))


func combat_level() -> int:
	return SkillMath.combat_level(skill_xp("great_axe"), skill_xp("strength"), skill_xp("defense"), skill_xp("hitpoints"))


func combat_level_precise() -> float:
	return SkillMath.combat_level_precise(skill_xp("great_axe"), skill_xp("strength"), skill_xp("defense"), skill_xp("hitpoints"))


func grant_xp(skill: String, amount: float, awake: bool = false) -> void:
	if amount == 0.0:
		return
	var before: int = skill_level(skill)
	var cl_before: int = combat_level()
	if awake or run == null:
		if save == null:
			return
		save.add_xp(skill, amount)
	else:
		run.add_xp_run(skill, amount)
	if skill == "hitpoints" and run:
		run.refresh_max_hp(false)
	var after: int = skill_level(skill)
	if after > before:
		skill_leveled.emit(skill, after)
		Sfx.play("level")
		toast("%s level %d!" % [SkillMath.label(skill), after], Color(1.0, 0.92, 0.42))
	var cl_after: int = combat_level()
	if cl_after > cl_before:
		toast("Combat level %d!" % cl_after, Color(1.0, 0.86, 0.35))


func toast(text: String, col: Color = Color(1.0, 0.86, 0.35)) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	for c in tree.root.get_children():
		if c.name == "ToastLayer":
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	layer.layer = 80
	var lab := Label.new()
	lab.text = text
	lab.position = Vector2(360, 110)
	lab.size = Vector2(1200, 56)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 32)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lab.add_theme_constant_override("outline_size", 8)
	layer.add_child(lab)
	tree.root.add_child(layer)
	tree.create_timer(2.2, true, false, true).timeout.connect(layer.queue_free)


func add_run_gold(n: int) -> void:
	if run == null:
		return
	var amt := n
	if run.gold_mult != 1.0:
		amt = int(round(float(n) * run.gold_mult))
	run.gold += amt
	gold_changed.emit()


func mail_gold() -> int:
	if run == null or run.gold <= 0:
		return 0
	var carried := run.gold
	var to_town := int(floor(carried * 0.50))
	var fee := int(floor(carried * 0.10))
	run.gold = carried - to_town - fee
	save.gold += to_town
	run.gold_mailed += to_town
	gold_changed.emit()
	save.write()
	return to_town


func extract_ore(index: int) -> int:
	if run == null:
		return 0
	var it := run.remove_item_at(index, -1)
	if it == null or it.family != "ore":
		return 0
	save.banked_ore += it.count
	run.ore_extracted += it.count
	bag_changed.emit()
	save.write()
	return it.count


func analyze_gear(index: int, as_xp: bool = false) -> String:
	if run == null:
		return ""
	var it := run.remove_item_at(index, -1)
	if it == null:
		return ""
	bag_changed.emit()
	if as_xp:
		grant_xp("smithing", 14.0 + (8.0 if it.rarity == ItemData.Rarity.GREEN else 0.0))
		run.gear_extracted.append("smithing XP (%s)" % it.full_name())
		save.write()
		return "xp"
	save.add_recipe(it)
	run.gear_extracted.append(it.full_name())
	save.write()
	return "recipe"


func pawn_bag_item(index: int) -> int:
	if run == null:
		return 0
	var it := run.remove_item_at(index, -1)
	if it == null:
		return 0
	var gold_amt := 2
	if it.rarity == ItemData.Rarity.GREEN:
		gold_amt = 6
	if it.kind == ItemData.Kind.POTION:
		gold_amt = 3
	_maybe_destroy_hold(it)
	add_run_gold(gold_amt)
	bag_changed.emit()
	return gold_amt


func _maybe_destroy_hold(it: ItemData) -> void:
	if save == null or it == null:
		return
	var key := it.hold_key()
	var list := save.holds_of(key)
	for i in list.size():
		var h: ItemData = list[i]
		if h and h.unique_id == it.unique_id:
			save.destroy_hold(key, i)
			save.write()
			return


func give_artifact(id: String) -> bool:
	if run == null:
		return false
	var art_s := load("res://scripts/data/artifacts.gd")
	var nm := str(art_s.apply(run, id))
	if nm == "" or nm == "<null>":
		return false
	toast("Artifact: %s" % nm, Color(0.85, 0.72, 1.0))
	Sfx.play("level")
	return true


func extract_misc(index: int) -> bool:
	if run == null:
		return false
	var it: ItemData = run.bag[index]
	if it == null:
		return false
	if it.kind == ItemData.Kind.WEAPON or it.kind == ItemData.Kind.TOOL or it.kind == ItemData.Kind.ARMOR:
		return false
	if it.family == "ore":
		return false
	if it.family == "food":
		run.remove_item_at(index, -1)
		save.extra_food = mini(20, save.extra_food + it.count)
		bag_changed.emit()
		save.write()
		return true
	if it.kind == ItemData.Kind.POTION or it.family == "potion":
		return false
	run.remove_item_at(index, -1)
	bag_changed.emit()
	return true


func _register_input() -> void:
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
	_act("dash", [KEY_SPACE], JOY_BUTTON_B)
	_act("slam", [KEY_SHIFT], JOY_BUTTON_X)
	_act("interact", [KEY_E], JOY_BUTTON_A)
	_act("target_lock", [KEY_Q], JOY_BUTTON_RIGHT_STICK)
	_act("potion", [KEY_1], JOY_BUTTON_DPAD_UP)
	_act("food", [KEY_2], JOY_BUTTON_DPAD_LEFT)
	_act("map_view", [KEY_M], JOY_BUTTON_BACK)
	_act("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	_act("tab_left", [KEY_BRACKETLEFT], JOY_BUTTON_LEFT_SHOULDER)
	_act("tab_right", [KEY_BRACKETRIGHT], JOY_BUTTON_RIGHT_SHOULDER)
	_bind_ui_actions()


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


func _bind_ui_actions() -> void:
	_ensure_action("ui_accept")
	_ensure_action("ui_cancel")
	_ensure_action("ui_left")
	_ensure_action("ui_right")
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_focus_next")
	_ensure_action("ui_focus_prev")
	_joy_button("ui_accept", JOY_BUTTON_A)
	_joy_button("ui_cancel", JOY_BUTTON_B)
	_key("ui_accept", KEY_ENTER)
	_key("ui_cancel", KEY_ESCAPE)
	_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)


func _ensure_action(name: String) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.5)


func _joy_button(name: String, button: int) -> void:
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	if not _has_event(name, jb):
		InputMap.action_add_event(name, jb)


func _joy_axis(name: String, axis: int, value: float) -> void:
	var jm := InputEventJoypadMotion.new()
	jm.axis = axis
	jm.axis_value = value
	if not _has_event(name, jm):
		InputMap.action_add_event(name, jm)


func _key(name: String, keycode: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	if not _has_event(name, e):
		InputMap.action_add_event(name, e)


func _has_event(name: String, ev: InputEvent) -> bool:
	for existing in InputMap.action_get_events(name):
		if existing.as_text() == ev.as_text():
			return true
	return false
