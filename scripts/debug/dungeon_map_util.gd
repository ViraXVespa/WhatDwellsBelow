extends Object

const Cells := preload("res://scripts/world/dungeon_cells.gd")

static func _out(lines: Array[String], text: String) -> void:
	lines.append(text)
	printerr("MAP: " + text)


static func _fmt(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _in_room(r: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= int(r.x) and cell.y >= int(r.y) and cell.x < int(r.x) + int(r.w) and cell.y < int(r.y) + int(r.h)


static func _kind_of(n: Node) -> String:
	if n.is_in_group("boss"):
		return "boss_enemy"
	if n.is_in_group("floor_crystals"):
		return "crystal"
	if n.is_in_group("boss_door"):
		return "boss_door"
	var k: Variant = n.get("kind")
	if k != null and str(k) != "":
		return str(k)
	return n.get_class()


static func _cell_of(n: Node) -> Vector2i:
	var cc: Variant = n.get("crystal_cell")
	if cc is Vector2i:
		return cc
	return Cells.world_cell(n.global_position)


static func _mark(overlays: Dictionary, cell: Vector2i, kind: String) -> void:
	if cell.x < 0 or cell.y < 0:
		return
	var cur: String = str(overlays.get(cell, ""))
	if cur == "" or _rank(kind) >= _rank(cur):
		overlays[cell] = kind


static func _rank(kind: String) -> int:
	match kind:
		"spawn":
			return 100
		"boss", "boss_enemy":
			return 95
		"stairs":
			return 90
		"boss_door":
			return 85
		"extract_gate":
			return 80
		"crystal":
			return 75
		"shop":
			return 70
		"gate":
			return 68
		"puzzle":
			return 65
		"chest", "base_chest", "puzzle_chest":
			return 60
		"shrine", "campfire":
			return 50
		"mine", "wood", "pot", "break", "barrel", "crack":
			return 40
		"lever", "plate", "quest_item":
			return 35
		"named":
			return 30
		"enemy_job":
			return 20
		"ambush":
			return 10
		_:
			return 5


static func _glyph(kind: String) -> String:
	match kind:
		"spawn":
			return "S"
		"boss", "boss_enemy":
			return "B"
		"boss_door":
			return "D"
		"stairs":
			return "T"
		"crystal":
			return "C"
		"extract_gate":
			return "G"
		"shop":
			return "$"
		"puzzle":
			return "P"
		"gate":
			return "U"
		"chest", "base_chest", "puzzle_chest":
			return "X"
		"mine":
			return "M"
		"wood":
			return "W"
		"pot", "break", "barrel":
			return "K"
		"crack":
			return "R"
		"campfire":
			return "F"
		"shrine":
			return "H"
		"lever", "plate":
			return "L"
		"ambush":
			return "A"
		"enemy_job":
			return "E"
		"named":
			return "N"
		"quest_item":
			return "Q"
		_:
			return "?"


static func _tally_objs(objs: Array) -> Dictionary:
	var t: Dictionary = {}
	for raw: Variant in objs:
		var k: String = str(raw.get("kind", ""))
		t[k] = int(t.get(k, 0)) + 1
	return t


static func _cells_of(objs: Array, kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for raw: Variant in objs:
		if str(raw.get("kind", "")) == kind:
			out.append(Vector2i(raw.get("cell", Vector2i.ZERO)))
	return out


static func _min_pair_sep(cells: Array[Vector2i]) -> int:
	if cells.size() < 2:
		return 1 << 30
	var best: int = 1 << 30
	for i: int in cells.size():
		for j: int in range(i + 1, cells.size()):
			var d: int = Cells.cell_manhattan(cells[i], cells[j])
			if d < best:
				best = d
	return best


static func _crystal_buckets(rooms: Array, spawn: Vector2i, crystals: Array[Vector2i]) -> Dictionary:
	var entrance_n: int = 0
	var extra_n: int = 0
	var deadend_n: int = 0
	for c: Vector2i in crystals:
		if Cells.cell_manhattan(c, spawn) <= 1:
			entrance_n += 1
			continue
		var in_combat: bool = false
		for r: Variant in rooms:
			var k: String = str(r.get("kind", "normal"))
			if k == "spawn" or k == "boss" or k == "extract_gate" or k == "shop" or k == "puzzle" or k == "stash" or k == "vein":
				continue
			if _in_room(r, c):
				in_combat = true
				break
		if in_combat:
			extra_n += 1
		else:
			deadend_n += 1
	return {"entrance": entrance_n, "extra": extra_n, "deadend": deadend_n}


static func _spec(lines: Array[String], key: String, ok: bool, detail: String) -> int:
	_out(lines, "spec %s ok=%s %s" % [key, str(ok).to_lower(), detail])
	if ok:
		return 0
	return 1
