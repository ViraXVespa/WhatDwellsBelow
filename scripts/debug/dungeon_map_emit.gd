extends Object

const Cells := preload("res://scripts/world/dungeon_cells.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const Util := preload("res://scripts/debug/dungeon_map_util.gd")

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
	Util._out(lines, "kinds " + " ".join(bits))


static func _emit_rooms(lines: Array[String], rooms: Array) -> void:
	var i: int = 0
	for r: Variant in rooms:
		var vein: String = str(r.get("vein", ""))
		var extra: String = ""
		if vein != "":
			extra = " vein=" + vein
		Util._out(lines, "room i=%d kind=%s x=%d y=%d w=%d h=%d c=%s%s" % [i, str(r.get("kind", "normal")), int(r.x), int(r.y), int(r.w), int(r.h), Util._fmt(Cells.center_room(r)), extra])
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
		Util._out(lines, "obj kind=%s cell=%s%s" % [kind, Util._fmt(cell), extra])


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
		Util._out(lines, "job i=%d kind=%s cell=%s pack=%d state=%s named=%s nname=%s room=%s ids=%s" % [i, str(job.get("kind", "")), Util._fmt(cell), ids.size(), str(job.get("state", "")), str(job.get("named", false)), str(job.get("nname", "")), rk, ",".join(ids)])
		i += 1


static func _emit_counts(lines: Array[String], host: Node, data: Dictionary, objs: Array) -> void:
	var t: Dictionary = Util._tally_objs(objs)
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
	Util._out(lines, "counts " + " ".join(bits))
	Util._out(lines, "jobs total=%d room=%d ambush=%d named=%d pack=%d floor_cells=%d deadends=%d ambush_anchors=%d crystals_data=%d" % [jobs.size(), room_jobs, ambush_jobs, named_jobs, pack_sum, floor_cells, (data.get("deadends", []) as Array).size(), (data.get("ambushes", []) as Array).size(), (data.get("crystals", []) as Array).size()])
	var host_counts: Dictionary = host.get("counts") as Dictionary
	if not host_counts.is_empty():
		var cb: PackedStringArray = PackedStringArray()
		var ck: Array = host_counts.keys()
		ck.sort()
		for k2: Variant in ck:
			cb.append("%s=%s" % [str(k2), str(host_counts[k2])])
		Util._out(lines, "placed " + " ".join(cb))
