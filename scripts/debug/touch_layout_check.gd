extends RefCounted

## Touch overlay probe (dungeon-touch-controls flow). Checks return "" or the first fault; press getters act, "ok".
## .geometry: hud_layout.compute for phone / 16:9 / 4:3 canvases, with and without notch insets and Bow mode:
## every control inside the safe area, no two overlapping, the playfield centre clear, the move ring in its zone,
## each centre hit-tests to its own control. .plant_caught: an overlap, an off-screen button and a centre blocker fed
## to the same validator must each fail. Live (the real TouchHud via _input): .buttons taps each world button and
## reads it back as held through Touch and Pad, then released; .dash_down / .dash_fired, .lock_tap / .lock_toggled,
## .move_down / .move_walked and .bow_down / .bow_aimed drive the game over frames.

const Layout := preload("res://scripts/ui/touch_hud/hud_layout.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")
const BowMode := preload("res://scripts/world/player/bow_mode.gd")

const VPS: Array[Vector2] = [Vector2(2340, 1080), Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1440, 1080)]
const NOTCH := Vector4(130, 0, 130, 60)
const WORLD: PackedStringArray = ["special", "dash", "interact", "potion", "food", "target_lock"]

static var _p0 := Vector3.ZERO
static var _lock0 := false
static var _x0 := 0.0

static func _p() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("player") if tree else null

static func _hud() -> CanvasLayer:
	return App.touch_hud as CanvasLayer

static func _vp() -> Vector2:
	return _hud().get_viewport().get_visible_rect().size

static func _row(action: String) -> Dictionary:
	for r: Dictionary in _hud()._btns:
		if str(r["action"]) == action:
			return r
	return {}

static func _touch(idx: int, pos: Vector2, on: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = on
	_hud()._input(e)

static func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	_hud()._input(e)

## The first fault in a layout, or "".
static func validate(vp: Vector2, ins: Vector4, rows: Array) -> String:
	var safe := Rect2(ins.x, ins.y, vp.x - ins.x - ins.z, vp.y - ins.y - ins.w)
	var mid := Rect2(vp * Vector2(0.35, 0.3), vp * Vector2(0.3, 0.4))
	for i in rows.size():
		var a: Dictionary = rows[i]
		var c: Vector2 = a["pos"]
		var r: float = a["r"]
		if not safe.encloses(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)):
			return "%s at %s r%.0f leaves the safe area %s (vp %s)" % [a["action"], c, r, safe, vp]
		if mid.grow(r).has_point(c):
			return "%s at %s covers the playfield centre (vp %s)" % [a["action"], c, vp]
		var hit: Dictionary = Layout.hit(rows, c, Layout.scale_for(vp))
		if hit.is_empty() or str(hit["action"]) != str(a["action"]):
			return "%s centre hit-tests to %s" % [a["action"], hit.get("action", "nothing")]
		for j in range(i + 1, rows.size()):
			var b: Dictionary = rows[j]
			if c.distance_to(b["pos"]) < r + float(b["r"]):
				return "%s overlaps %s (vp %s)" % [a["action"], b["action"], vp]
	var home := Layout.move_home(vp, ins)
	var mr := Layout.move_radius(vp)
	if not Layout.in_move_zone(vp, home) or not safe.encloses(Rect2(home - Vector2(mr, mr), Vector2(mr, mr) * 2.0)):
		return "move ring at %s outside its zone (vp %s)" % [home, vp]
	return ""

var geometry: String:
	get:
		for vp: Vector2 in VPS:
			for ins: Vector4 in [Vector4.ZERO, NOTCH]:
				for bow: bool in [false, true]:
					var rows := Layout.compute(vp, ins, bow)
					if rows.size() != 9:
						return "%d controls, want 9" % rows.size()
					if bow != (str(rows[0]["kind"]) == "stick"):
						return "Bow mode %s but Attack kind %s" % [bow, rows[0]["kind"]]
					var bad := validate(vp, ins, rows)
					if bad != "":
						return bad
		return ""

var plant_caught: String:
	get:
		var vp := Vector2(2340, 1080)
		var plants := {
			"overlap": func(rows: Array) -> void: rows[1]["pos"] = rows[0]["pos"] + Vector2(-40, 0),
			"off-screen": func(rows: Array) -> void: rows[0]["pos"] += Vector2(220, 0),
			"centre": func(rows: Array) -> void: rows[2]["pos"] = vp * 0.5,
		}
		for name: String in plants:
			var rows := Layout.compute(vp, Vector4.ZERO, false)
			(plants[name] as Callable).call(rows)
			if validate(vp, Vector4.ZERO, rows) == "":
				return "planted %s passed" % name
		return ""

var setup: String:
	get:
		Touch.force_show = true
		BowMode.enabled = false
		_p().set_weapon("great_axe")
		_hud()._refresh()
		return "ok" if _hud().visible and _hud()._btns.size() == 9 else "touch HUD hidden (%d rows)" % _hud()._btns.size()

var buttons: String:
	get:
		var bad := validate(_vp(), Touch.safe_insets(_vp()), _hud()._btns)
		if bad != "":
			return "live layout: " + bad
		for i in WORLD.size():
			var a := WORLD[i]
			var row := _row(a)
			_touch(i, row["pos"] + Vector2(row["r"], 0) * 0.6, true)
			var on := Touch.held(a) and App.pad_held(a)
			_touch(i, row["pos"], false)
			if not on:
				return "tap on %s did not hold it" % a
			if Touch.held(a):
				return "%s stuck after release" % a
		var at := _row("attack")
		_touch(7, at["pos"], true)
		var atk := Touch.held("attack")
		_touch(7, at["pos"], false)
		return "" if atk else "tap on attack did not hold it"

var dash_down: String:
	get:
		_touch(1, _row("dash")["pos"], true)
		return "ok"
var dash_fired: String:
	get:
		var t: float = _p().dash_t
		_touch(1, _row("dash")["pos"], false)
		return "" if t > 0.0 else "dash button: no dash (dash_t %.2f)" % t
var lock_tap: String:
	get:
		_lock0 = bool(_p().lock_armed)
		_touch(2, _row("target_lock")["pos"], true)
		return "ok"
var lock_toggled: String:
	get:
		_touch(2, _row("target_lock")["pos"], false)
		var now := bool(_p().lock_armed)
		return "" if now != _lock0 else "lock button: lock_armed stayed %s" % now
var move_down: String:
	get:
		var home: Vector2 = _hud()._move_home
		_p0 = _p().global_position
		_touch(3, home, true)
		_drag(3, home + Vector2(_hud()._move_r, 0))
		return "ok"
var move_walked: String:
	get:
		var mv: Vector2 = Touch.move
		var dx: float = _p().global_position.x - _p0.x
		_touch(3, _hud()._move_home, false)
		if mv.x < 0.9:
			return "move stick: Touch.move %s" % mv
		return "" if dx > 0.2 else "move stick: player moved %.2f in x" % dx
var bow_on: String:
	get:
		_p().set_weapon("longbow")
		BowMode.enabled = true
		_hud()._refresh()
		return "ok" if str(_row("attack").get("kind", "")) == "stick" else "Bow mode on but no aim stick"
var bow_down: String:
	get:
		var row := _row("attack")
		_touch(4, row["pos"], true)
		_drag(4, row["pos"] + Vector2(0, -float(row["r"])))
		return "ok"
var bow_aimed: String:
	get:
		var p := _p()
		var d: Vector2 = p.aim_dir
		var aiming := BowMode.aiming()
		var st: int = int(p.atk_state)
		_touch(4, _row("attack")["pos"], false)
		if not aiming:
			return "bow stick: not aiming"
		if d.y > -0.9:
			return "bow stick: aim_dir %s, want up" % d
		return "" if st != int(p.ATK_NONE) else "bow stick: no shot"
var teardown: String:
	get:
		BowMode.enabled = false
		return "ok"
