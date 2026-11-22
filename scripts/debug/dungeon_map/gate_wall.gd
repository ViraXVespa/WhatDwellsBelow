extends Object

## gate_top_wall map spec: every Extraction Gate hangs on a top (north) wall face.
## The 3 cells behind the gate are wall, the 3 in front are walkable floor,
## and the gate sits on the wall face line (no side wall, no free-standing gate).

const Gen := preload("res://scripts/dungeon/gen.gd")
const Cells := preload("res://scripts/world/dungeon/dungeon_cells.gd")
const Util := preload("res://scripts/debug/dungeon_map/map_util.gd")

static func _wall(data: Dictionary, c: Vector2i) -> bool:
	var w: int = int(data.w)
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= int(data.h):
		return true
	return data.grid[Gen.idx(c.x, c.y, w)] == Gen.WALL

## "" when the gate at world position p is on a top wall, else the reason.
static func why_bad(host: Node, data: Dictionary, p: Vector3) -> String:
	var front := Vector2i(int(floor(p.x)), int(floor(p.z)))
	var off: float = p.z - floor(p.z)
	if off > 0.2:
		return "off_face z=%.2f" % p.z
	if absf(p.x - floor(p.x) - 0.5) > 0.05:
		return "off_cell x=%.2f" % p.x
	for dx: int in range(-1, 2):
		if not _wall(data, Vector2i(front.x + dx, front.y - 1)):
			return "no_back_wall dx=%d" % dx
		if not Cells.is_floor_cell(host, Vector2i(front.x + dx, front.y)):
			return "front_blocked dx=%d" % dx
	return ""

static func emit(lines: Array[String], host: Node, data: Dictionary) -> int:
	var bad: Array[String] = []
	var n: int = 0
	for g: Node in host.get_tree().get_nodes_in_group("interact"):
		if str(g.get("kind")) != "extract_gate" or not (g is Node3D):
			continue
		n += 1
		var p: Vector3 = (g as Node3D).position
		var why: String = why_bad(host, data, p)
		if why != "":
			bad.append("%s:%s" % [Util._fmt(Vector2i(int(floor(p.x)), int(floor(p.z)))), why])
	return Util._spec(lines, "gate_top_wall", n > 0 and bad.is_empty(), "n=%d bad=%d %s" % [n, bad.size(), " ".join(bad)])
