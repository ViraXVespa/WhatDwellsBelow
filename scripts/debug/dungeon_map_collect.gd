extends Object

const Util := preload("res://scripts/debug/dungeon_map_util.gd")

static func _collect(host: Node, data: Dictionary, overlays: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	Util._mark(overlays, Vector2i(data.get("spawn", Vector2i.ZERO)), "spawn")
	Util._mark(overlays, Vector2i(data.get("stairs", Vector2i.ZERO)), "stairs")
	Util._mark(overlays, Vector2i(data.get("door", Vector2i.ZERO)), "boss_door")
	Util._mark(overlays, Vector2i(data.get("boss", Vector2i.ZERO)), "boss")
	var tree: SceneTree = host.get_tree()
	var groups: PackedStringArray = PackedStringArray(["interact", "gates", "breakables", "floor_crystals", "boss_door", "boss", "plates"])
	for g: String in groups:
		for n: Node in tree.get_nodes_in_group(g):
			_take_node(out, seen, overlays, n)
	var jobs: Array = host.get("spawn_jobs") as Array
	for raw: Variant in jobs:
		if raw is Dictionary:
			_take_job_overlay(overlays, raw)
	return out


static func _take_node(out: Array, seen: Dictionary, overlays: Dictionary, n: Node) -> void:
	var cell: Vector2i = Util._cell_of(n)
	var kind: String = Util._kind_of(n)
	var key: String = "%s:%s" % [kind, Util._fmt(cell)]
	if seen.has(key):
		return
	seen[key] = true
	var row: Dictionary = {"kind": kind, "cell": cell}
	if n.is_in_group("floor_crystals"):
		row["cl"] = int(n.get("crystal_cl"))
		row["gate"] = bool(n.get("crystal_gate"))
		row["on"] = bool(n.get("crystal_on"))
	if kind == "gate" or kind == "plate" or kind == "lever":
		row["pair"] = str(n.get("pair"))
	if n.is_in_group("boss"):
		row["title"] = str(n.get("type_id"))
	out.append(row)
	Util._mark(overlays, cell, kind)


static func _take_job_overlay(overlays: Dictionary, job: Dictionary) -> void:
	var cell: Vector2i = Vector2i(job.get("cell", Vector2i.ZERO))
	var kind: String = str(job.get("kind", "room"))
	if bool(job.get("named", false)):
		Util._mark(overlays, cell, "named")
	elif kind == "ambush":
		Util._mark(overlays, cell, "ambush")
	else:
		Util._mark(overlays, cell, "enemy_job")
