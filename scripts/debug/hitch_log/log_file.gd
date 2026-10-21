extends Object

## Split from hitch_log.gd: _trim_file, _count_hitches, _read_all.

const HL_PATH := "res://scripts/debug/hitch_log.gd"

static func _trim_file() -> void:
	var hl: Variant = load(HL_PATH)
	var file_path: String = hl.file_path
	if file_path == "" or not FileAccess.file_exists(file_path):
		return
	var raw: String = FileAccess.get_file_as_string(file_path)
	if raw == "":
		return
	var kept: Array[String] = []
	var found: int = 0
	var parts: PackedStringArray = raw.split("\n")
	var i: int = parts.size()
	while i > 0:
		i -= 1
		var line: String = parts[i].strip_edges()
		if line == "" or not line.begins_with("{"):
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed == null:
			continue
		var is_hitch: bool = parsed is Dictionary and str((parsed as Dictionary).get("ev", "")) == "hitch"
		if is_hitch:
			if found >= hl.CAP:
				continue
			found += 1
		kept.push_front(line)
	var out: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if out == null:
		return
	for line: String in kept:
		out.store_line(line)
	out.close()

static func _count_hitches() -> int:
	var raw: String = _read_all()
	if raw == "":
		return 0
	var n: int = 0
	for line: String in raw.split("\n"):
		if line.find("\"ev\":\"hitch\"") >= 0:
			n += 1
	return n

static func _read_all() -> String:
	var file_path: String = load(HL_PATH).file_path
	if file_path != "" and FileAccess.file_exists(file_path):
		return FileAccess.get_file_as_string(file_path)
	return ""
