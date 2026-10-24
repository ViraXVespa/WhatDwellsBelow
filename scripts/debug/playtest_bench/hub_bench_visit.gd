extends Object

## Split from hub_bench.gd: _build_visits, _add_visit, _push_visit....

const End := preload("res://scripts/debug/playtest_bench/hub_bench_end.gd")

static func _build_visits(host: Node) -> void:
	var camp: Node = _camp(host)
	var lay: Node = null
	if camp != null:
		lay = camp.get("_layout") as Node
	if lay == null:
		End._finish(host, "no_layout")
		return
	for stop: Array in [["loadout_crystal", "Crystal"], ["anvil", "Anvil"], ["vendor", "Vendor"], ["quest_board", "Board"]]:
		_add_visit(host, lay, stop[0], stop[1], false)
	var rec: Vector3 = _call_vec(lay, "reception_pos", "")
	_push_visit(host, "receptionist", rec, false)
	_add_visit(host, lay, "dummy", "Dummy", true)

static func _add_visit(host: Node, lay: Node, id: String, spot: String, strike: bool) -> void:
	_push_visit(host, id, _call_vec(lay, "spot_pos", spot), strike)

static func _push_visit(host: Node, id: String, look: Vector3, strike: bool) -> void:
	var at: Vector3 = look
	if strike:
		at += Vector3(1.05, 0.0, 0.0)
	else:
		at += Vector3(0.0, 0.0, 0.8)
	host._visits.append({"id": id, "at": at, "look": look, "strike": strike})

static func _call_vec(lay: Node, method: String, arg: String) -> Vector3:
	var v: Variant = lay.call(method) if arg == "" else lay.call(method, arg)
	if v is Vector3:
		return v as Vector3
	return Vector3.ZERO

static func _camp(host: Node) -> Node:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return null
	var scene: Node = tree.current_scene
	if scene != null and scene.get("_layout") != null:
		return scene
	return null

static func _steer(host: Node, actor: Node3D, at: Vector3, look: Vector3, delta: float) -> void:
	var flat: Vector2 = Vector2(at.x - actor.global_position.x, at.z - actor.global_position.z)
	var dist: float = flat.length()
	var dir: Vector2 = Vector2.ZERO
	if dist > 0.12:
		dir = flat / dist
	if actor.global_position.distance_to(host._stuck_from) < 0.04:
		host._stuck_t += delta
	else:
		host._stuck_t = 0.0
		host._stuck_from = actor.global_position
	if host._stuck_t > 0.7:
		host._bias_t = 0.45
		host._stuck_t = 0.0
	if host._bias_t > 0.0 and dir.length() > 0.1:
		host._bias_t -= delta
		dir = Vector2(-dir.y, dir.x)
	App.playtest.move = dir if dist > 0.45 else Vector2.ZERO
	_aim_at(actor, look)

static func _aim_at(actor: Node3D, look: Vector3) -> void:
	var d: Vector2 = Vector2(look.x - actor.global_position.x, look.z - actor.global_position.z)
	if d.length() > 0.05:
		App.playtest.aim = d.normalized()

static func _xz(at: Vector3, look: Vector3) -> float:
	return Vector2(look.x - at.x, look.z - at.z).length()

static func _close_ui(host: Node) -> void:
	var camp: Node = _camp(host)
	var ui_v: Variant = camp.get("ui") if camp != null else null
	if ui_v is Node and (ui_v as Node).has_method("close_ui") and bool((ui_v as Node).get("open")):
		(ui_v as Node).call("close_ui")
	App.ui_open = false
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.paused = false
