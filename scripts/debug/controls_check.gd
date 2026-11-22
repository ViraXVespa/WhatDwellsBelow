extends RefCounted

## Default controls probe (camp-controls flow). Getters act or check and return "ok" / "" or the first fault.
## .pad_defaults: the W13 Xbox layout (X attack, A special, Y interact, B back and nothing else, RB dash, LT aim,
## RT fire, View inventory, Menu pause, D-pad right/left/up/down potion/food/map/target lock, R3 look mode).
## .kb_defaults: P / F / T bind by key label (a Dvorak or AZERTY press of the key printed P is Potion, the key at
## QWERTY P's position printing L is not), WASD stays physical. .migrate_untouched: a layout-1 save with no rebinds
## loads as the new layout. .migrate_kb_custom / .migrate_pad_custom: a layout-1 save with a rebind keeps that pool
## as saved (the other pool moves) and the new Bow aim / fire do not take an input the kept pool uses.
## .roundtrip: a layout-2 save keeps its rebinds and letter binds. .plant_caught: physical P for Potion, B left
## on Dash, and a layout-1 save loaded without migration must each be caught.

const Binds := preload("res://scripts/input/binds.gd")
const Table := preload("res://scripts/input/binds/table.gd")
const Migrate := preload("res://scripts/input/binds/migrate.gd")

const PAD := {JOY_BUTTON_X: "attack", JOY_BUTTON_A: "special", JOY_BUTTON_Y: "interact", JOY_BUTTON_B: "ui_cancel",
	JOY_BUTTON_RIGHT_SHOULDER: "dash", JOY_BUTTON_BACK: "inventory", JOY_BUTTON_START: "pause",
	JOY_BUTTON_DPAD_RIGHT: "potion", JOY_BUTTON_DPAD_LEFT: "food", JOY_BUTTON_DPAD_UP: "map_view",
	JOY_BUTTON_DPAD_DOWN: "target_lock", JOY_BUTTON_RIGHT_STICK: "look_mode"}
const WORLD: PackedStringArray = ["attack", "special", "aim", "fire", "dash", "target_lock", "interact", "map_view",
	"inventory", "potion", "food", "look_mode", "pause"]

var reset: String:
	get:
		Binds.reset()
		return "ok"
var pad_defaults: String:
	get:
		for b: int in PAD:
			var want: String = PAD[b]
			var got := _world_of(_joy(b))
			if want == "ui_cancel":
				if not _joy(b).is_action("ui_cancel") or got != "":
					return "B: want Back only, world actions %s" % got
			elif got != want:
				return "pad %d: want %s, got %s" % [b, want, got]
		if _world_of(_axis(JOY_AXIS_TRIGGER_LEFT)) != "aim" or _world_of(_axis(JOY_AXIS_TRIGGER_RIGHT)) != "fire":
			return "triggers: LT %s RT %s (want aim / fire)" % [_world_of(_axis(JOY_AXIS_TRIGGER_LEFT)), _world_of(_axis(JOY_AXIS_TRIGGER_RIGHT))]
		return ""
var kb_defaults: String:
	get:
		for pair: Array in [[KEY_P, "potion"], [KEY_F, "food"], [KEY_T, "target_lock"]]:
			var code: int = pair[0]
			for phys: int in [code, KEY_R, KEY_Y, KEY_K]:
				if not _key(code, phys).is_action(pair[1]):
					return "%s: the key printed %s (at QWERTY %s) does not fire it" % [pair[1], OS.get_keycode_string(code), OS.get_keycode_string(phys)]
			if _key(KEY_L, code).is_action(pair[1]):
				return "%s: bound by position (QWERTY %s printing L fires it)" % [pair[1], OS.get_keycode_string(code)]
		if not _key(KEY_Z, KEY_W).is_action("move_up") or _key(KEY_W, KEY_Z).is_action("move_up"):
			return "move_up: not on the physical W position"
		if not _key(KEY_E, KEY_E).is_action("interact") or not _key(KEY_SHIFT, KEY_SHIFT).is_action("aim"):
			return "interact E / aim Shift missing"
		return ""
var migrate_untouched: String:
	get:
		Binds.reset()
		Binds.apply(legacy_rows({}))
		return _first([pad_defaults, kb_defaults], "untouched layout-1 save")
var migrate_kb_custom: String:
	get:
		Binds.reset()
		Binds.apply(legacy_rows({"dash|kb": [_key(KEY_F9, KEY_F9)]}))
		var d: InputEvent = Binds.slot_event("dash", "kb", 0)
		var pot: InputEventKey = Binds.slot_event("potion", "kb", 0) as InputEventKey
		if not (d is InputEventKey and (d as InputEventKey).physical_keycode == KEY_F9):
			return "kb custom: Dash lost its F9 rebind"
		if pot == null or pot.physical_keycode != KEY_F:
			return "kb custom: the saved keyboard layout moved (Potion %s)" % pot
		return _first([pad_defaults], "kb custom: pad pool")
var migrate_pad_custom: String:
	get:
		Binds.reset()
		Binds.apply(legacy_rows({"potion|pad": [_joy(JOY_BUTTON_Y)]}))
		if _world_of(_joy(JOY_BUTTON_Y)) != "potion" or _world_of(_axis(JOY_AXIS_TRIGGER_RIGHT)) != "attack":
			return "pad custom: saved pad layout not kept (Y %s, RT %s)" % [_world_of(_joy(JOY_BUTTON_Y)), _world_of(_axis(JOY_AXIS_TRIGGER_RIGHT))]
		if _all_of(_axis(JOY_AXIS_TRIGGER_LEFT)).size() != 1:
			return "pad custom: LT doubles up %s" % str(_all_of(_axis(JOY_AXIS_TRIGGER_LEFT)))
		return _first([kb_defaults], "pad custom: keyboard pool")
var roundtrip: String:
	get:
		Binds.reset()
		Binds.bind_slot("dash", "kb", 0, _key(KEY_F9, KEY_F9))
		var rows: Array = Binds.collect()
		Binds.reset()
		Binds.apply(rows)
		var d: InputEventKey = Binds.slot_event("dash", "kb", 0) as InputEventKey
		if d == null or d.physical_keycode != KEY_F9:
			return "roundtrip: Dash rebind lost"
		return _first([kb_defaults], "roundtrip")
var plant_caught: String:
	get:
		Binds.reset()
		var phys := InputEventKey.new()
		phys.physical_keycode = KEY_P
		InputMap.action_erase_events("potion")
		InputMap.action_add_event("potion", phys)
		var a := kb_defaults
		Binds.reset()
		InputMap.action_add_event("dash", _joy(JOY_BUTTON_B))
		var b := pad_defaults
		Binds.reset()
		var rows := legacy_rows({})
		rows.append({"action": Migrate.LAYOUT_ROW, "v": Table.LAYOUT})
		Binds.apply(rows)
		var c := pad_defaults
		Binds.reset()
		if a == "" or b == "" or c == "":
			return "plant missed: physical P '%s' B on dash '%s' unmigrated '%s'" % [a, b, c]
		return ""

## A layout-1 save: every table row at its layout-1 defaults; over = {"action|pool": [events]} replaces one.
static func legacy_rows(over: Dictionary) -> Array:
	var rows: Array = []
	for r: Dictionary in Table.ROWS:
		var id: String = str(r.id)
		if Migrate.NEW_IN_2.has(id):
			continue
		var old: Dictionary = Migrate.LEGACY_1.get(id, r)
		for pool: String in ["kb", "pad"]:
			var evs: Array = over.get(id + "|" + pool, Table.stock(old, pool))
			for e: InputEvent in evs:
				rows.append(Migrate.row_of(id, e, pool))
	return rows

static func _first(faults: Array, what: String) -> String:
	for f: String in faults:
		if f != "":
			return what + ": " + f
	return ""

static func _all_of(ev: InputEvent) -> PackedStringArray:
	var out := PackedStringArray()
	for a: String in WORLD:
		if InputMap.has_action(a) and ev.is_action(a):
			out.append(a)
	return out

static func _world_of(ev: InputEvent) -> String:
	return ",".join(_all_of(ev))

static func _joy(b: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b as JoyButton
	e.pressed = true
	return e

static func _axis(ax: int) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = ax as JoyAxis
	e.axis_value = 1.0
	return e

## A key press as a layout delivers it: code = the printed label, phys = the position (QWERTY name).
static func _key(code: int, phys: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = phys as Key
	e.pressed = true
	return e
