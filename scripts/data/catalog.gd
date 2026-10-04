extends Object

## Eight artifact sets. Bonuses begin at 2 pieces.

const LocS := preload("res://scripts/app/app_loc.gd")
const SETS: PackedStringArray = ["cinder", "tide", "root", "ash", "spark", "bone", "veil", "iron"]

const ARTS: Array = [
	{"id": "cinder_ember", "set": "cinder"},
	{"id": "cinder_coil", "set": "cinder"},
	{"id": "tide_pearl", "set": "tide"},
	{"id": "tide_scale", "set": "tide"},
	{"id": "root_knot", "set": "root"},
	{"id": "root_charm", "set": "root"},
	{"id": "root_seed", "set": "root"},
	{"id": "ash_mask", "set": "ash"},
	{"id": "ash_bell", "set": "ash"},
	{"id": "ash_cloak", "set": "ash"},
	{"id": "spark_lens", "set": "spark"},
	{"id": "spark_wire", "set": "spark"},
	{"id": "bone_ring", "set": "bone"},
	{"id": "bone_splint", "set": "bone"},
	{"id": "bone_tooth", "set": "bone"},
	{"id": "veil_shard", "set": "veil"},
	{"id": "veil_thread", "set": "veil"},
	{"id": "veil_coin", "set": "veil"},
	{"id": "veil_hush", "set": "veil"},
	{"id": "iron_seal", "set": "iron"},
	{"id": "iron_nail", "set": "iron"},
	{"id": "iron_link", "set": "iron"},
	{"id": "iron_plate", "set": "iron"},
	{"id": "iron_heart", "set": "iron"},
]

static func _loc(a: Dictionary) -> Dictionary:
	var d: Dictionary = a.duplicate()
	d["name"] = LocS.tr_or("item.%s.name" % a.id, str(a.id).capitalize())
	d["desc"] = LocS.tr_or("item.%s.desc" % a.id, "")
	return d

## Ids only (`id`, `set`): text is looked up when drawn (`by_id`), so a language change shows at once.
static func pick(rng: RandomNumberGenerator, n: int) -> Array:
	var pool: Array = ARTS.duplicate()
	var out: Array = []
	n = mini(n, pool.size())
	for _i in n:
		if pool.is_empty():
			break
		var j := rng.randi() % pool.size()
		out.append((pool[j] as Dictionary).duplicate())
		pool.remove_at(j)
	return out

static func by_id(id: String) -> Dictionary:
	for a in ARTS:
		if str(a.id) == id:
			return _loc(a)
	return {}

static func set_title(set_id: String) -> String:
	return LocS.tr_or("set.%s.name" % set_id, set_id)

static func set_size(set_id: String) -> int:
	var n := 0
	for a in ARTS:
		if str(a.set) == set_id:
			n += 1
	return n

static func set_bonus_line(set_id: String, n: int) -> String:
	match set_id:
		"cinder":
			return App.tr("set.cinder.bonus") if n >= 2 else ""
		"tide":
			return App.tr("set.tide.bonus") if n >= 2 else ""
		"root":
			return App.tr("set.root.bonus") if n >= 2 else ""
		"ash":
			return App.tr("set.ash.bonus") if n >= 2 else ""
		"spark":
			return App.tr("set.spark.bonus") if n >= 2 else ""
		"bone":
			return App.tr("set.bone.bonus") if n >= 2 else ""
		"veil":
			return App.tr("set.veil.bonus") if n >= 2 else ""
		"iron":
			return App.tr("set.iron.bonus") if n >= 2 else ""
	return ""

static func set_ids() -> PackedStringArray:
	return SETS
