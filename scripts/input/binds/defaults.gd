extends Object

## Fills the InputMap from table.gd (the single home for bindings). Host module is scripts/input/binds.gd.

const Table := preload("res://scripts/input/binds/table.gd")

static func register() -> void:
	for extra in ["weapon_1", "weapon_2", "weapon_3"]:
		if InputMap.has_action(extra):
			InputMap.erase_action(extra)
	for r: Dictionary in Table.ROWS:
		var a: String = str(r.id)
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
		else:
			InputMap.add_action(a, 0.25)
		for pool in ["kb", "pad"]:
			for e: InputEvent in Table.stock(r, pool):
				InputMap.action_add_event(a, e)
	for m: Dictionary in Table.MENU:
		var a: String = str(m.id)
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.5)
		for pool in ["kb", "pad"]:
			for e: InputEvent in Table.stock(m, pool):
				_ensure(a, e)
	strip_key("ui_accept", KEY_SPACE)
	strip_key("ui_select", KEY_SPACE)

## Adds the event unless the action already has an equal one (the engine ships its own ui_* events).
static func _ensure(action: String, ev: InputEvent) -> void:
	var Pool = load("res://scripts/input/binds/binds_pool.gd")
	for e in InputMap.action_get_events(action):
		if Pool.events_equal(e, ev):
			return
	InputMap.action_add_event(action, ev)

static func strip_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: InputEventKey = e as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if int(code) == keycode:
				InputMap.action_erase_event(action, e)
