extends RefCounted

const Touch := preload("res://scripts/input/touch_pad.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const Disp := preload("res://scripts/display_mode.gd")

## Actions whose press edge Pad tracks. Which pad button or trigger drives each comes from the InputMap (binds/table.gd).
const TRACKED: PackedStringArray = [
	"interact", "dash", "target_lock", "pause", "map_view", "potion", "food", "look_mode",
	"tab_left", "tab_right", "attack", "special",
]

static var was: Dictionary = {}
static var edge: Dictionary = {}
static var eat_pause := false
static var mode := false

static func note_event(event: InputEvent) -> void:
	Touch.note_event(event)
	Look.note_event(event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if Touch.wants_device():
			_set_mode(true)
		return
	if Touch.wants_device() and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventJoypadButton and event.pressed:
		_set_mode(true)
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.24:
		_set_mode(true)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_set_mode(false)
		return
	if event is InputEventMouseButton and event.pressed:
		_set_mode(false)
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		_set_mode(false)

static func _set_mode(pad_on: bool) -> void:
	if mode == pad_on:
		return
	mode = pad_on
	_refresh_prompts()

static func _refresh_prompts() -> void:
	var Prompts = load("res://scripts/input/prompts.gd")
	var PView = load("res://scripts/ui/prompt_view.gd")
	if Prompts.dirty():
		PView.pulse()

static func wake_web(release_gui: bool = true) -> void:
	if Engine.get_main_loop() == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree and release_gui:
		tree.root.get_viewport().gui_release_focus()
	if not OS.has_feature("web"):
		return
	Disp.ensure_web_hooks()
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

static func stick(lx: JoyAxis, ly: JoyAxis, dead := 0.24) -> Vector2:
	var pid := id()
	if pid < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(pid, lx), Input.get_joy_axis(pid, ly))
	return v if v.length() >= dead else Vector2.ZERO

static func move() -> Vector2:
	if Touch.active() and Touch.move.length() > 0.01:
		return Touch.move
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 0.01:
		return v
	return stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)

static func aim() -> Vector2:
	if Look.eats_aim():
		return Vector2.ZERO
	if Touch.active() and Touch.aim.length() > 0.01:
		return Touch.aim
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() > 0.01:
		return v
	return stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

static func held(action: String) -> bool:
	if Touch.held(action):
		return true
	if Input.is_action_pressed(action):
		return true
	return pad_down(action)

## True while any pad button or trigger bound to `action` (in the live InputMap) is down on the first pad.
static func pad_down(action: String) -> bool:
	var pid := id()
	if pid < 0 or not InputMap.has_action(action):
		return false
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and Input.is_joy_button_pressed(pid, (e as InputEventJoypadButton).button_index):
			return true
		if e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			if signf(Input.get_joy_axis(pid, m.axis)) == signf(m.axis_value) and absf(Input.get_joy_axis(pid, m.axis)) > 0.45:
				return true
	return false

static func just(action: String) -> bool:
	if eat_pause and action in ["dash", "pause", "interact", "attack", "special", "potion", "food", "target_lock"]:
		return false
	if bool(edge.get(action, false)):
		return true
	if blocked(action):
		return false
	if bool(was.get(action, false)):
		return false
	return Input.is_action_just_pressed(action)

static func pause_just() -> bool:
	var menu_open := App != null and App.pause_menu != null and bool(App.pause_menu.get("open"))
	if Disp.consume_web_esc():
		if Input.is_action_pressed("pause"):
			Input.action_release("pause")
		if menu_open:
			return false
		if eat_pause:
			return false
		return true
	if menu_open or eat_pause:
		return false
	return Input.is_action_just_pressed("pause") or just("pause")

static func swallow_close() -> void:
	for action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock", "pause"]:
		edge[action] = false
		was[action] = true
	eat_pause = true
	Look.clear()

static func blocked(action: String) -> bool:
	if not App.ui_open:
		return false
	return action in ["dash", "attack", "special", "interact", "potion", "food", "target_lock"]

static func tick() -> void:
	Touch.tick()
	Look.tick(_dt())
	if Touch.active():
		_set_mode(true)
	if stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).length() >= 0.24:
		_set_mode(true)
	elif stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).length() >= 0.24:
		_set_mode(true)
	edge.clear()
	for key in TRACKED:
		var now := held(key)
		if now and pad_down(key):
			_set_mode(true)
		if blocked(key) or eat_pause:
			edge[key] = false
		else:
			edge[key] = now and not bool(was.get(key, false))
		was[key] = now
	if eat_pause:
		var held_close := Input.is_action_pressed("pause") or Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("dash")
		if not held_close:
			held_close = pad_down("pause") or pad_down("ui_cancel")
		if not held_close and Touch.held("pause"):
			held_close = true
		if not held_close:
			eat_pause = false

static func _dt() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_process_delta_time()
	return 0.016666
