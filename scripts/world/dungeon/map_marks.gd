extends Object

## Live map markers over the minimap and the full map: enemies near the player, drops, chests, pots, extraction
## gates and other interactables. The list is rebuilt from node groups every TICK s from the floor tick (never per
## frame) and views redraw only when the list or their region changes.
## Non-enemy marks need a revealed cell and drop out when the node is freed, used, opened or broken.
## Enemies show only within App.bal.map_enemy_range cells of the player (revealed or not); bosses and named are distinct.

const Gen := preload("res://scripts/dungeon/gen.gd")
const ViewS := preload("res://scripts/world/dungeon/map_marks_view.gd")
const TICK := 0.25
const SNAP := Vector2(0.25, 0.25)

## Smoke plant (map_marks_check): true lists every enemy whatever the range; the range check must catch it.
static var plant_no_range := false

static func tick(host: Node, delta: float) -> void:
	var t: float = float(host.get_meta("map_mark_t", 0.0)) + delta
	host.set_meta("map_mark_t", t if t < TICK else 0.0)
	if t >= TICK:
		refresh(host)

static func refresh(host: Node) -> Array:
	var list: Array = collect(host)
	if list != host.get_meta("map_mark_list", []):
		host.set_meta("map_mark_list", list)
		for v: Control in _views(host):
			v.queue_redraw()
	return list

## One overlay per map rect, made on first bind. Called from minimap_view.sync_views and minimap.make_map.
static func bind(host: Node, rect: Control, region: Rect2) -> void:
	if rect == null:
		return
	var v: Control = rect.get_node_or_null("MapMarks") as Control
	if v == null:
		v = ViewS.new()
		v.name = "MapMarks"
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.clip_contents = true
		rect.add_child(v)
		var views: Array = _views(host)
		views.append(v)
		host.set_meta("map_mark_views", views)
	v.set("host", host)
	if v.get("region") != region:
		v.set("region", region)
		v.queue_redraw()

static func _views(host: Node) -> Array:
	var keep: Array = []
	for v: Variant in host.get_meta("map_mark_views", []):
		if is_instance_valid(v):
			keep.append(v)
	host.set_meta("map_mark_views", keep)
	return keep

## [[Vector2 world xz, kind], ...]: non-enemy marks first so enemies draw on top.
static func collect(host: Node) -> Array:
	var out: Array = []
	var tree: SceneTree = host.get_tree()
	if tree == null or host.get("data") == null or host.get("visited") == null:
		return out
	for n: Node in tree.get_nodes_in_group("interact"):
		_add(host, out, n, _interact_kind(n))
	for n: Node in tree.get_nodes_in_group("breakables"):
		_add(host, out, n, -1 if str(n.get("kind")) == "crack" else ViewS.POT)
	for n: Node in tree.get_nodes_in_group("pickups"):
		_add(host, out, n, _pickup_kind(n))
	var pl: Node3D = host.get("player") as Node3D
	if pl == null:
		return out
	var pc := Vector2(pl.global_position.x, pl.global_position.z)
	var rng: float = float(App.bal.map_enemy_range)
	for n: Node in tree.get_nodes_in_group("enemies"):
		if not (n is Node3D) or n.get("dead") == true or n.is_queued_for_deletion():
			continue
		var p: Vector3 = (n as Node3D).global_position
		var at := Vector2(p.x, p.z)
		if at.distance_to(pc) > rng and not plant_no_range:
			continue
		var k: int = ViewS.ENEMY
		if n.get("is_boss") == true:
			k = ViewS.BOSS
		elif n.get("is_named") == true:
			k = ViewS.ELITE
		out.append([at.snapped(SNAP), k])
	return out

static func _add(host: Node, out: Array, n: Node, kind: int) -> void:
	if kind < 0 or not (n is Node3D) or n.is_queued_for_deletion():
		return
	var p: Vector3 = (n as Node3D).global_position
	var x: int = floori(p.x)
	var y: int = floori(p.z)
	if x < 0 or y < 0 or x >= int(host.data.w) or y >= int(host.data.h):
		return
	if host.visited[Gen.idx(x, y, int(host.data.w))] == 0:
		return
	out.append([Vector2(p.x, p.z).snapped(SNAP), kind])

static func _interact_kind(n: Node) -> int:
	if n.get("hidden") == true:
		return -1
	var k: String = str(n.get("kind"))
	var spent: bool = n.get("used") == true
	if k == "extract_gate" or k.begins_with("clerk"):
		return -1 if spent else ViewS.GATE
	if k.ends_with("chest"):
		return -1 if spent else ViewS.CHEST
	if k == "shrine":
		return -1 if spent else ViewS.SHRINE
	if k == "campfire":
		return -1 if spent else ViewS.CAMPFIRE
	if k == "mine" or k == "wood":
		if int(n.get("hits")) <= 0:
			return -1
		return ViewS.ORE if k == "mine" else ViewS.WOOD
	var fixed: Dictionary = {"shop": ViewS.SHOP, "quest_item": ViewS.QUEST, "lever": ViewS.LEVER}
	return int(fixed.get(k, -1))

static func _pickup_kind(n: Node) -> int:
	var k: String = str(n.get("kind"))
	if k == "item":
		var r: String = str((n.get("item") as Dictionary).get("rarity", "white"))
		return {"blue": ViewS.ITEM_BLUE, "green": ViewS.ITEM_GREEN}.get(r, ViewS.ITEM)
	return int({"gold": ViewS.GOLD, "hp": ViewS.HP, "mana": ViewS.MANA}.get(k, -1))
