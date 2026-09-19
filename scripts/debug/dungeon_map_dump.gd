extends Object

const Util := preload("res://scripts/debug/dungeon_map_util.gd")
const Collect := preload("res://scripts/debug/dungeon_map_collect.gd")
const Emit := preload("res://scripts/debug/dungeon_map_emit.gd")
const Spec := preload("res://scripts/debug/dungeon_map_spec.gd")
const Ascii := preload("res://scripts/debug/dungeon_map_ascii.gd")

static func dump_floor(host: Node) -> void:
	var lines: Array[String] = []
	var data: Dictionary = host.get("data")
	if data.is_empty() or not bool(data.get("ok", false)):
		Util._out(lines, "ok=false reason=no_data")
		_finish(lines, false)
		return
	var grid_w: int = int(data.get("w", 0))
	var grid_h: int = int(data.get("h", 0))
	var rooms: Array = data.get("rooms", []) as Array
	var spawn: Vector2i = Vector2i(data.get("spawn", Vector2i.ZERO))
	var stairs: Vector2i = Vector2i(data.get("stairs", Vector2i.ZERO))
	var door: Vector2i = Vector2i(data.get("door", Vector2i.ZERO))
	var boss: Vector2i = Vector2i(data.get("boss", Vector2i.ZERO))
	Util._out(lines, "floor=%d seed=%d w=%d h=%d rooms=%d ok=true" % [App.floor_n, App.run_seed, grid_w, grid_h, rooms.size()])
	Util._out(lines, "role=%s gate_master=%s cycle=%s" % [str(data.get("boss_title", "")), str(data.get("gate_master", false)), str(data.get("cycle", 0))])
	Util._out(lines, "spawn=%s stairs=%s door=%s boss=%s" % [Util._fmt(spawn), Util._fmt(stairs), Util._fmt(door), Util._fmt(boss)])
	Util._out(lines, "tunables gen_w=%s gen_h=%s gen_rooms=%s extra_loops=%s max_clerks=%s crystal_min_sep=%s crystal_extra_max=%s ambush_cap=%s" % [str(App.bal.get("gen_w")), str(App.bal.get("gen_h")), str(App.bal.get("gen_rooms")), str(App.bal.get("gen_extra_loops")), str(App.bal.get("max_clerks")), str(App.bal.get("crystal_min_sep")), str(App.bal.get("crystal_extra_max")), str(App.bal.get("ambush_cap"))])
	Emit._emit_kinds(lines, rooms)
	Emit._emit_rooms(lines, rooms)
	var overlays: Dictionary = {}
	var objs: Array = Collect._collect(host, data, overlays)
	Emit._emit_objs(lines, objs)
	Emit._emit_jobs(lines, host)
	Emit._emit_counts(lines, host, data, objs)
	var spec_fail: int = Spec._emit_spec(lines, host, data, objs)
	Ascii._emit_ascii(lines, data, overlays)
	Util._out(lines, "spec_fail=%d" % spec_fail)
	Util._out(lines, "ok=true")
	_write_dump(lines)
	_finish(lines, true)


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
