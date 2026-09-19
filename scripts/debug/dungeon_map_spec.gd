extends Object

const Cells := preload("res://scripts/world/dungeon_cells.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const Util := preload("res://scripts/debug/dungeon_map_util.gd")

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
	fail += Util._spec(lines, "rooms_min", rooms.size() >= 6, "n=%d want>=6" % rooms.size())
	fail += Util._spec(lines, "spawn_room", spawn_n == 1, "n=%d" % spawn_n)
	fail += Util._spec(lines, "boss_room", boss_n == 1, "n=%d" % boss_n)
	fail += Util._spec(lines, "gate_rooms", gate_rooms == want_gates, "n=%d want=%d" % [gate_rooms, want_gates])
	fail += Util._spec(lines, "shop_cap", shop_rooms <= 1, "n=%d want<=1" % shop_rooms)
	fail += Util._spec(lines, "puzzle_room", puzzle_rooms == 1, "n=%d want=1" % puzzle_rooms)
	var gates: Array[Vector2i] = Util._cells_of(objs, "extract_gate")
	fail += Util._spec(lines, "gates_placed", gates.size() == want_gates, "n=%d want=%d" % [gates.size(), want_gates])
	var gate_sep: int = Util._min_pair_sep(gates)
	fail += Util._spec(lines, "gate_sep", gates.size() < 2 or gate_sep >= 28, "min=%d want>=28" % gate_sep)
	var crystals: Array[Vector2i] = Util._cells_of(objs, "crystal")
	var extra_max: int = maxi(1, int(App.bal.get("crystal_extra_max")))
	var spawn: Vector2i = Vector2i(data.get("spawn", Vector2i.ZERO))
	var crystal_n: Dictionary = Util._crystal_buckets(rooms, spawn, crystals)
	var extra_n: int = int(crystal_n.get("extra", 0))
	var deadend_n: int = int(crystal_n.get("deadend", 0))
	var entrance_n: int = int(crystal_n.get("entrance", 0))
	fail += Util._spec(lines, "crystal_count", crystals.size() >= 1, "n=%d extra=%d deadend=%d extra_max=%d" % [crystals.size(), extra_n, deadend_n, extra_max])
	fail += Util._spec(lines, "crystal_extras", extra_n <= extra_max, "extra=%d extra_max=%d" % [extra_n, extra_max])
	var csep: int = maxi(1, int(App.bal.get("crystal_min_sep")))
	var crystal_sep: int = Util._min_pair_sep(crystals)
	fail += Util._spec(lines, "crystal_sep", crystals.size() < 2 or crystal_sep >= csep, "min=%d want>=%d" % [crystal_sep, csep])
	fail += Util._spec(lines, "crystal_entrance", entrance_n >= 1, "n=%d spawn=%s" % [entrance_n, Util._fmt(spawn)])
	var stairs: Vector2i = Vector2i(data.get("stairs", Vector2i.ZERO))
	var stairs_ok: bool = not boss_r.is_empty() and Util._in_room(boss_r, stairs)
	fail += Util._spec(lines, "stairs_in_boss", stairs_ok, "stairs=%s" % Util._fmt(stairs))
	var boss: Vector2i = Vector2i(data.get("boss", Vector2i.ZERO))
	var need_sep: int = 16
	if not spawn_r.is_empty() and not boss_r.is_empty():
		var mw: int = maxi(int(data.w), int(data.h))
		need_sep = maxi(16, int(float(mw) * 0.5))
	var boss_sep: int = Cells.cell_manhattan(spawn, boss)
	fail += Util._spec(lines, "boss_sep", boss_sep >= 16, "manhattan=%d min_boss_sep~%d" % [boss_sep, need_sep])
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
			if Gen.is_safe_kind(str(r2.get("kind", ""))) and Util._in_room(r2, cell):
				safe_hits += 1
				break
	fail += Util._spec(lines, "safe_enemy_free", safe_hits == 0, "jobs_in_safe=%d" % safe_hits)
	var ambush_cap: int = maxi(0, int(App.bal.get("ambush_cap")))
	var ambush_n: int = 0
	for raw2: Variant in jobs:
		if raw2 is Dictionary and str(raw2.get("kind", "")) == "ambush":
			ambush_n += 1
	fail += Util._spec(lines, "ambush_cap", ambush_n <= ambush_cap, "n=%d cap=%d" % [ambush_n, ambush_cap])
	return fail
