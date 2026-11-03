extends Object

## Split from hitch_log.gd: _hub_ctx, _counted, _mesh_n....

## Mesh and light totals. One walk per bench. A walk on every stall held web at two refreshes.
static var _counted: bool = false
static var _mesh_n: int = 0
static var _light_n: int = 0

static func _hub_ctx(host: Node, row: Dictionary) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var actor: Node = tree.get_first_node_in_group("player")
	if actor is Node3D:
		var at: Vector3 = (actor as Node3D).global_position
		row["px"] = snappedf(at.x, 0.1)
		row["pz"] = snappedf(at.z, 0.1)
		row["cell"] = "%d,%d" % [int(at.x), int(at.z)]
		var loco_i: int = int(actor.get("loc_state"))
		var loco_name: String = "idle"
		if loco_i == 1:
			loco_name = "start"
		elif loco_i == 2:
			loco_name = "loop"
		elif loco_i == 3:
			loco_name = "stop"
		var face: String = str(actor.get("facing_key"))
		row["face"] = face
		row["anim"] = loco_name + "_" + face
	var scn: Node = tree.current_scene
	if scn == null:
		return
	var panels: PackedStringArray = PackedStringArray()
	var ui_v: Variant = scn.get("ui")
	if ui_v is Node and bool((ui_v as Node).get("open")):
		panels.append(str((ui_v as Node).get("mode")))
	if App != null and App.pause_menu != null and bool(App.pause_menu.get("open")):
		panels.append("pause")
	if panels.is_empty() and App != null and App.ui_open:
		panels.append("ui")
	if not panels.is_empty():
		row["ui"] = ",".join(panels)
	var gen: Node = scn.get_node_or_null("Generated")
	row["gen"] = gen.get_child_count() if gen != null else 0
	if not _counted and gen != null:
		_counted = true
		_mesh_n = gen.find_children("*", "MeshInstance3D", true, false).size()
		_light_n = scn.find_children("*", "Light3D", true, false).size()
	row["meshes"] = _mesh_n
	row["lights"] = _light_n

static func _where(host: Node) -> String:
	if App != null and App.in_dungeon:
		return "dungeon"
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return "boot"
	var scn: String = tree.current_scene.name.to_lower()
	if scn.find("title") >= 0 or scn.find("splash") >= 0:
		return "title"
	if scn.find("camp") >= 0 or scn.find("hub") >= 0:
		return "hub"
	return scn

static var _score_where: String = "hub"

static func set_score_where(where_name: String) -> void:
	_score_where = where_name if where_name == "dungeon" else "hub"

static func _loader_up(host: Node) -> bool:
	var loader_v: Variant = host.get("loader")
	if loader_v is Node:
		var loader: Node = loader_v as Node
		if bool(loader.get("open")) or bool(loader.get("visible")):
			return true
	return false

static func _hub_on_screen(host: Node) -> bool:
	return _scene_on_screen(host, "Camp", "camp")

## Dungeon bench: the player can see the dungeon scene and the loader bar is down.
static func _dungeon_on_screen(host: Node) -> bool:
	return _scene_on_screen(host, "Dungeon", "dungeon.tscn")

static func _scene_on_screen(host: Node, scene_name: String, path_frag: String) -> bool:
	if _loader_up(host):
		return false
	var tree: SceneTree = host.get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var scene: Node = tree.current_scene
	return str(scene.name) == scene_name or str(scene.scene_file_path).find(path_frag) >= 0

static func _score_on_screen(host: Node) -> bool:
	if _score_where == "dungeon":
		return _dungeon_on_screen(host)
	return _hub_on_screen(host)

static func _ver_label() -> String:
	var txt: String = FileAccess.get_file_as_string("res://scripts/data/version.json")
	if txt == "":
		return ""
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("label", ""))
	return ""

static func _localhost() -> bool:
	if not OS.has_feature("web"):
		return false
	var host: Variant = JavaScriptBridge.eval("window.location.hostname", true)
	var h: String = str(host)
	return h == "localhost" or h == "127.0.0.1" or h == "[::1]"
