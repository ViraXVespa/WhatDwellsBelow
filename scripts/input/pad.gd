extends RefCounted

const PAD := {
	"interact": JOY_BUTTON_A,
	"dash": JOY_BUTTON_B,
	"target_lock": JOY_BUTTON_RIGHT_STICK,
	"pause": JOY_BUTTON_START,
	"map_view": JOY_BUTTON_BACK,
	"potion": JOY_BUTTON_DPAD_UP,
	"food": JOY_BUTTON_DPAD_LEFT,
	"tab_left": JOY_BUTTON_LEFT_SHOULDER,
	"tab_right": JOY_BUTTON_RIGHT_SHOULDER,
}

static var was: Dictionary = {}
static var edge: Dictionary = {}
static var eat_pause := false
static var mode := false


static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		mode = true
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.24:
		mode = true
		return
	if event is InputEventMouseButton and event.pressed:
		mode = false
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		mode = false


static func wake_web() -> void:
	if Engine.get_main_loop() == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.root.get_viewport().gui_release_focus()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function () {
			var c = document.getElementById('canvas');
			if (!c) return;
			c.tabIndex = 0;
			c.focus();
		})();
	""", true)


static func id() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if not pads.is_empty() else -1


static func stick(lx: int, ly: int, dead := 0.24) -> Vector2:
	var pid := id()
	if pid < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(pid, lx), Input.get_joy_axis(pid, ly))
	return v if v.length() >= dead else Vector2.ZERO


static func move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 0.01:
		return v
	return stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)


static func aim() -> Vector2:
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() > 0.01:
		return v
	return stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


static func held(action: String) -> bool:
	if Input.is_action_pressed(action):
		return true
	var pid := id()
	if pid >= 0:
		if action == "attack" and Input.get_joy_axis(pid, JOY_AXIS_TRIGGER_RIGHT) > 0.45:
			return true
		if action == "special" and Input.get_joy_axis(pid, JOY_AXIS_TRIGGER_LEFT) > 0.45:
			return true
		if PAD.has(action) and Input.is_joy_button_pressed(pid, int(PAD[action])):
			return true
	return false


static func just(action: String) -> bool:
	return bool(edge.get(action, false))


static func pause_just() -> bool:
	if eat_pause:
		return false
	return Input.is_action_just_pressed("pause") or just("pause")


static func swallow_close() -> void:
	for action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock", "pause"]:
		edge[action] = false
		was[action] = true
	eat_pause = true


static func blocked(action: String) -> bool:
	if not App.ui_open:
		return false
	return action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock"]


static func tick() -> void:
	if stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).length() >= 0.24:
		mode = true
	elif stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).length() >= 0.24:
		mode = true
	edge.clear()
	var names: Array = PAD.keys()
	names.append_array(["attack", "special"])
	for action in names:
		var key := str(action)
		var now := held(key)
		if now and id() >= 0:
			var pid := id()
			var from_pad := false
			if key == "attack" and Input.get_joy_axis(pid, JOY_AXIS_TRIGGER_RIGHT) > 0.45:
				from_pad = true
			elif key == "special" and Input.get_joy_axis(pid, JOY_AXIS_TRIGGER_LEFT) > 0.45:
				from_pad = true
			elif PAD.has(key) and Input.is_joy_button_pressed(pid, int(PAD[key])):
				from_pad = true
			if from_pad:
				mode = true
		if blocked(key):
			edge[key] = false
		else:
			edge[key] = now and not bool(was.get(key, false))
		was[key] = now
	if eat_pause:
		var held_pause := Input.is_action_pressed("pause") or Input.is_action_pressed("ui_cancel")
		if not held_pause:
			var pid := id()
			if pid >= 0:
				held_pause = Input.is_joy_button_pressed(pid, JOY_BUTTON_START) or Input.is_joy_button_pressed(pid, JOY_BUTTON_B)
		if not held_pause:
			eat_pause = false


static func web_buttons() -> PackedFloat32Array:
	if not OS.has_feature("web"):
		return PackedFloat32Array()
	var raw := str(JavaScriptBridge.eval("""
		(function () {
			var pads = navigator.getGamepads ? navigator.getGamepads() : [];
			for (var i = 0; i < pads.length; i++) {
				if (!pads[i] || !pads[i].buttons) continue;
				return JSON.stringify(pads[i].buttons.map(function (b) { return b.value; }));
			}
			return "[]";
		})();
	""", true))
	var parsed: Variant = JSON.parse_string(raw)
	var out := PackedFloat32Array()
	if parsed is Array:
		for v in parsed:
			out.append(float(v))
	return out