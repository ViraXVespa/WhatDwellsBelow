extends Node

var move := Vector2.ZERO
var aim := Vector2.ZERO
var attack := false
var special := false
var a := false
var b := false
var start := false
var back := false
var ls := false
var device_ok := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
    if not OS.has_feature("web"):
        return
    var raw := str(JavaScriptBridge.eval("""
        (function () {
            var pads = navigator.getGamepads ? navigator.getGamepads() : [];
            for (var i = 0; i < pads.length; i++) {
                var g = pads[i];
                if (!g) continue;
                return JSON.stringify({
                    ax: Array.from(g.axes || []),
                    bt: (g.buttons || []).map(function (b) { return b.value; })
                });
            }
            return "";
        })();
    """, true))
    if raw.is_empty():
        device_ok = false
        move = Vector2.ZERO
        aim = Vector2.ZERO
        attack = false
        special = false
        return
    var data: Variant = JSON.parse_string(raw)
    if typeof(data) != TYPE_DICTIONARY:
        return
    device_ok = true
    var ax: Array = data.get("ax", [])
    var bt: Array = data.get("bt", [])
    move = _stick(ax, 0, 1)
    aim = _stick(ax, 2, 3)
    attack = _held(bt, 7) or _axis(ax, 5)
    special = _held(bt, 6) or _axis(ax, 4)
    a = _held(bt, 0)
    b = _held(bt, 1)
    start = _held(bt, 9)
    back = _held(bt, 8)
    ls = _held(bt, 11)

func _stick(ax: Array, x: int, y: int) -> Vector2:
    var v := Vector2(_axis_at(ax, x), _axis_at(ax, y))
    return v if v.length() >= 0.24 else Vector2.ZERO

func _axis_at(ax: Array, i: int) -> float:
    return float(ax[i]) if i < ax.size() else 0.0

func _held(bt: Array, i: int) -> bool:
    return i < bt.size() and float(bt[i]) >= 0.45

func _axis(ax: Array, i: int) -> bool:
    return _axis_at(ax, i) >= 0.45