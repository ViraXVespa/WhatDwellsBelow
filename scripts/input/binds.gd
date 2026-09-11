extends RefCounted

const Pool := preload("res://scripts/input/binds_pool.gd")
const Defaults := preload("res://scripts/input/binds_defaults.gd")

const BIND_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"attack", "special", "dash", "target_lock", "interact", "pause",
	"tab_left", "tab_right",
	"map_view", "potion", "food", "look_mode",
	"inventory",
	"gear_tip", "gear_drop", "crystal_zoom",
	"anim_model_prev", "anim_model_next", "anim_idle", "anim_play",
	"anim_list_up", "anim_list_down", "anim_back",
]

const GAMEPLAY_ACTIONS: PackedStringArray = Pool.GAMEPLAY_ACTIONS


static func collect() -> Array:
	var out: Array = []
	for a in BIND_ACTIONS:
		if not InputMap.has_action(a):
			continue
		for e in InputMap.action_get_events(a):
			var row: Dictionary = {"action": a}
			if e is InputEventKey:
				var k: InputEventKey = e as InputEventKey
				row["type"] = "key"
				row["code"] = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				row["pool"] = "kb"
			elif e is InputEventJoypadButton:
				row["type"] = "joy"
				row["code"] = (e as InputEventJoypadButton).button_index
				row["pool"] = "pad"
			elif e is InputEventJoypadMotion:
				var m: InputEventJoypadMotion = e as InputEventJoypadMotion
				row["type"] = "axis"
				row["code"] = m.axis
				row["value"] = m.axis_value
				row["pool"] = "pad"
			elif e is InputEventMouseButton:
				row["type"] = "mouse"
				row["code"] = (e as InputEventMouseButton).button_index
				row["pool"] = "kb"
			else:
				continue
			out.append(row)
	return out


static func apply(rows: Array) -> void:
	if rows.is_empty():
		return
	var seen: Dictionary = {}
	for row in rows:
		if not (row is Dictionary):
			continue
		var a: String = str(row.get("action", ""))
		if a == "" or BIND_ACTIONS.find(a) < 0:
			continue
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
		if not seen.has(a):
			InputMap.action_erase_events(a)
			seen[a] = true
		var ev: InputEvent = bind_event(row)
		if ev:
			InputMap.action_add_event(a, ev)
	Defaults.ensure_key("inventory", KEY_I)
	Defaults.ensure_joy("inventory", JOY_BUTTON_DPAD_RIGHT)


static func bind_event(row: Dictionary) -> InputEvent:
	var t: String = str(row.get("type", ""))
	if t == "key":
		var e := InputEventKey.new()
		e.physical_keycode = int(row.get("code", 0)) as Key
		return e
	if t == "joy":
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(row.get("code", 0)) as JoyButton
		return jb
	if t == "axis":
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(row.get("code", 0)) as JoyAxis
		jm.axis_value = float(row.get("value", 1.0))
		return jm
	if t == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(row.get("code", 1)) as MouseButton
		return mb
	return null


static func event_in_pool(e: InputEvent, pool: String) -> bool:
	return Pool.event_in_pool(e, pool)


static func events_equal(a: InputEvent, b: InputEvent) -> bool:
	return Pool.events_equal(a, b)


static func pool_events(action: String, pool: String) -> Array:
	return Pool.pool_events(action, pool)


static func slot_event(action: String, pool: String, slot: int) -> InputEvent:
	return Pool.slot_event(action, pool, slot)


static func bind_slot(action: String, pool: String, slot: int, ev: InputEvent) -> void:
	Pool.bind_slot(action, pool, slot, ev)


static func reset_pool(pool: String) -> void:
	Pool.reset_pool(pool)


static func reset() -> void:
	for a in BIND_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
	register()


static func register() -> void:
	Defaults.register()


static func apply_pc_defaults() -> void:
	Defaults.apply_pc_defaults()


static func ensure_key(action: String, keycode: int) -> void:
	Defaults.ensure_key(action, keycode)


static func ensure_joy(action: String, button: int) -> void:
	Defaults.ensure_joy(action, button)


static func ensure_mouse(action: String, btn: int) -> void:
	Defaults.ensure_mouse(action, btn)


static func ensure_axis(action: String, axis: int, axis_value: float) -> void:
	Defaults.ensure_axis(action, axis, axis_value)
