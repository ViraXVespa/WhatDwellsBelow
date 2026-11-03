extends Object

## Offline sole bake. Flag --wdb-bake-soles. Writes scripts/data/actor_soles.json and quits.

const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")

static func run(tree: SceneTree) -> void:
	var paths: PackedStringArray = PackedStringArray()
	# Sprites and the fx stickers ActorLit binds (the training dummy lives under fx).
	_pngs("res://assets/sprites", paths)
	_pngs("res://assets/fx", paths)
	paths.sort()
	if paths.is_empty():
		_fail(tree, "no pngs under res://assets/sprites or res://assets/fx")
		return
	var rows: Dictionary = {}
	var lines: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			_fail(tree, "load failed %s" % path)
			return
		var scanned: Dictionary = Soles._scan(tex)
		var sha: String = FileAccess.get_sha256(path).substr(0, 16)
		if sha == "":
			_fail(tree, "sha failed %s" % path)
			return
		var sole: Vector4 = scanned["sole"] as Vector4
		var packed: Array = [
			sha,
			Soles._fhex(sole.x), Soles._fhex(sole.y), Soles._fhex(sole.z), Soles._fhex(sole.w),
			int(scanned["min_x"]), int(scanned["min_y"]), int(scanned["max_x1"]), int(scanned["max_y1"]),
			int(scanned["w"]), int(scanned["h"]),
		]
		rows[path] = packed
		lines.append(_line(path, packed))
	lines.append("soles:" + _script_sha("res://scripts/graphics/actor_lit/soles.gd"))
	lines.append("bake:" + _script_sha("res://scripts/graphics/actor_lit/sole_bake.gd"))
	lines.append("soles-v1")
	var stamp: String = _sha_text("\n".join(lines)).substr(0, 16)
	var payload: Dictionary = {"stamp": stamp, "algo": "soles-v1", "rows": rows}
	var abs_path: String = ProjectSettings.globalize_path(Soles.BAKE_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var out: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if out == null:
		_fail(tree, "cannot write %s" % abs_path)
		return
	out.store_string(JSON.stringify(payload))
	out.close()
	printerr("bake_soles: n=%d stamp=%s" % [paths.size(), stamp])
	tree.quit(0)

static func _line(path: String, packed: Array) -> String:
	return "%s\t%s\t%s,%s,%s,%s,%d,%d,%d,%d,%d,%d" % [
		path, str(packed[0]),
		str(packed[1]), str(packed[2]), str(packed[3]), str(packed[4]),
		int(packed[5]), int(packed[6]), int(packed[7]), int(packed[8]), int(packed[9]), int(packed[10]),
	]

static func _pngs(dir_path: String, out: PackedStringArray) -> void:
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return
	var files: PackedStringArray = da.get_files()
	for name: String in files:
		if name.ends_with(".png"):
			out.append(dir_path.path_join(name))
	var subs: PackedStringArray = da.get_directories()
	for sub: String in subs:
		_pngs(dir_path.path_join(sub), out)

static func _script_sha(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return _sha_text(_strip_stamp(raw.get_string_from_utf8()))

static func _strip_stamp(src: String) -> String:
	var key: String = "const SOLE_BAKE_STAMP := \""
	var at: int = src.find(key)
	if at < 0:
		return src
	var end: int = src.find("\"", at + key.length())
	if end < 0:
		return src
	return src.substr(0, at) + key + src.substr(end)

static func _sha_text(src: String) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(src.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _fail(tree: SceneTree, msg: String) -> void:
	printerr("bake_soles: FAIL %s" % msg)
	tree.quit(1)
