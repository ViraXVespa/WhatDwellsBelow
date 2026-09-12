extends Object

const SEE := 36.0
const ROOM := 11.0
const Near := preload("res://scripts/debug/playtest_goals_near.gd")
const Best := preload("res://scripts/debug/playtest_goals_best.gd")


static func world_ui(pt: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var s: Node = tree.current_scene
	if s and s.has_method("world_ui"):
		return s.world_ui()
	return null

static func role_has_cargo(pt: Node, role: String) -> bool:
	if role == "gather":
		return pt._gather_cargo() > 0
	if role == "misc":
		return pt._misc_cargo() > 0
	if role == "patty" or role == "gate":
		return (pt._gather_cargo() + pt._misc_cargo()) > 0
	return false

static func dismiss_world_ui(pt: Node) -> bool:
	return Near.dismiss_world_ui(pt)

static func nearest_visible_threat(pt: Node, p: Node) -> Node:
	return Near.nearest_visible_threat(pt, p)

static func nearest_room_threat(pt: Node, p: Node, radius: float = ROOM) -> Node:
	return Best.nearest_room_threat(pt, p, radius)

static func nearest_foe(pt: Node, p: Node) -> Node:
	var seen: Node = Near.nearest_visible_threat(pt, p)
	if seen:
		return seen
	return Best.nearest_room_threat(pt, p)

static func nearest_hunt(pt: Node, p: Node) -> Node:
	return Near.nearest_hunt(pt, p)

static func nearest_boss(pt: Node, p: Node) -> Node:
	return Best.nearest_boss(pt, p)

static func closest_kind(pt: Node, p: Node, kind: String, radius: float) -> Node:
	return Best.closest_kind(pt, p, kind, radius)

static func away_open(pt: Node, p: Node, node: Node) -> Vector2:
	return Best.away_open(pt, p, node)

static func mail_at(pt: Node, clerk: Node) -> void:
	if clerk == null or pt._is_chest(clerk):
		return
	var role: String = pt._clerk_role(clerk)
	if role == "" or not pt._clerk_accepts(clerk):
		return
	App.note_clerk()
	App.prog.extract_all(role)
	var ui: Node = pt._world_ui()
	if ui and bool(ui.get("open")) and ui.has_method("close_ui"):
		ui.close_ui()

static func clerk_role(n: Node) -> String:
	var k: String = str(n.get("kind"))
	if k == "extract_gate":
		return "gate"
	if k.find("patty") >= 0:
		return "patty"
	if k.find("misc") >= 0:
		return "misc"
	if k.begins_with("clerk"):
		return "gather"
	return ""

static func gather_cargo() -> int:
	var root_n: int = 0
	if App.prog:
		root_n = int(App.prog.root)
	return App.ore + App.wood + root_n

static func misc_cargo() -> int:
	var n: int = App.gold
	if App.prog == null:
		return n
	for it: Variant in App.prog.bag:
		if it is Dictionary and it.get("extract") == true and str(it.get("kind", "")) != "artifact" and str(it.get("kind", "")) != "tool" and it.get("hold") != true:
			n += 1
	return n

static func clerk_accepts(pt: Node, n: Node) -> bool:
	var role: String = pt._clerk_role(n)
	if role == "gather":
		return pt._gather_cargo() > 0
	if role == "misc":
		return pt._misc_cargo() > 0
	if role == "patty" or role == "gate":
		return (pt._gather_cargo() + pt._misc_cargo()) > 0
	return false

static func best_clerk(pt: Node, p: Node) -> Node:
	return Near.best_clerk(pt, p)

static func best_gather(pt: Node, p: Node) -> Node:
	return Near.best_gather(pt, p)

static func best_chest(pt: Node, p: Node) -> Node:
	return Best.best_chest(pt, p)

static func reachable_kind(pt: Node, p: Node, prefix: String) -> Node:
	return Near.reachable_kind(pt, p, prefix)

static func crowd(pt: Node, p: Node) -> int:
	var n_hit: int = 0
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return 0
	for e: Node in tree.get_nodes_in_group("enemies"):
		if not pt._alive_enemy(e) or pt._is_boss(e):
			continue
		if pt._dist(p, e) <= 2.4 and pt._has_los(p, e):
			n_hit += 1
	return n_hit

static func dist(a: Node, b: Node) -> float:
	if a == null or b == null:
		return 999.0
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	return Vector2(pa.x - pb.x, pa.z - pb.z).length()

static func xz_to(a: Node, b: Node) -> Vector2:
	var pa: Vector3 = (a as Node3D).global_position
	var pb: Vector3 = (b as Node3D).global_position
	var v: Vector2 = Vector2(pb.x - pa.x, pb.z - pa.z)
	if v.length() < 0.001:
		return Vector2.DOWN
	return v.normalized()

static func dungeon(pt: Node) -> Node:
	var tree: SceneTree = pt.get_tree()
	if tree == null:
		return null
	var s: Node = tree.current_scene
	if s and s.get("data") != null:
		return s
	return null
