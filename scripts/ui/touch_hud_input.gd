extends Object

## Touch HUD pointer / pinch / pan input.

const Touch := preload("res://scripts/input/touch_pad.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const MapAct := preload("res://scripts/world/dungeon_map_act.gd")


static func handle_input(host: CanvasLayer, event: InputEvent) -> void:
	if not host.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			down(host, t.index, t.position)
		else:
			up(host, t.index)
		host.get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		drag(host, d.index, d.position)
		host.get_viewport().set_input_as_handled()

static func down(host: CanvasLayer, idx: int, pos: Vector2) -> void:
	for row in host._btns:
		if pos.distance_to(row["pos"]) <= float(row["r"]) + 8.0:
			var action := str(row["action"])
			if action == "map_view" and Touch.in_camp():
				return
			host._btn_i[idx] = action
			if action == "attack":
				Touch.attack_press(now())
			else:
				Touch.set_held(action, true)
			return
	if host._move_live:
		return
	host._free[idx] = pos
	host._park[idx] = pos
	if host._free.size() >= 2 and host._pinch_a < 0:
		begin_pinch(host)

static func drag(host: CanvasLayer, idx: int, pos: Vector2) -> void:
	if idx == host._move_i:
		var d: Vector2 = pos - host._move_origin
		if d.length() > host._move_r:
			d = d.normalized() * host._move_r
		host._move_knob = host._move_origin + d
		Touch.set_move(d / host._move_r)
		return
	if idx == host._pan_i:
		MapAct.pan_by(dungeon(), pos - host._pan_at)
		host._pan_at = pos
		return
	if host._free.has(idx):
		host._free[idx] = pos
	if host._pinch_a >= 0:
		if idx == host._pinch_a or idx == host._pinch_b:
			tick_pinch(host)
		return
	if not host._park.has(idx):
		return
	var origin: Vector2 = host._park[idx]
	var slop := maxf(12.0, Touch.dead * host._move_r)
	if pos.distance_to(origin) < slop:
		return
	if can_pan(host) and host._pan_i < 0:
		host._free.erase(idx)
		host._park.erase(idx)
		host._pan_i = idx
		host._pan_at = pos
		return
	if in_move_zone(host, origin) and host._move_i < 0:
		claim_move(host, idx, origin, pos)

static func up(host: CanvasLayer, idx: int) -> void:
	host._free.erase(idx)
	host._park.erase(idx)
	if host._btn_i.has(idx):
		var action := str(host._btn_i[idx])
		host._btn_i.erase(idx)
		if action == "attack":
			Touch.attack_release(now())
		else:
			Touch.set_held(action, false)
		return
	if idx == host._move_i:
		host._move_i = -1
		host._move_live = false
		Touch.move_live = false
		Touch.set_move(Vector2.ZERO)
		return
	if idx == host._pan_i:
		host._pan_i = -1
		return
	if idx == host._pinch_a or idx == host._pinch_b:
		host._pinch_a = -1
		host._pinch_b = -1
		host._pinch_dist = 0.0

static func claim_move(host: CanvasLayer, idx: int, origin: Vector2, pos: Vector2) -> void:
	host._free.erase(idx)
	host._park.erase(idx)
	host._move_i = idx
	host._move_origin = origin
	var d: Vector2 = pos - origin
	if d.length() > host._move_r:
		d = d.normalized() * host._move_r
	host._move_knob = origin + d
	host._move_live = true
	Touch.move_live = true
	Touch.set_move(d / host._move_r)

static func begin_pinch(host: CanvasLayer) -> void:
	var keys: Array = host._free.keys()
	if keys.size() < 2:
		return
	host._pinch_a = int(keys[0])
	host._pinch_b = int(keys[1])
	tick_pinch(host, false)

static func tick_pinch(host: CanvasLayer, apply := true) -> void:
	if not host._free.has(host._pinch_a) or not host._free.has(host._pinch_b):
		return
	var a: Vector2 = host._free[host._pinch_a]
	var b: Vector2 = host._free[host._pinch_b]
	var dist := a.distance_to(b)
	var mid := (a + b) * 0.5
	if apply and host._pinch_dist > 8.0 and dist > 8.0:
		Look.pinch(dist / host._pinch_dist, mid)
	host._pinch_dist = dist
	host._pinch_mid = mid

static func can_pan(host: CanvasLayer) -> bool:
	if host._move_live or host._pinch_a >= 0:
		return false
	var map_host := dungeon()
	return MapAct.is_open(map_host) and float(map_host.get_meta("map_zoom", 1.0)) > 1.001

static func in_move_zone(host: CanvasLayer, pos: Vector2) -> bool:
	var vp := host.get_viewport().get_visible_rect().size
	return pos.x <= vp.x * 0.48 and pos.y >= vp.y * 0.22

static func dungeon() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var tree := loop as SceneTree
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene == null:
		return null
	if str(scene.scene_file_path).ends_with("dungeon.tscn"):
		return scene
	return null

static func release_all(host: CanvasLayer) -> void:
	host._move_i = -1
	host._btn_i.clear()
	host._move_live = false
	host._pinch_a = -1
	host._pinch_b = -1
	host._pinch_dist = 0.0
	host._pan_i = -1
	host._free.clear()
	host._park.clear()
	Touch.move_live = false
	Touch.set_move(Vector2.ZERO)
	Touch.set_aim(Vector2.ZERO)
	for action in Touch.ACTIONS:
		if action != "attack":
			Touch.set_held(action, false)

static func now() -> float:
	return Time.get_ticks_msec() * 0.001