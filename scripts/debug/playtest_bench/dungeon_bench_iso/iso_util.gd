extends Object

## Split from dungeon_bench_iso.gd: _kinds, _tag, _child_covered....

static func _kinds() -> PackedStringArray:
	return PackedStringArray([
		"base", "floor", "walls", "sprites", "props", "lights", "hud", "bare",
		"noenv", "linear", "rest", "empty", "empty1", "empty05", "base2",
	])

static func _tag(n: Node) -> String:
	var node_name: String = str(n.name)
	if node_name == "Floors":
		return "floor"
	if node_name == "WallRibbons":
		return "walls"
	if n is MultiMeshInstance3D:
		return "floor"
	if n is Sprite3D:
		return "sprites"
	if n is Light3D:
		return "lights"
	if n is CanvasLayer:
		return "hud"
	if n is MeshInstance3D:
		return "props"
	return ""

static func _child_covered(n: Node, tag: String, under: bool) -> bool:
	if tag != "":
		return true
	if under:
		return true
	if n is Node3D and not (n as Node3D).visible:
		return true
	if n is CanvasItem and not (n as CanvasItem).visible:
		return true
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return true
	return false

static func _mid(vals: Array[float]) -> float:
	if vals.is_empty():
		return 0.0
	var ordered: Array[float] = vals.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.5))
	return ordered[at]

static func _p95(host: Node) -> float:
	if host._iso_dts.is_empty():
		return 0.0
	var ordered: Array[float] = host._iso_dts.duplicate()
	ordered.sort()
	var at: int = int(round(float(ordered.size() - 1) * 0.95))
	return ordered[at]

static func _root_vp(host: Node) -> Viewport:
	var tree: SceneTree = host.get_tree()
	if tree != null and tree.root != null:
		return tree.root
	return host.get_viewport()

static func _empty_kind(kind: String) -> bool:
	return kind == "empty" or kind == "empty1" or kind == "empty05"

static func _bare_kind(kind: String) -> bool:
	return kind == "bare" or kind == "noenv" or kind == "linear" or kind == "rest" or _empty_kind(kind)

static func _hide(host: Node, tag: String) -> void:
	var i: int = 0
	while i < host._iso_all.size():
		if tag == "bare" or host._iso_tag[i] == tag:
			var n: Node = host._iso_all[i]
			if n is Node3D:
				(n as Node3D).visible = false
			elif n is CanvasLayer:
				(n as CanvasLayer).visible = false
		i += 1
