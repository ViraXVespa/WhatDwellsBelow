extends RefCounted

const Table := preload("res://scripts/input/binds/table.gd")

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

const REFUSED := 0
const BOUND := 1
const SWAPPED := 2
## The action that held ev during the last bind_slot call ("" when none); names the partner of a swap or refusal.
static var last_other := ""

## Writes ev into one slot; an equal event on another action swaps in the displaced one.
## Returns BOUND, SWAPPED (the other action took the displaced event), or REFUSED (no change: fixed pool, stick axis,
## or a swap that would leave the other action unbound).
static func bind_slot(action: String, pool: String, slot: int, ev: InputEvent) -> int:
	last_other = ""
	if not Table.can_rebind(action, pool) or not event_in_pool(ev, pool):
		return REFUSED
	if ev is InputEventJoypadMotion:
		var ax: int = (ev as InputEventJoypadMotion).axis
		if ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y or ax == JOY_AXIS_RIGHT_X or ax == JOY_AXIS_RIGHT_Y:
			return REFUSED
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var other_act: String = ""
	var other_slot: int = -1
	for r: Dictionary in Table.rebindable():
		var a: String = str(r.id)
		var evs: Array = pool_events(a, pool)
		for i: int in evs.size():
			if events_equal(evs[i], ev) and not (a == action and i == slot):
				other_act = a
				other_slot = i
				break
		if other_act != "":
			break
	var displaced: InputEvent = slot_event(action, pool, slot)
	last_other = other_act
	if other_act == action and displaced == null:
		last_other = ""
		return REFUSED
	if other_act != "" and displaced == null and pool_events(other_act, pool).size() < 2:
		return REFUSED
	_write_slot(action, pool, slot, ev)
	if other_act != "":
		_write_slot(other_act, pool, other_slot, displaced)
		return SWAPPED
	return BOUND

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
	for r: Dictionary in Table.rebindable():
		var a: String = str(r.id)
		if not InputMap.has_action(a):
			continue
		var keep: Array = []
		for e in InputMap.action_get_events(a):
			if not event_in_pool(e, pool):
				keep.append(e)
		InputMap.action_erase_events(a)
		for e: Variant in keep:
			InputMap.action_add_event(a, e)
		for e: InputEvent in Table.stock(r, pool):
			InputMap.action_add_event(a, e)
