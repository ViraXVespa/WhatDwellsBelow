extends Object

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const KEEP := 3

static func _prune() -> void:
	var dir_path: String = PlaytestLogUtil._dir()
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return
	var batches: Array = []
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if not da.current_is_dir() and name.begins_with("batch_") and name.ends_with(".json"):
			batches.append(name)
		name = da.get_next()
	da.list_dir_end()
	batches.sort()
	while batches.size() > KEEP:
		var drop: String = str(batches[0])
		batches.remove_at(0)
		_drop_batch(dir_path, drop)
	var keep: Dictionary = {}
	for bn: Variant in batches:
		keep[str(bn)] = true
		keep[str(bn).trim_suffix(".json") + ".txt"] = true
		var jf: FileAccess = FileAccess.open(dir_path.path_join(str(bn)), FileAccess.READ)
		if jf == null:
			continue
		var parsed: Variant = JSON.parse_string(jf.get_as_text())
		jf.close()
		if not (parsed is Dictionary):
			continue
		for fn: Variant in (parsed as Dictionary).get("files", []):
			keep[str(fn)] = true
		for row: Variant in (parsed as Dictionary).get("runs", []):
			if row is Dictionary:
				var rf: String = str((row as Dictionary).get("file", ""))
				if rf != "":
					keep[rf] = true
	da = DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	name = da.get_next()
	while name != "":
		if not da.current_is_dir() and not keep.has(name):
			if name.begins_with("batch_") or name.begins_with("run_"):
				_rm(dir_path.path_join(name))
		name = da.get_next()
	da.list_dir_end()

static func _drop_batch(dir_path: String, json_name: String) -> void:
	var json_path: String = dir_path.path_join(json_name)
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var body: Dictionary = parsed
			for fn: Variant in body.get("files", []):
				_rm(dir_path.path_join(str(fn)))
			for row: Variant in body.get("runs", []):
				if row is Dictionary:
					var rf: String = str((row as Dictionary).get("file", ""))
					if rf != "":
						_rm(dir_path.path_join(rf))
	_rm(json_path)
	_rm(dir_path.path_join(json_name.trim_suffix(".json") + ".txt"))

static func _rm(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(path)
