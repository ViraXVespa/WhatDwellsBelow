extends RefCounted

## One reader for pipeline exports. Per-type builders live in content_pack/.
## An id that is not in the export index is not a pipeline asset: callers keep today's paths.
## An id that is listed, but whose record is missing or invalid, fails in debug.

const Character := preload("res://scripts/data/content_pack/character.gd")
const Foe := preload("res://scripts/data/content_pack/pack_enemy.gd")
const Npc := preload("res://scripts/data/content_pack/npc.gd")
const Item := preload("res://scripts/data/content_pack/item.gd")
const World := preload("res://scripts/data/content_pack/world.gd")
const Audio := preload("res://scripts/data/content_pack/audio.gd")

const INDEX_PATH := "res://data/pipeline/export/index.json"
const EXPORT_SCHEMA := "wdb.export/1"
const INDEX_SCHEMA := "wdb.export.index/1"
const CANVAS := 128

static var _ready: bool = false
static var _ids: Dictionary = {}
static var _records: Dictionary = {}


static func exported(subject_id: String) -> bool:
	_ensure()
	return _ids.has(subject_id)


static func record(subject_id: String) -> Dictionary:
	_ensure()
	if not _ids.has(subject_id):
		_fail("pipeline export missing: " + subject_id)
		return {}
	if _records.has(subject_id):
		return _records[subject_id]
	var path: String = str(_ids[subject_id])
	var doc: Dictionary = _read_object(path)
	if doc.is_empty():
		return {}
	if not _valid_record(doc, subject_id):
		return {}
	_records[subject_id] = doc
	return doc


static func view(subject_id: String) -> Dictionary:
	var doc: Dictionary = record(subject_id)
	if doc.is_empty():
		return {}
	var kind: String = str(doc.get("type", ""))
	if kind == "character":
		return Character.view(doc)
	if kind == "enemy" or kind == "sub-boss" or kind == "boss":
		return Foe.view(doc)
	if kind == "npc":
		return Npc.view(doc)
	if kind == "item" or kind == "equipment" or kind == "projectile" or kind == "resource" or kind == "ui" or kind == "vfx":
		return Item.view(doc)
	if kind == "biome" or kind == "building" or kind == "decoration":
		return World.view(doc)
	_fail("pipeline type has no builder: " + kind)
	return {}


static func scenario(doc: Dictionary, ctx: Dictionary) -> String:
	var rules: Variant = doc.get("rules", [])
	if not (rules is Array):
		return "base"
	for item in rules:
		if not (item is Dictionary):
			continue
		var op: String = str(item.get("op", ""))
		if _matches(op, item, ctx):
			var picked: String = str(item.get("scenario", "base"))
			if picked == "":
				return "base"
			return picked
	return "base"


static func frame_rect(doc: Dictionary, clip: String, frame_index: int) -> Rect2i:
	var frames: Variant = doc.get("frames", {})
	if not (frames is Dictionary) or not frames.has(clip):
		_fail("pipeline clip missing: " + clip)
		return Rect2i()
	var spec: Dictionary = frames[clip]
	var count: int = maxi(int(spec.get("count", 1)), 1)
	var columns: int = maxi(int(spec.get("columns", count)), 1)
	var wrapped: int = posmod(frame_index, count)
	var cell_w: int = int(spec.get("w", CANVAS))
	var cell_h: int = int(spec.get("h", CANVAS))
	var origin: Variant = spec.get("origin", [0, 0])
	var ox: int = 0
	var oy: int = 0
	if origin is Array and origin.size() >= 2:
		ox = int(origin[0])
		oy = int(origin[1])
	var col: int = wrapped % columns
	var row: int = int(float(wrapped) / float(columns))
	return Rect2i(ox + col * cell_w, oy + row * cell_h, cell_w, cell_h)


static func audio_of(subject_id: String) -> Array:
	var doc: Dictionary = record(subject_id)
	if doc.is_empty():
		return []
	return Audio.cues(doc)


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var doc: Dictionary = _read_object(INDEX_PATH)
	if doc.is_empty():
		return
	if str(doc.get("schema", "")) != INDEX_SCHEMA:
		_fail("pipeline index schema")
		return
	var rows: Variant = doc.get("subjects", [])
	if not (rows is Array):
		_fail("pipeline index subjects")
		return
	for row in rows:
		if not (row is Dictionary):
			_fail("pipeline index row")
			return
		var subject_id: String = str(row.get("id", ""))
		var kind: String = str(row.get("type", ""))
		if subject_id == "" or kind == "":
			_fail("pipeline index row needs id and type")
			return
		_ids[subject_id] = "res://data/pipeline/export/%s/%s.json" % [kind, subject_id]


static func _read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("pipeline file missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_fail("pipeline file is not an object: " + path)
		return {}
	return parsed


static func _valid_record(doc: Dictionary, subject_id: String) -> bool:
	if str(doc.get("schema", "")) != EXPORT_SCHEMA:
		_fail("pipeline schema: " + subject_id)
		return false
	if str(doc.get("id", "")) != subject_id:
		_fail("pipeline id: " + subject_id)
		return false
	if int(doc.get("canvas", 0)) != CANVAS:
		_fail("pipeline canvas: " + subject_id)
		return false
	if str(doc.get("type", "")) == "" or str(doc.get("name", "")) == "":
		_fail("pipeline type or name: " + subject_id)
		return false
	if not (doc.get("frames", {}) is Dictionary) or not (doc.get("sheets", []) is Array) or not (doc.get("rules", []) is Array):
		_fail("pipeline frames: " + subject_id)
		return false
	return true


static func _matches(op: String, rule: Dictionary, ctx: Dictionary) -> bool:
	if op == "always":
		return true
	if op == "equipped":
		var worn: Variant = ctx.get("equipped", {})
		if not (worn is Dictionary):
			return false
		return str(worn.get(str(rule.get("slot", "")), "")) == str(rule.get("tag", ""))
	if op == "health_below":
		return float(ctx.get("health", 1.0)) < float(rule.get("below", 0.0))
	if op == "has_item":
		return _listed(ctx.get("items", []), str(rule.get("item", "")))
	if op == "quest_complete":
		return _listed(ctx.get("quests", []), str(rule.get("quest", "")))
	_fail("pipeline rule op unknown: " + op)
	return false


static func _listed(bag: Variant, want: String) -> bool:
	if want == "" or not (bag is Array):
		return false
	for entry in bag:
		if str(entry) == want:
			return true
	return false


static func _fail(msg: String) -> void:
	push_error(msg)
	assert(not OS.is_debug_build(), msg)
