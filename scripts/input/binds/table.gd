extends RefCounted

## The one home for input bindings: every action, its default keys / mouse / pad buttons, and which
## pools the Controls page may rebind. Defaults, Reset Controls, the rebind page, saves, and every
## on-screen hint read from here (names and glyphs come from the live InputMap via prompts.gd).
## rebind: "both" | "kb" | "pad" | "" (fixed). axis rows are [axis, sign]. web: extra pad buttons on web.
## kb rows bind by physical position (WASD stays put on AZERTY); "letter" rows bind by the key's printed label
## (logical keycode), so P / F / T mnemonics stay on P / F / T on AZERTY, QWERTZ and Dvorak.
## LAYOUT bumps when a default changes; binds/migrate.gd moves untouched saves from the older defaults.

const ROWS: Array = [
	{"id": "move_up", "label": "Move up", "rebind": "kb", "kb": [KEY_W, KEY_UP], "axis": [[JOY_AXIS_LEFT_Y, -1.0]]},
	{"id": "move_down", "label": "Move down", "rebind": "kb", "kb": [KEY_S, KEY_DOWN], "axis": [[JOY_AXIS_LEFT_Y, 1.0]]},
	{"id": "move_left", "label": "Move left", "rebind": "kb", "kb": [KEY_A, KEY_LEFT], "axis": [[JOY_AXIS_LEFT_X, -1.0]]},
	{"id": "move_right", "label": "Move right", "rebind": "kb", "kb": [KEY_D, KEY_RIGHT], "axis": [[JOY_AXIS_LEFT_X, 1.0]]},
	{"id": "aim_left", "axis": [[JOY_AXIS_RIGHT_X, -1.0]]},
	{"id": "aim_right", "axis": [[JOY_AXIS_RIGHT_X, 1.0]]},
	{"id": "aim_up", "axis": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	{"id": "aim_down", "axis": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	{"id": "attack", "label": "Attack", "rebind": "both", "mouse": [MOUSE_BUTTON_LEFT], "pad": [JOY_BUTTON_X]},
	{"id": "special", "label": "Special", "rebind": "both", "mouse": [MOUSE_BUTTON_RIGHT], "pad": [JOY_BUTTON_A]},
	{"id": "aim", "label": "Bow aim (Bow mode)", "rebind": "both", "kb": [KEY_SHIFT], "axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]], "web": [6]},
	{"id": "fire", "label": "Bow fire (Bow mode)", "rebind": "pad", "axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], "web": [7]},
	{"id": "dash", "label": "Dash", "rebind": "both", "kb": [KEY_SPACE], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"id": "target_lock", "label": "Target lock", "rebind": "both", "letter": [KEY_T], "pad": [JOY_BUTTON_DPAD_DOWN]},
	{"id": "interact", "label": "Interact", "rebind": "both", "kb": [KEY_E, KEY_ENTER, KEY_KP_ENTER], "pad": [JOY_BUTTON_Y]},
	{"id": "map_view", "label": "Map", "rebind": "both", "kb": [KEY_M], "pad": [JOY_BUTTON_DPAD_UP]},
	{"id": "inventory", "label": "Inventory", "rebind": "both", "kb": [KEY_I], "pad": [JOY_BUTTON_BACK]},
	{"id": "potion", "label": "Potion", "rebind": "both", "letter": [KEY_P], "pad": [JOY_BUTTON_DPAD_RIGHT]},
	{"id": "food", "label": "Food", "rebind": "both", "letter": [KEY_F], "pad": [JOY_BUTTON_DPAD_LEFT]},
	{"id": "look_mode", "label": "Look mode", "rebind": "pad", "pad": [JOY_BUTTON_RIGHT_STICK]},
	{"id": "pause", "label": "Pause menu", "rebind": "both", "kb": [KEY_ESCAPE], "pad": [JOY_BUTTON_START]},
	{"id": "tab_left", "label": "Menu tab left", "rebind": "both", "kb": [KEY_BRACKETLEFT], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	{"id": "tab_right", "label": "Menu tab right", "rebind": "both", "kb": [KEY_BRACKETRIGHT], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"id": "gear_tip", "label": "Item tip", "rebind": "both", "kb": [KEY_Y], "pad": [JOY_BUTTON_Y]},
	{"id": "gear_drop", "label": "Item drop (hold: destroy)", "rebind": "both", "kb": [KEY_X], "pad": [JOY_BUTTON_X]},
	{"id": "crystal_zoom", "label": "Crystal map zoom", "rebind": "both", "kb": [KEY_TAB], "pad": [JOY_BUTTON_Y]},
	{"id": "anim_model_prev", "kb": [KEY_COMMA], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	{"id": "anim_model_next", "kb": [KEY_PERIOD], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	{"id": "anim_idle", "kb": [KEY_I], "pad": [JOY_BUTTON_RIGHT_STICK]},
	{"id": "anim_play", "kb": [KEY_P]},
	{"id": "anim_list_up", "kb": [KEY_PAGEUP], "axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	{"id": "anim_list_down", "kb": [KEY_PAGEDOWN], "axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	{"id": "anim_back", "kb": [KEY_BACKSPACE, KEY_ESCAPE], "pad": [JOY_BUTTON_B]},
]

## Fixed menu navigation (Godot ui_* actions). Not rebindable; Esc and B stay Back in menus.
const MENU: Array = [
	{"id": "ui_accept", "kb": [KEY_ENTER, KEY_KP_ENTER], "pad": [JOY_BUTTON_A]},
	{"id": "ui_cancel", "kb": [KEY_ESCAPE, KEY_BACKSPACE], "pad": [JOY_BUTTON_B]},
	{"id": "ui_left", "kb": [KEY_LEFT, KEY_A], "pad": [JOY_BUTTON_DPAD_LEFT]},
	{"id": "ui_right", "kb": [KEY_RIGHT, KEY_D], "pad": [JOY_BUTTON_DPAD_RIGHT]},
	{"id": "ui_up", "kb": [KEY_UP, KEY_W], "pad": [JOY_BUTTON_DPAD_UP]},
	{"id": "ui_down", "kb": [KEY_DOWN, KEY_S], "pad": [JOY_BUTTON_DPAD_DOWN]},
	{"id": "page_prev", "kb": [KEY_Q], "axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	{"id": "page_next", "kb": [KEY_E], "axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
]

const LAYOUT := 2

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r: Dictionary in ROWS:
		out.append(str(r.id))
	return out

static func row(id: String) -> Dictionary:
	for r: Dictionary in ROWS:
		if r.id == id:
			return r
	return {}

## Rows the Controls page lists (and Reset / swap act on).
static func rebindable() -> Array:
	var out: Array = []
	for r: Dictionary in ROWS:
		if str(r.get("rebind", "")) != "":
			out.append(r)
	return out

static func can_rebind(id: String, pool: String) -> bool:
	var m: String = str(row(id).get("rebind", ""))
	return m == "both" or m == pool

## Default events of one action in one pool ("kb" = keys + mouse, "pad" = buttons + axes).
static func stock(r: Dictionary, pool: String) -> Array:
	var out: Array = []
	if pool == "kb":
		for k: int in r.get("kb", []):
			var e := InputEventKey.new()
			e.physical_keycode = k as Key
			out.append(e)
		for k: int in r.get("letter", []):
			var lk := InputEventKey.new()
			lk.keycode = k as Key
			out.append(lk)
		for b: int in r.get("mouse", []):
			var m := InputEventMouseButton.new()
			m.button_index = b as MouseButton
			out.append(m)
		return out
	for b: int in r.get("pad", []):
		out.append(_joy(b))
	for a: Array in r.get("axis", []):
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(a[0]) as JoyAxis
		jm.axis_value = float(a[1])
		out.append(jm)
	if OS.has_feature("web"):
		for b: int in r.get("web", []):
			out.append(_joy(b))
	return out

static func _joy(b: int) -> InputEventJoypadButton:
	var jb := InputEventJoypadButton.new()
	jb.button_index = b as JoyButton
	return jb
