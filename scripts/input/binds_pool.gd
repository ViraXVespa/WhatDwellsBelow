extends RefCounted

const GAMEPLAY_ACTIONS: PackedStringArray = [
	"move_up", "move_down", "move_left", "move_right",
	"attack", "special", "dash", "target_lock", "interact",
	"map_view", "inventory", "potion", "food", "look_mode",
]


static func _binds():
	return load("res://scripts/input/binds.gd")


static func event_in_pool(e: InputEvent, pool: String) -> bool:
	if e == null:
		return false
	if pool == "pad":
		return e is InputEventJoypadButton or e is InputEventJoypadMotion
	return e is InputEventKey or e is InputEventMouseButton


static func events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ak: InputEventKey = a as InputEventKey
		var bk: InputEventKey = b as InputEventKey
		var ac: int = ak.physical_keycode if ak.physical_keycode != 0 else ak.keycode
		var bc: int = bk.physical_keycode if bk.physical_keycode != 0 else bk.keycode
		return ac != 0 and ac == bc
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var am: InputEventJoypadMotion = a as InputEventJoypadMotion
		var bm: InputEventJoypadMotion = b as InputEventJoypadMotion
		return am.axis == bm.axis and signf(am.axis_value) == signf(bm.axis_value)
	return false


static func pool_events(action: String, pool: String) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		if event_in_pool(e, pool):
			out.append(e)
	return out


static func slot_event(action: String, pool: String, slot: int) -> InputEvent:
	var evs: Array = pool_events(action, pool)
	if slot < 0 or slot >= evs.size():
		return null
	return evs[slot]


static func bind_slot(action: String, pool: String, slot: int, ev: InputEvent) -> void:
	if GAMEPLAY_ACTIONS.find(action) < 0 or not event_in_pool(ev, pool):
		return
	if ev is InputEventJoypadMotion:
		var ax: int = (ev as InputEventJoypadMotion).axis
		if ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y or ax == JOY_AXIS_RIGHT_X or ax == JOY_AXIS_RIGHT_Y:
			return
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var other_act: String = ""
	var other_slot: int = -1
	for a in GAMEPLAY_ACTIONS:
		var evs: Array = pool_events(a, pool)
		for i: int in evs.size():
			if events_equal(evs[i], ev) and not (a == action and i == slot):
				other_act = a
				other_slot = i
				break
		if other_act != "":
			break
	var displaced: InputEvent = slot_event(action, pool, slot)
	_write_slot(action, pool, slot, ev)
	if other_act != "":
		_write_slot(other_act, pool, other_slot, displaced)


static func _write_slot(action: String, pool: String, slot: int, ev: InputEvent) -> void:
	var keep: Array = []
	for e in InputMap.action_get_events(action):
		if not event_in_pool(e, pool):
			keep.append(e)
	var pool_evs: Array = pool_events(action, pool)
	while pool_evs.size() < 2:
		pool_evs.append(null)
	if slot < 0:
		slot = 0
	if slot > 1:
		slot = 1
	pool_evs[slot] = ev
	InputMap.action_erase_events(action)
	for e: Variant in keep:
		InputMap.action_add_event(action, e)
	for e: Variant in pool_evs:
		if e:
			InputMap.action_add_event(action, e)


static func reset_pool(pool: String) -> void:
	for a in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(a):
			continue
		var keep: Array = []
		for e in InputMap.action_get_events(a):
			if not event_in_pool(e, pool):
				keep.append(e)
		InputMap.action_erase_events(a)
		for e: Variant in keep:
			InputMap.action_add_event(a, e)
	_stock_pool(pool)


static func _stock_pool(pool: String) -> void:
	var Binds = _binds()
	if pool == "kb":
		Binds.ensure_key("move_left", KEY_A)
		Binds.ensure_key("move_left", KEY_LEFT)
		Binds.ensure_key("move_right", KEY_D)
		Binds.ensure_key("move_right", KEY_RIGHT)
		Binds.ensure_key("move_up", KEY_W)
		Binds.ensure_key("move_up", KEY_UP)
		Binds.ensure_key("move_down", KEY_S)
		Binds.ensure_key("move_down", KEY_DOWN)
		Binds.ensure_mouse("attack", MOUSE_BUTTON_LEFT)
		Binds.ensure_mouse("special", MOUSE_BUTTON_RIGHT)
		Binds.ensure_key("dash", KEY_SPACE)
		Binds.ensure_key("target_lock", KEY_Q)
		Binds.ensure_key("interact", KEY_E)
		Binds.ensure_key("interact", KEY_ENTER)
		Binds.ensure_key("map_view", KEY_M)
		Binds.ensure_key("inventory", KEY_I)
		Binds.ensure_key("potion", KEY_F)
		Binds.ensure_key("food", KEY_C)
	else:
		Binds.ensure_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
		Binds.ensure_axis("special", JOY_AXIS_TRIGGER_LEFT, 1.0)
		Binds.ensure_joy("dash", JOY_BUTTON_B)
		Binds.ensure_joy("target_lock", JOY_BUTTON_RIGHT_STICK)
		Binds.ensure_joy("interact", JOY_BUTTON_A)
		Binds.ensure_joy("map_view", JOY_BUTTON_BACK)
		Binds.ensure_joy("inventory", JOY_BUTTON_DPAD_RIGHT)
		Binds.ensure_joy("potion", JOY_BUTTON_DPAD_UP)
		Binds.ensure_joy("food", JOY_BUTTON_DPAD_LEFT)
		Binds.ensure_joy("look_mode", JOY_BUTTON_DPAD_DOWN)
