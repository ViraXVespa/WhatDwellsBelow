extends RefCounted

## Map marker add/remove checks (dungeon-map-marks flow; target "script:debug/map_marks_check").
## .stage lays a gold coin, a blue gear drop, a stash chest and a pot beside the player through the real setup paths.
## .listed: "" when map_marks lists each at its spot. .collect takes the coin and the gear, opens the chest and
## breaks the pot (real interact / hit paths); after a wait .gone: "" when none of the four is listed.
## .in_range: "" when a frozen enemy shows just inside map_enemy_range and drops out just past it.
## .plant_range sets MapMarks.plant_no_range (the old show-everything path): .in_range must then fail ("caught").
## .views: "" when the HUD minimap and the full map rect each carry a MapMarks overlay.

const Marks := preload("res://scripts/world/dungeon/map_marks.gd")
const V := preload("res://scripts/world/dungeon/map_marks_view.gd")

static var _staged: Array = []

static func _player() -> Node3D:
	return (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player") as Node3D

static func _host() -> Node:
	var n: Node = _player()
	while n != null and n.get("visited") == null:
		n = n.get_parent()
	return n

static func _has(list: Array, at: Vector2, kind: int, tol: float = 0.4) -> bool:
	for e: Variant in list:
		if int(e[1]) == kind and (e[0] as Vector2).distance_to(at) <= tol:
			return true
	return false

var stage: String:
	get:
		var host: Node = _host()
		var pl: Node3D = _player()
		if host == null or pl == null:
			return "no host"
		var o: Vector3 = pl.global_position
		var gold: Node3D = load("res://scripts/world/pickup.gd").new()
		host.add_child(gold)
		gold.setup("gold", o + Vector3(1.5, 0.0, 0.0), 3)
		gold.set("life", 0.0)
		var gear: Node3D = load("res://scripts/world/pickup.gd").new()
		host.add_child(gear)
		gear.setup_item(App.prog.make_armor("head", "blue"), o + Vector3(-1.5, 0.0, 0.0))
		var chest: Node3D = load("res://scripts/world/interact.gd").new()
		chest.setup("base_chest", o + Vector3(0.0, 0.0, 2.0))
		host.add_child(chest)
		var pot: Node3D = load("res://scripts/world/breakable.gd").new()
		pot.setup("pot", o + Vector3(0.0, 0.0, -2.0))
		host.add_child(pot)
		_staged = [[gold, V.GOLD], [gear, V.ITEM_BLUE], [chest, V.CHEST], [pot, V.POT]]
		return "ok"

static func _at(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)

var listed: String:
	get:
		var list: Array = Marks.refresh(_host())
		var miss: PackedStringArray = []
		for s: Array in _staged:
			if not _has(list, _at(s[0]), int(s[1])):
				miss.append(str(s[1]))
		return "" if not _staged.is_empty() and miss.is_empty() else "missing kinds " + ",".join(miss)

var collect: String:
	get:
		var pl: Node3D = _player()
		_staged[0][0].call("_take", pl)
		_staged[1][0].call("_take", pl)
		_staged[2][0].call("interact", pl)
		_staged[3][0].call("take_hit", 10.0, Vector2.ZERO, false)
		for s: Array in _staged:
			s.append(_at(s[0]))
		return "ok"

var gone: String:
	get:
		var list: Array = Marks.refresh(_host())
		var left: PackedStringArray = []
		for s: Array in _staged:
			if _has(list, s[2], int(s[1])):
				left.append(str(s[1]))
		return "" if left.is_empty() else "still listed kinds " + ",".join(left)

var in_range: String:
	get:
		return _range_fault()

var plant_range: String:
	get:
		Marks.plant_no_range = true
		var r: String = _range_fault()
		Marks.plant_no_range = false
		return "caught" if r != "" else "missed"

static func _range_fault() -> String:
	var host: Node = _host()
	var pl: Node3D = _player()
	var e: Node3D = null
	for n: Node in pl.get_tree().get_nodes_in_group("enemies"):
		if n is Node3D and n.get("dead") != true and n.get("is_boss") != true:
			e = n as Node3D
			break
	if e == null:
		return "no enemy"
	var keep: Vector3 = e.global_position
	var rng: float = float(App.bal.map_enemy_range)
	var out := ""
	e.global_position = pl.global_position + Vector3(rng - 2.0, 0.0, 0.0)
	if not _has(Marks.refresh(host), _at(e), V.ENEMY, 0.6) and not _has(Marks.refresh(host), _at(e), V.ELITE, 0.6):
		out = "near enemy not listed"
	e.global_position = pl.global_position + Vector3(rng + 4.0, 0.0, 0.0)
	for e2: Variant in Marks.refresh(host):
		if (e2[0] as Vector2).distance_to(_at(e)) <= 0.6:
			out = "far enemy listed"
	e.global_position = keep
	Marks.refresh(host)
	return out

var views: String:
	get:
		var host: Node = _host()
		var hud: Node = host.get("hud")
		var mini: Node = hud.get("mini_map") if hud != null else null
		var full: Node = host.get("map_rect")
		if mini == null or mini.get_node_or_null("MapMarks") == null:
			return "minimap has no overlay"
		if full == null or full.get_node_or_null("MapMarks") == null:
			return "full map has no overlay"
		return ""

## .show_enemy (shot only): parks the first live non-boss enemy 4 cells inside map_enemy_range, north-east of the player.
var show_enemy: String:
	get:
		var pl: Node3D = _player()
		var rng: float = float(App.bal.map_enemy_range) - 4.0
		for n: Node in pl.get_tree().get_nodes_in_group("enemies"):
			if n is Node3D and n.get("dead") != true and n.get("is_boss") != true:
				(n as Node3D).global_position = pl.global_position + Vector3(rng * 0.7, 0.0, -rng * 0.7)
				Marks.refresh(_host())
				return "ok"
		return "no enemy"
