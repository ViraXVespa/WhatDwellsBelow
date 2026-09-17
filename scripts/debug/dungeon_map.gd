extends Object

## Dungeon generation map dump. Flag: --wdb-dungeon-map-smoke
## Optional: --wdb-dungeon-map-seed=42 --wdb-dungeon-map-floor=1 --wdb-dungeon-map-scale=8
## Lines: MAP: key=value  (and MAP: ascii= rows). Not a numbered phase.

const FLAG := "--wdb-dungeon-map-smoke"
const Cells := preload("res://scripts/world/dungeon_cells.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")

static var _cached := -1


static func _flag_on() -> bool:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return FLAG in user
	return FLAG in OS.get_cmdline_args()


static func active() -> bool:
	if _cached < 0:
		_cached = 1 if _flag_on() else 0
	return _cached == 1


static func _args() -> PackedStringArray:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return user
	return OS.get_cmdline_args()


static func _arg_int(key: String, fallback: int) -> int:
	var prefix: String = key + "="
	for a: String in _args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return int(s.substr(prefix.length()))
	return fallback


static func run_seed() -> int:
	var n: int = _arg_int("--wdb-dungeon-map-seed", 42)
	if n == 0:
		return 1
	return n


static func floor_n() -> int:
	return maxi(1, _arg_int("--wdb-dungeon-map-floor", 1))


static func ascii_scale() -> int:
	return clampi(_arg_int("--wdb-dungeon-map-scale", 8), 4, 16)


static func dump_floor(host: Node) -> void:
	var lines: Array[String] = []
	var data: Dictionary = host.get("data")
	if data.is_empty() or not bool(data.get("ok", false)):
		_out(lines, "ok=false reason=no_data")
		_finish(lines, false)
		return
	var grid_w: int = int(data.get("w", 0))
	var grid_h: int = int(data.get("h", 0))
	var rooms: Array = data.get("rooms", []) as Array
	var spawn: Vector2i = Vector2i(data.get("spawn", Vector2i.ZERO))
	var stairs: Vector2i = Vector2i(data.get("stairs", Vector2i.ZERO))
	var door: Vector2i = Vector2i(data.get("door", Vector2i.ZERO))
	var boss: Vector2i = Vector2i(data.get("boss", Vector2i.ZERO))
	_out(lines, "floor=%d seed=%d w=%d h=%d rooms=%d ok=true" % [App.floor_n, App.run_seed, grid_w, grid_h, rooms.size()])
	_out(lines, "role=%s gate_master=%s cycle=%s" % [str(data.get("boss_title", "")), str(data.get("gate_master", false)), str(data.get("cycle", 0))])
	_out(lines, "spawn=%s stairs=%s door=%s boss=%s" % [_fmt(spawn), _fmt(stairs), _fmt(door), _fmt(boss)])
	_out(lines, "tunables gen_w=%s gen_h=%s gen_rooms=%s extra_loops=%s max_clerks=%s crystal_min_sep=%s crystal_extra_max=%s ambush_cap=%s" % [str(App.bal.get("gen_w")), str(App.bal.get("gen_h")), str(App.bal.get("gen_rooms")), str(App.bal.get("gen_extra_loops")), str(App.bal.get("max_clerks")), str(App.bal.get("crystal_min_sep")), str(App.bal.get("crystal_extra_max")), str(App.bal.get("ambush_cap"))])
	_emit_kinds(lines, rooms)
	_emit_rooms(lines, rooms)
	var overlays: Dictionary = {}
	var objs: Array = _collect(host, data, overlays)
	_emit_objs(lines, objs)
	_emit_jobs(lines, host)
	_emit_counts(lines, host, data, objs)
	var spec_fail: int = _emit_spec(lines, host, data, objs)
	_emit_ascii(lines, data, overlays)
	_out(lines, "spec_fail=%d" % spec_fail)
	_out(lines, "ok=true")
	_write_dump(lines)
	_finish(lines, true)


static func _out(lines: Array[String], text: String) -> void:
	lines.append(text)
	printerr("MAP: " + text)


static func _fmt(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


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


static func _in_room(r: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= int(r.x) and cell.y >= int(r.y) and cell.x < int(r.x) + int(r.w) and cell.y < int(r.y) + int(r.h)


static func _mark(overlays: Dictionary, cell: Vector2i, kind: String) -> void:
	if cell.x < 0 or cell.y < 0:
		return
	var cur: String = str(overlays.get(cell, ""))
	if cur == "" or _rank(kind) >= _rank(cur):
		overlays[cell] = kind


static func _collect(host: Node, data: Dictionary, overlays: Dictionary) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	_mark(overlays, Vector2i(data.get("spawn", Vector2i.ZERO)), "spawn")
	_mark(overlays, Vector2i(data.get("stairs", Vector2i.ZERO)), "stairs")
	_mark(overlays, Vector2i(data.get("door", Vector2i.ZERO)), "boss_door")
	_mark(overlays, Vector2i(data.get("boss", Vector2i.ZERO)), "boss")
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
	var cell: Vector2i = _cell_of(n)
	var kind: String = _kind_of(n)
	var key: String = "%s:%s" % [kind, _fmt(cell)]
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
	_mark(overlays, cell, kind)


static func _take_job_overlay(overlays: Dictionary, job: Dictionary) -> void:
	var cell: Vector2i = Vector2i(job.get("cell", Vector2i.ZERO))
	var kind: String = str(job.get("kind", "room"))
	if bool(job.get("named", false)):
		_mark(overlays, cell, "named")
	elif kind == "ambush":
		_mark(overlays, cell, "ambush")
	else:
		_mark(overlays, cell, "enemy_job")


static func _emit_kinds(lines: Array[String], rooms: Array) -> void:
	var tallies: Dictionary = {}
	for r: Variant in rooms:
		var k: String = str(r.get("kind", "normal"))
		tallies[k] = int(tallies.get(k, 0)) + 1
	var bits: PackedStringArray = PackedStringArray()
	var keys: Array = tallies.keys()
	keys.sort()
	for k: Variant in keys:
		bits.append("%s=%d" % [str(k), int(tallies[k])])
	_out(lines, "kinds " + " ".join(bits))


static func _emit_rooms(lines: Array[String], rooms: Array) -> void:
	var i: int = 0
	for r: Variant in rooms:
		var vein: String = str(r.get("vein", ""))
		var extra: String = ""
		if vein != "":
			extra = " vein=" + vein
		_out(lines, "room i=%d kind=%s x=%d y=%d w=%d h=%d c=%s%s" % [i, str(r.get("kind", "normal")), int(r.x), int(r.y), int(r.w), int(r.h), _fmt(Cells.center_room(r)), extra])
		i += 1


static func _emit_objs(lines: Array[String], objs: Array) -> void:
	for raw: Variant in objs:
		var o: Dictionary = raw
		var kind: String = str(o.get("kind", ""))
		var cell: Vector2i = Vector2i(o.get("cell", Vector2i.ZERO))
		var extra: String = ""
		if o.has("cl"):
			extra += " cl=%d gate=%s on=%s" % [int(o.cl), str(o.get("gate", false)), str(o.get("on", false))]
		if o.has("pair"):
			extra += " pair=%s" % str(o.pair)
		if o.has("title"):
			extra += " title=%s" % str(o.title)
		_out(lines, "obj kind=%s cell=%s%s" % [kind, _fmt(cell), extra])


static func _emit_jobs(lines: Array[String], host: Node) -> void:
	var jobs: Array = host.get("spawn_jobs") as Array
	var i: int = 0
	for raw: Variant in jobs:
		if not (raw is Dictionary):
			continue
		var job: Dictionary = raw
		var cell: Vector2i = Vector2i(job.get("cell", Vector2i.ZERO))
		var ids: PackedStringArray = job.get("ids", PackedStringArray()) as PackedStringArray
		var room: Dictionary = job.get("room", {})
		var rk: String = str(room.get("kind", ""))
		_out(lines, "job i=%d kind=%s cell=%s pack=%d state=%s named=%s nname=%s room=%s ids=%s" % [i, str(job.get("kind", "")), _fmt(cell), ids.size(), str(job.get("state", "")), str(job.get("named", false)), str(job.get("nname", "")), rk, ",".join(ids)])
		i += 1


static func _tally_objs(objs: Array) -> Dictionary:
	var t: Dictionary = {}
	for raw: Variant in objs:
		var k: String = str(raw.get("kind", ""))
		t[k] = int(t.get(k, 0)) + 1
	return t


static func _emit_counts(lines: Array[String], host: Node, data: Dictionary, objs: Array) -> void:
	var t: Dictionary = _tally_objs(objs)
	var jobs: Array = host.get("spawn_jobs") as Array
	var ambush_jobs: int = 0
	var room_jobs: int = 0
	var named_jobs: int = 0
	var pack_sum: int = 0
	for raw: Variant in jobs:
		if not (raw is Dictionary):
			continue
		var job: Dictionary = raw
		var ids: PackedStringArray = job.get("ids", PackedStringArray()) as PackedStringArray
		pack_sum += ids.size()
		var k: String = str(job.get("kind", ""))
		if bool(job.get("named", false)):
			named_jobs += 1
		elif k == "ambush":
			ambush_jobs += 1
		else:
			room_jobs += 1
	var floor_cells: int = 0
	var grid: PackedByteArray = data.get("grid", PackedByteArray()) as PackedByteArray
	for i: int in grid.size():
		if int(grid[i]) == Gen.FLOOR:
			floor_cells += 1
	var bits: PackedStringArray = PackedStringArray()
	var keys: Array = t.keys()
	keys.sort()
	for k: Variant in keys:
		bits.append("%s=%d" % [str(k), int(t[k])])
	_out(lines, "counts " + " ".join(bits))
	_out(lines, "jobs total=%d room=%d ambush=%d named=%d pack=%d floor_cells=%d deadends=%d ambush_anchors=%d crystals_data=%d" % [jobs.size(), room_jobs, ambush_jobs, named_jobs, pack_sum, floor_cells, (data.get("deadends", []) as Array).size(), (data.get("ambushes", []) as Array).size(), (data.get("crystals", []) as Array).size()])
	var host_counts: Dictionary = host.get("counts") as Dictionary
	if not host_counts.is_empty():
		var cb: PackedStringArray = PackedStringArray()
		var ck: Array = host_counts.keys()
		ck.sort()
		for k2: Variant in ck:
			cb.append("%s=%s" % [str(k2), str(host_counts[k2])])
		_out(lines, "placed " + " ".join(cb))


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


static func _spec(lines: Array[String], key: String, ok: bool, detail: String) -> int:
	_out(lines, "spec %s ok=%s %s" % [key, str(ok).to_lower(), detail])
	if ok:
		return 0
	return 1


static func _emit_spec(lines: Array[String], host: Node, data: Dictionary, objs: Array) -> int:
	var fail: int = 0
	var rooms: Array = data.get("rooms", []) as Array
	var spawn_n: int = 0
	var boss_n: int = 0
	var gate_rooms: int = 0
	var shop_rooms: int = 0
	var puzzle_rooms: int = 0
	var boss_r: Dictionary = {}
	var spawn_r: Dictionary = {}
	for r: Variant in rooms:
		var k: String = str(r.get("kind", "normal"))
		if k == "spawn":
			spawn_n += 1
			spawn_r = r
		elif k == "boss":
			boss_n += 1
			boss_r = r
		elif k == "extract_gate":
			gate_rooms += 1
		elif k == "shop":
			shop_rooms += 1
		elif k == "puzzle":
			puzzle_rooms += 1
	var want_gates: int = maxi(1, mini(3, int(App.bal.get("max_clerks"))))
	fail += _spec(lines, "rooms_min", rooms.size() >= 6, "n=%d want>=6" % rooms.size())
	fail += _spec(lines, "spawn_room", spawn_n == 1, "n=%d" % spawn_n)
	fail += _spec(lines, "boss_room", boss_n == 1, "n=%d" % boss_n)
	fail += _spec(lines, "gate_rooms", gate_rooms == want_gates, "n=%d want=%d" % [gate_rooms, want_gates])
	fail += _spec(lines, "shop_cap", shop_rooms <= 1, "n=%d want<=1" % shop_rooms)
	fail += _spec(lines, "puzzle_room", puzzle_rooms == 1, "n=%d want=1" % puzzle_rooms)
	var gates: Array[Vector2i] = _cells_of(objs, "extract_gate")
	fail += _spec(lines, "gates_placed", gates.size() == want_gates, "n=%d want=%d" % [gates.size(), want_gates])
	var gate_sep: int = _min_pair_sep(gates)
	fail += _spec(lines, "gate_sep", gates.size() < 2 or gate_sep >= 28, "min=%d want>=28" % gate_sep)
	var crystals: Array[Vector2i] = _cells_of(objs, "crystal")
	var extra_max: int = maxi(1, int(App.bal.get("crystal_extra_max")))
	var spawn: Vector2i = Vector2i(data.get("spawn", Vector2i.ZERO))
	var crystal_n: Dictionary = _crystal_buckets(rooms, spawn, crystals)
	var extra_n: int = int(crystal_n.get("extra", 0))
	var deadend_n: int = int(crystal_n.get("deadend", 0))
	var entrance_n: int = int(crystal_n.get("entrance", 0))
	fail += _spec(lines, "crystal_count", crystals.size() >= 1, "n=%d extra=%d deadend=%d extra_max=%d" % [crystals.size(), extra_n, deadend_n, extra_max])
	fail += _spec(lines, "crystal_extras", extra_n <= extra_max, "extra=%d extra_max=%d" % [extra_n, extra_max])
	var csep: int = maxi(1, int(App.bal.get("crystal_min_sep")))
	var crystal_sep: int = _min_pair_sep(crystals)
	fail += _spec(lines, "crystal_sep", crystals.size() < 2 or crystal_sep >= csep, "min=%d want>=%d" % [crystal_sep, csep])
	fail += _spec(lines, "crystal_entrance", entrance_n >= 1, "n=%d spawn=%s" % [entrance_n, _fmt(spawn)])
	var stairs: Vector2i = Vector2i(data.get("stairs", Vector2i.ZERO))
	var stairs_ok: bool = not boss_r.is_empty() and _in_room(boss_r, stairs)
	fail += _spec(lines, "stairs_in_boss", stairs_ok, "stairs=%s" % _fmt(stairs))
	var boss: Vector2i = Vector2i(data.get("boss", Vector2i.ZERO))
	var need_sep: int = 16
	if not spawn_r.is_empty() and not boss_r.is_empty():
		var mw: int = maxi(int(data.w), int(data.h))
		need_sep = maxi(16, int(float(mw) * 0.5))
	var boss_sep: int = Cells.cell_manhattan(spawn, boss)
	fail += _spec(lines, "boss_sep", boss_sep >= 16, "manhattan=%d min_boss_sep~%d" % [boss_sep, need_sep])
	var safe_hits: int = 0
	var jobs: Array = host.get("spawn_jobs") as Array
	for raw: Variant in jobs:
		if not (raw is Dictionary):
			continue
		var job: Dictionary = raw
		var room: Dictionary = job.get("room", {})
		var rk: String = str(room.get("kind", ""))
		if rk != "" and Gen.is_safe_kind(rk):
			safe_hits += 1
			continue
		var cell: Vector2i = Vector2i(job.get("cell", Vector2i.ZERO))
		for r2: Variant in rooms:
			if Gen.is_safe_kind(str(r2.get("kind", ""))) and _in_room(r2, cell):
				safe_hits += 1
				break
	fail += _spec(lines, "safe_enemy_free", safe_hits == 0, "jobs_in_safe=%d" % safe_hits)
	var ambush_cap: int = maxi(0, int(App.bal.get("ambush_cap")))
	var ambush_n: int = 0
	for raw2: Variant in jobs:
		if raw2 is Dictionary and str(raw2.get("kind", "")) == "ambush":
			ambush_n += 1
	fail += _spec(lines, "ambush_cap", ambush_n <= ambush_cap, "n=%d cap=%d" % [ambush_n, ambush_cap])
	return fail


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


static func _emit_ascii(lines: Array[String], data: Dictionary, overlays: Dictionary) -> void:
	var grid: PackedByteArray = data.get("grid", PackedByteArray()) as PackedByteArray
	var grid_w: int = int(data.get("w", 0))
	var grid_h: int = int(data.get("h", 0))
	var sc: int = ascii_scale()
	var dw: int = int((float(grid_w) + float(sc) - 1.0) / float(sc))
	var dh: int = int((float(grid_h) + float(sc) - 1.0) / float(sc))
	_out(lines, "ascii scale=%d dw=%d dh=%d" % [sc, dw, dh])
	_out(lines, "legend #=wall .=floor S=spawn B=boss D=door T=stairs C=crystal G=extract_gate $=shop P=puzzle U=puzzle_gate X=chest M=mine W=wood K=break/barrel R=crack F=campfire H=shrine L=lever/plate A=ambush E=enemy_job N=named Q=quest")
	for gy: int in dh:
		var row: String = ""
		for gx: int in dw:
			row += _sample(grid, grid_w, grid_h, overlays, gx * sc, gy * sc, sc)
		_out(lines, "ascii=%s" % row)


static func _sample(grid: PackedByteArray, grid_w: int, grid_h: int, overlays: Dictionary, ox: int, oy: int, sc: int) -> String:
	var best_kind: String = ""
	var best_rank: int = -1
	var saw_floor: bool = false
	for y: int in range(oy, oy + sc):
		for x: int in range(ox, ox + sc):
			var cell := Vector2i(x, y)
			if overlays.has(cell):
				var k: String = str(overlays[cell])
				var rnk: int = _rank(k)
				if rnk > best_rank:
					best_rank = rnk
					best_kind = k
			if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
				continue
			if int(grid[Gen.idx(x, y, grid_w)]) == Gen.FLOOR:
				saw_floor = true
	if best_kind != "":
		return _glyph(best_kind)
	if saw_floor:
		return "."
	return "#"


static func _write_dump(lines: Array[String]) -> void:
	var root_path: String = ProjectSettings.globalize_path("res://")
	var dir_path: String = root_path.path_join("_logs").path_join("dungeon-map")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path: String = dir_path.path_join("dump.txt")
	var f: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		printerr("MAP: dump_write=fail")
		return
	for line: String in lines:
		f.store_line(line)
	f.close()
	printerr("MAP: dump=%s" % file_path)


static func _finish(_lines: Array[String], _ok: bool) -> void:
	if App == null:
		return
	App.get_tree().create_timer(0.25).timeout.connect(func(): App.get_tree().quit())
