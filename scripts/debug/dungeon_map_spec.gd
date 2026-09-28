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
	var spans: Array = data.get("outline_spans", []) as Array
	var solid: PackedByteArray = PackedByteArray()
	var raw_solid: Variant = data.get("solid", PackedByteArray())
	if raw_solid is PackedByteArray:
		solid = raw_solid
	var sw: int = int(data.get("solid_w", 0))
	var sh: int = int(data.get("solid_h", 0))
	var n: int = int(data.get("solid_n", 0))
	var gw: int = int(data.get("w", 0))
	var gh: int = int(data.get("h", 0))
	fail += Util._spec(lines, "spans_present", spans.size() > 0, "n=%d" % spans.size())
	fail += Util._spec(lines, "solid_size", n >= 2 and sw == gw * n and sh == gh * n and solid.size() == sw * sh, "n=%d sw=%d sh=%d want=%dx%d bytes=%d" % [n, sw, sh, gw * n, gh * n, solid.size()])
	var span_hits: int = 0
	var span_miss: int = 0
	for raw_span: Variant in spans:
		if not (raw_span is Dictionary):
			continue
		var sp: Dictionary = raw_span
		var o: Vector2 = Vector2(sp.get("origin", Vector2.ZERO))
		var d: Vector2 = Vector2(sp.get("delta", Vector2.ZERO))
		var slen: float = d.length()
		if slen < 0.5:
			continue
		var steps: int = maxi(1, int(slen))
		for si: int in range(steps + 1):
			var t: float = float(si) / float(steps)
			var p: Vector2 = o + d * t
			var nrm: Vector2 = Vector2(sp.get("normal", Vector2.ZERO))
			if nrm.length_squared() < 0.0001:
				nrm = Vector2(-d.y, d.x)
			if nrm.length_squared() > 0.0001:
				nrm = nrm.normalized()
			var hit_now: bool = false
			var step_i: int = 0
			while step_i < 3 and not hit_now:
				var q: Vector2 = p + nrm * (0.5 + float(step_i) * 0.5)
				var qx: int = int(floor(q.x))
				var qy: int = int(floor(q.y))
				var ni: int = 0
				while ni < 5 and not hit_now:
					var ax: int = qx
					var ay: int = qy
					if ni == 1:
						ax = qx + 1
					elif ni == 2:
						ax = qx - 1
					elif ni == 3:
						ay = qy + 1
					elif ni == 4:
						ay = qy - 1
					if ax >= 0 and ay >= 0 and ax < sw and ay < sh and solid.size() == sw * sh and solid[ay * sw + ax] != 0:
						hit_now = true
					ni += 1
				step_i += 1
			if hit_now:
				span_hits += 1
			else:
				span_miss += 1
	fail += Util._spec(lines, "span_on_solid", span_hits > 0 and span_miss == 0, "hit=%d miss=%d" % [span_hits, span_miss])
	var job_ok: int = 0
	var job_bad: int = 0
	for rawj: Variant in jobs:
		if not (rawj is Dictionary):
			continue
		var jc: Vector2i = Vector2i(rawj.get("cell", Vector2i.ZERO))
		var fx2: int = jc.x * n + (n >> 1)
		var fy2: int = jc.y * n + (n >> 1)
		if n >= 2 and solid.size() == sw * sh and sw > 0 and fx2 >= 0 and fy2 >= 0 and fx2 < sw and fy2 < sh and solid[fy2 * sw + fx2] != 0:
			job_ok += 1
		else:
			job_bad += 1
	fail += Util._spec(lines, "jobs_on_solid", job_bad == 0 and job_ok > 0, "ok=%d bad=%d" % [job_ok, job_bad])
	var rim: Dictionary = rim_report(data)
	var hole_n: int = int(rim.get("holes", 0))
	var hole_txt: String = str(rim.get("sample", ""))
	fail += Util._spec(lines, "rim_closed", hole_n == 0, "holes=%d sample=%s" % [hole_n, hole_txt])
	return fail


static func mark_holes(overlays: Dictionary, data: Dictionary) -> int:
	var rim: Dictionary = rim_report(data)
	var cells: Array = rim.get("cells", []) as Array
	for raw: Variant in cells:
		if raw is Vector2i and not overlays.has(raw):
			overlays[raw] = "rim_hole"
	return int(rim.get("holes", 0))


static func rim_report(data: Dictionary) -> Dictionary:
	var empty: Dictionary = {"holes": 0, "cells": [], "sample": "-"}
	var spans: Array = data.get("outline_spans", []) as Array
	var raw_solid: Variant = data.get("solid", PackedByteArray())
	if not (raw_solid is PackedByteArray):
		return empty
	var solid: PackedByteArray = raw_solid
	var sw: int = int(data.get("solid_w", 0))
	var sh: int = int(data.get("solid_h", 0))
	var per: int = int(data.get("solid_n", 0))
	if per < 1 or sw < 2 or sh < 2 or solid.size() != sw * sh:
		return empty
	var cover: PackedByteArray = PackedByteArray()
	cover.resize(sw * sh)
	cover.fill(0)
	for raw_span: Variant in spans:
		if not (raw_span is Dictionary):
			continue
		var sp: Dictionary = raw_span
		var o: Vector2 = Vector2(sp.get("origin", Vector2.ZERO))
		var d: Vector2 = Vector2(sp.get("delta", Vector2.ZERO))
		var slen: float = d.length()
		if slen < 0.5:
			continue
		var steps: int = maxi(1, int(ceil(slen * 2.0)))
		for si: int in range(steps + 1):
			var t: float = float(si) / float(steps)
			var p: Vector2 = o + d * t
			var cx: int = int(floor(p.x))
			var cy: int = int(floor(p.y))
			for oy: int in range(cy - 2, cy + 3):
				if oy < 0 or oy >= sh:
					continue
				for ox: int in range(cx - 2, cx + 3):
					if ox < 0 or ox >= sw:
						continue
					cover[oy * sw + ox] = 1
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var hole_n: int = 0
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var sample: PackedStringArray = PackedStringArray()
	for y: int in sh:
		var row: int = y * sw
		for x: int in sw:
			if solid[row + x] == 0:
				continue
			var edge: bool = false
			for d2: Vector2i in dirs:
				var nx: int = x + d2.x
				var ny: int = y + d2.y
				if nx < 0 or ny < 0 or nx >= sw or ny >= sh or solid[ny * sw + nx] == 0:
					edge = true
					break
			if not edge:
				continue
			if cover[row + x] != 0:
				continue
			hole_n += 1
			var cell: Vector2i = Vector2i(int(x / per), int(y / per))
			if not seen.has(cell):
				seen[cell] = true
				cells.append(cell)
				if sample.size() < 8:
					sample.append("%d,%d" % [cell.x, cell.y])
	var shown: String = "-"
	if sample.size() > 0:
		shown = ",".join(sample)
	return {"holes": hole_n, "cells": cells, "sample": shown}
