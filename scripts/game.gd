extends Node

signal run_hp_changed
signal bag_changed
signal gold_changed
signal floor_changed
signal skill_leveled(skill: String, new_level: int)

var save: SaveData
var run: RunState
var in_dungeon: bool = false
var last_recap: Dictionary = {}
var overwrite_queue: ItemData = null

var plaza_scene := "res://scenes/plaza.tscn"
var dungeon_scene := "res://scenes/dungeon_floor.tscn"
var recap_scene := "res://scenes/recap.tscn"
var title_scene := "res://scenes/title.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	save = SaveData.load_or_create()
	randomize()


func go_title() -> void:
	in_dungeon = false
	run = null
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", title_scene)


func go_plaza() -> void:
	in_dungeon = false
	run = null
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", plaza_scene)


func begin_run(weapon: ItemData, tool: ItemData, start_floor: int) -> void:
	run = RunState.new()
	run.setup(save, weapon, tool)
	run.current_floor = maxi(1, start_floor)
	run.visited_deepest = run.current_floor
	if run.current_floor > save.deepest_floor:
		save.deepest_floor = run.current_floor
	in_dungeon = true
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", dungeon_scene)
	floor_changed.emit()


func enter_floor(n: int) -> void:
	if run == null:
		return
	run.current_floor = n
	if n > run.visited_deepest:
		run.visited_deepest = n
	if n > save.deepest_floor:
		save.deepest_floor = n
		save.write()
	in_dungeon = true
	get_tree().call_deferred("change_scene_to_file", dungeon_scene)
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
	var keep_m := run.mining_xp_run * 0.02
	var keep_a := run.great_axe_xp_run * 0.02
	var keep_s := run.smithing_xp_run * 0.02
	var mine_lv := Skills.level_from_xp(save.mining_xp)
	var axe_lv := Skills.level_from_xp(save.great_axe_xp)
	var smith_lv := Skills.level_from_xp(save.smithing_xp)
	save.mining_xp += keep_m
	save.great_axe_xp += keep_a
	save.smithing_xp += keep_s
	var leveled: Array = []
	if Skills.level_from_xp(save.mining_xp) > mine_lv:
		leveled.append("Mining %d" % Skills.level_from_xp(save.mining_xp))
	if Skills.level_from_xp(save.great_axe_xp) > axe_lv:
		leveled.append("Great Axe %d" % Skills.level_from_xp(save.great_axe_xp))
	if Skills.level_from_xp(save.smithing_xp) > smith_lv:
		leveled.append("Smithing %d" % Skills.level_from_xp(save.smithing_xp))
	if run.visited_deepest > save.deepest_floor:
		save.deepest_floor = run.visited_deepest
	last_recap = {
		"voluntary": _voluntary,
		"floor": run.visited_deepest,
		"mining_kept": keep_m,
		"axe_kept": keep_a,
		"smithing_kept": keep_s,
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
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", recap_scene)


func add_to_bag(it: ItemData) -> bool:
	if run == null:
		return false
	var ok := run.add_item(it)
	if ok:
		bag_changed.emit()
	return ok


func damage_player(amount: float) -> void:
	if run == null:
		return
	run.hp = maxf(0.0, run.hp - amount)
	run_hp_changed.emit()
	if run.hp <= 0.0:
		end_run(false)


func heal_player(amount: float) -> void:
	if run == null:
		return
	run.hp = minf(run.max_hp, run.hp + amount)
	run_hp_changed.emit()


func restore_mana(amount: float) -> void:
	if run == null:
		return
	run.mana = minf(run.max_mana, run.mana + amount)


func skill_xp(skill: String) -> float:
	var awake := 0.0
	var dream := 0.0
	if save:
		match skill:
			"mining":
				awake = save.mining_xp
			"great_axe":
				awake = save.great_axe_xp
			"smithing":
				awake = save.smithing_xp
	if run:
		match skill:
			"mining":
				dream = run.mining_xp_run
			"great_axe":
				dream = run.great_axe_xp_run
			"smithing":
				dream = run.smithing_xp_run
	return awake + dream


func skill_level(skill: String) -> int:
	return Skills.level_from_xp(skill_xp(skill))


func grant_xp(skill: String, amount: float, awake: bool = false) -> void:
	if amount == 0.0:
		return
	var before := skill_level(skill)
	if awake or run == null:
		if save == null:
			return
		match skill:
			"mining":
				save.mining_xp += amount
			"great_axe":
				save.great_axe_xp += amount
			"smithing":
				save.smithing_xp += amount
	else:
		match skill:
			"mining":
				run.mining_xp_run += amount
			"great_axe":
				run.great_axe_xp_run += amount
			"smithing":
				run.smithing_xp_run += amount
	var after := skill_level(skill)
	if after > before:
		skill_leveled.emit(skill, after)
		toast("%s level %d!" % [Skills.label(skill), after], Color(1.0, 0.92, 0.42))


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
	run.gold += n
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


func extract_gear(index: int) -> Variant:
	if run == null:
		return null
	var it := run.remove_item_at(index, -1)
	if it == null:
		return null
	it.forged = false
	var blocked: Array = save.stash_gear(it)
	bag_changed.emit()
	if blocked.is_empty():
		run.gear_extracted.append(it.full_name())
		save.write()
		return true
	overwrite_queue = it
	return blocked


func confirm_overwrite(family: String, slot: int) -> void:
	if overwrite_queue == null:
		return
	save.overwrite_gear(overwrite_queue, slot)
	run.gear_extracted.append(overwrite_queue.full_name())
	overwrite_queue = null
	save.write()
	bag_changed.emit()


func extract_misc(index: int) -> bool:
	if run == null:
		return false
	var it: ItemData = run.bag[index]
	if it == null:
		return false
	if it.kind == ItemData.Kind.WEAPON or it.kind == ItemData.Kind.TOOL:
		return false
	if it.family == "ore":
		return false
	if it.family == "food" or it.family == "potion":
		run.remove_item_at(index, -1)
		bag_changed.emit()
		return true
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
	_act("inventory", [KEY_TAB], JOY_BUTTON_Y)
	_act("pause", [KEY_ESCAPE], JOY_BUTTON_START)
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
