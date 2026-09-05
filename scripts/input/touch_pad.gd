
extends RefCounted

## Web-only virtual pad state. TouchHud writes sticks/buttons; Pad reads them.

const ACTIONS: PackedStringArray = [
    "attack", "special", "dash", "interact", "pause",
    "map_view", "potion", "food", "target_lock",
]

static var mobile_ua := false
static var ua_ready := false
static var phys_kb := false
static var move := Vector2.ZERO
static var aim := Vector2.ZERO
static var down: Dictionary = {}
static var attack_latch := false
static var tap_window := 0.28
static var dead := 0.24
static var _attack_finger := false
static var _attack_cancel := false
static var _attack_armed := false
static var _attack_tap_at := -999.0


static func reset_defaults() -> void:
    tap_window = 0.28
    dead = 0.24


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
        clear_world()


static func wants_device() -> bool:
    if not OS.has_feature("web"):
        return false
    _probe_ua()
    if not mobile_ua or phys_kb:
        return false
    return not _pad_connected()


static func wants_show() -> bool:
    if not wants_device() or App.ui_open:
        return false
    return _play_surface()


static func active() -> bool:
    return wants_show()


static func set_move(v: Vector2) -> void:
    move = v if v.length() >= dead else Vector2.ZERO


static func set_aim(v: Vector2) -> void:
    aim = v if v.length() >= dead else Vector2.ZERO


static func set_held(action: String, on: bool) -> void:
    if action == "attack":
        return
    down[action] = on


static func attack_press(now: float) -> void:
    if attack_latch:
        attack_latch = false
        _attack_finger = false
        _attack_cancel = true
        _attack_armed = false
        return
    _attack_finger = true
    _attack_cancel = false
    if _attack_armed and now - _attack_tap_at <= tap_window:
        attack_latch = true
        _attack_armed = false


static func attack_release(now: float) -> void:
    _attack_finger = false
    if _attack_cancel:
        _attack_cancel = false
        _attack_armed = false
        return
    if attack_latch:
        return
    _attack_armed = true
    _attack_tap_at = now


static func held(action: String) -> bool:
    if not active():
        return false
    if action == "attack":
        return _attack_finger or attack_latch
    return bool(down.get(action, false))


static func clear_world() -> void:
    move = Vector2.ZERO
    aim = Vector2.ZERO
    down.clear()
    attack_latch = false
    _attack_finger = false
    _attack_cancel = false
    _attack_armed = false


static func _idle_sticks() -> void:
    move = Vector2.ZERO
    aim = Vector2.ZERO
    down.clear()
    attack_latch = false
    _attack_finger = false
    _attack_cancel = false
    _attack_armed = false


static func _play_surface() -> bool:
    var loop := Engine.get_main_loop()
    if loop == null:
        return false
    var tree := loop as SceneTree
    if tree == null or tree.current_scene == null:
        return false
    var path := str(tree.current_scene.scene_file_path)
    return path.ends_with("dungeon.tscn") or path.ends_with("camp.tscn")


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
    var raw := str(JavaScriptBridge.eval("""
        (function () {
            var pads = navigator.getGamepads ? navigator.getGamepads() : [];
            for (var i = 0; i < pads.length; i++) {
                if (pads[i]) return "1";
            }
            return "0";
        })();
    """, true))
    return raw == "1"
