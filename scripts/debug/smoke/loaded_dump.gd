extends Node

## Smoke load map: --wdb-dump-loaded=PATH writes every live script, scene and resource the run loaded (the
## ResourceLoader cache, sampled every frame and at exit, plus the static dependencies of each hit) to PATH, one res:// path per line. gate.py bot-smokes
## --record-loads turns the per-phase dumps into tools/data/phase_loads.json, which picks the phases a change needs.

const FLAG := "--wdb-dump-loaded="
const DIRS: Array[String] = ["res://scripts", "res://scenes", "res://tools/data", "res://assets/shaders"]
const EXT: Array[String] = ["gd", "tscn", "tres", "gdshader"]

var out_path: String = ""
var _all: PackedStringArray = []
var _seen: Dictionary = {}

static func maybe_start(tree: SceneTree, args: PackedStringArray) -> void:
	for a: String in args:
		if a.begins_with(FLAG):
			var n: Node = (load("res://scripts/debug/smoke/loaded_dump.gd") as GDScript).new()
			n.set("out_path", a.substr(FLAG.length()))
			tree.root.add_child.call_deferred(n)

func _list(dir: String) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() in EXT:
			_all.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_list(dir.path_join(d))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d: String in DIRS:
		if DirAccess.dir_exists_absolute(d):
			_list(d)
	_sample()

func _process(_d: float) -> void:
	_sample()

func _sample() -> void:
	for p: String in _all:
		if not _seen.has(p) and ResourceLoader.has_cached(p):
			_seen[p] = true

func _deps(p: String) -> void:
	for d: String in ResourceLoader.get_dependencies(p):
		var r: String = d.substr(d.find("res://")).get_slice("::", 0) if d.contains("res://") else d.get_slice("::", 0)
		if r.begins_with("uid://"):
			var id: int = ResourceUID.text_to_id(r)
			r = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
		if r != "" and not _seen.has(r) and r.get_extension() in EXT:
			_seen[r] = true
			_deps(r)

func _exit_tree() -> void:
	_sample()
	for p: String in _seen.keys():
		_deps(p)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(PackedStringArray(_seen.keys())) + "\n")
