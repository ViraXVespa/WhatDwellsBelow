extends RefCounted

## Web-only virtual pad state. TouchHud writes sticks/buttons; Pad reads them.

const WebPad := preload("res://scripts/web_pad.gd")
const T := preload("res://scripts/data/tunables.gd")

const ACTIONS: PackedStringArray = [
	"attack", "special", "dash", "interact", "pause",
	"map_view", "potion", "food", "target_lock", "aim", "fire",
]

static var mobile_ua := false
static var ua_ready := false
static var phys_kb := false
static var force_show := false
static var move := Vector2.ZERO
static var aim := Vector2.ZERO
static var move_live := false
static var down: Dictionary = {}
static var attack_latch := false
static var tap_window := T.TOUCH_TAP_WINDOW
static var dead := T.TOUCH_DEAD
static var _attack_finger := false

static func reset_defaults() -> void:
	tap_window = T.TOUCH_TAP_WINDOW
	dead = T.TOUCH_DEAD
	attack_latch = false

static func tick() -> void:
	_probe_ua()
	if not wants_device():
		_idle_sticks()
		return
	if App.ui_open:
		clear_world()

static func note_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		phys_kb = true
		if not force_show:
			clear_world()

static func wants_device() -> bool:
	if force_show:
		return true
	if not OS.has_feature("web"):
		return false
	_probe_ua()
	if not mobile_ua or phys_kb:
		return false
	return not _pad_connected()

static func wants_show() -> bool:
	if App.ui_open:
		return false
	if not wants_device():
		return false
	return _play_surface()

static func active() -> bool:
	return wants_show()

static func in_camp() -> bool:
	return _scene_path().ends_with("camp.tscn")

static func _scene_path() -> String:
	var n := scene_host()
	return str(n.scene_file_path) if n else ""

## The play scene: current_scene when it is set, else the shot-tool capture host, else the player's
## camp / dungeon ancestor. The shot tool reparents the scene into a SubViewport; Godot only accepts a
## direct child of root as current_scene, so that property stays null for the rest of the capture.
static func scene_host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if tree.current_scene:
		return tree.current_scene
	var win := tree.root
	if win:
		if win.has_meta("wdb_shot_host"):
			var h: Node = win.get_meta("wdb_shot_host") as Node
			if is_instance_valid(h):
				return h
		var snap: Node = win.find_child("ShotCapture", true, false)
		if snap and snap.get_child_count() > 0:
			return snap.get_child(0)
	var n: Node = tree.get_first_node_in_group("player")
	while n:
		var path := str(n.scene_file_path)
		if path.ends_with("dungeon.tscn") or path.ends_with("camp.tscn"):
			return n
		n = n.get_parent()
	return null

static func set_move(v: Vector2) -> void:
	move = v if v.length() >= dead else Vector2.ZERO

## The Bow mode aim stick (hud_input): a deflection past the deadzone steers the bow, else the lock / facing aims.
static func set_aim(v: Vector2) -> void:
	aim = v if v.length() >= dead else Vector2.ZERO

static func set_held(action: String, on: bool) -> void:
	if action == "attack":
		return
	down[action] = on

static func attack_press(_now: float) -> void:
	attack_latch = false
	_attack_finger = true

static func attack_release(_now: float) -> void:
	attack_latch = false
	_attack_finger = false

static func held(action: String) -> bool:
	if not active():
		return false
	if action == "attack":
		return _attack_finger
	return bool(down.get(action, false))

static func clear_world() -> void:
	move = Vector2.ZERO
	aim = Vector2.ZERO
	move_live = false
	down.clear()
	attack_latch = false
	_attack_finger = false

static func _idle_sticks() -> void:
	clear_world()

static func _play_surface() -> bool:
	var path := _scene_path()
	return path.ends_with("dungeon.tscn") or path.ends_with("camp.tscn")

## Safe-area insets in canvas units (x left, y top, z right, w bottom): the CSS env(safe-area-inset-*) on web,
## the display safe area elsewhere. Probed once per viewport size.
static var _ins_vp := Vector2(-1, -1)
static var _ins := Vector4.ZERO

static func safe_insets(vp: Vector2) -> Vector4:
	if vp == _ins_vp:
		return _ins
	_ins_vp = vp
	_ins = Vector4.ZERO
	if OS.has_feature("web"):
		var raw := str(JavaScriptBridge.eval("""
			(function () {
				var d = document.createElement('div');
				d.style.cssText = 'position:fixed;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
				document.body.appendChild(d);
				var s = getComputedStyle(d);
				var out = [s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom, window.innerWidth].map(parseFloat).join(',');
				d.remove();
				return out;
			})();
		""", true))
		var p := raw.split(",")
		if p.size() == 5 and float(p[4]) > 0.0:
			var k: float = vp.x / float(p[4])
			_ins = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3])) * k
	elif OS.has_feature("mobile"):
		var scr := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if scr.x > 0.0 and safe.size.x > 0 and Vector2(safe.size) != scr:
			var k2: float = vp.x / scr.x
			_ins = Vector4(safe.position.x, safe.position.y, scr.x - safe.end.x, scr.y - safe.end.y) * k2
	return _ins

static func _probe_ua() -> void:
	if ua_ready or not OS.has_feature("web"):
		return
	ua_ready = true
	var raw := str(JavaScriptBridge.eval("""
		(function () {
			var ch = navigator.userAgentData;
			if (ch && typeof ch.mobile === "boolean") return ch.mobile ? "1" : "0";
			var ua = navigator.userAgent || "";
			return /Mobi|Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(ua) ? "1" : "0";
		})();
	""", true))
	mobile_ua = raw == "1"

static func _pad_connected() -> bool:
	if not Input.get_connected_joypads().is_empty():
		return true
	if not OS.has_feature("web"):
		return false
	return WebPad.js_pad_any()
