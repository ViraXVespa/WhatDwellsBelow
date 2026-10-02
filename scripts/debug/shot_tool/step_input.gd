extends RefCounted

## Shot flow input injection: pad buttons, actions, keys. Goes through Input.parse_input_event,
## so menus see the same events as a player (and gamepad glyphs switch on for pad presses).

const PAD := {
	"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
	"LB": JOY_BUTTON_LEFT_SHOULDER, "RB": JOY_BUTTON_RIGHT_SHOULDER,
	"START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK,
	"UP": JOY_BUTTON_DPAD_UP, "DOWN": JOY_BUTTON_DPAD_DOWN,
	"LEFT": JOY_BUTTON_DPAD_LEFT, "RIGHT": JOY_BUTTON_DPAD_RIGHT,
	"LS": JOY_BUTTON_LEFT_STICK, "RS": JOY_BUTTON_RIGHT_STICK,
}

static func make(spec: Dictionary, down: bool) -> InputEvent:
	if spec.has("pad"):
		var code: Variant = PAD.get(str(spec.pad).to_upper(), null)
		if code == null:
			return null
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(code) as JoyButton
		jb.pressed = down
		return jb
	if spec.has("action"):
		var ia := InputEventAction.new()
		ia.action = str(spec.action)
		ia.pressed = down
		ia.strength = 1.0 if down else 0.0
		return ia
	if spec.has("key"):
		var code2: Key = OS.find_keycode_from_string(str(spec.key))
		if code2 == KEY_NONE:
			return null
		var ik := InputEventKey.new()
		ik.keycode = code2
		ik.physical_keycode = code2
		ik.pressed = down
		return ik
	return null

## True when the spec names a known input. One tap = press, one frame, release, one frame.
static func tap(host: Node, spec: Dictionary) -> bool:
	var ev_down: InputEvent = make(spec, true)
	if ev_down == null:
		return false
	var tree: SceneTree = host.get_tree()
	Input.parse_input_event(ev_down)
	await tree.process_frame
	await tree.process_frame
	Input.parse_input_event(make(spec, false))
	await tree.process_frame
	return true

## Forces the glyph set (pad or keyboard) without pressing anything.
static func device(kind: String) -> void:
	var pad_mod: GDScript = load("res://scripts/input/pad.gd") as GDScript
	if pad_mod != null:
		pad_mod.call("_set_mode", kind == "pad")
