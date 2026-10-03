extends Object

## Eight artifact sets. Bonuses begin at 2 pieces.

const LocS := preload("res://scripts/app/app_loc.gd")
const SETS: PackedStringArray = ["cinder", "tide", "root", "ash", "spark", "bone", "veil", "iron"]

const ARTS: Array = [
	{"id": "cinder_ember", "name": "Cinder Ember", "set": "cinder", "desc": "A coal that never cools. +damage."},
	{"id": "cinder_coil", "name": "Cinder Coil", "set": "cinder", "desc": "Wire hot to the touch. +damage."},
	{"id": "tide_pearl", "name": "Tide Pearl", "set": "tide", "desc": "Salt-wet and heavy. +HP."},
	{"id": "tide_scale", "name": "Tide Scale", "set": "tide", "desc": "A fish that shouldn't be. +HP."},
	{"id": "root_knot", "name": "Root Knot", "set": "root", "desc": "Twisted living wood. +gathering."},
	{"id": "root_charm", "name": "Root Charm", "set": "root", "desc": "Smells like wet soil. +gathering."},
	{"id": "root_seed", "name": "Root Seed", "set": "root", "desc": "It wants to sprout. +gathering."},
	{"id": "ash_mask", "name": "Ash Mask", "set": "ash", "desc": "A face of grey dust. +defense."},
	{"id": "ash_bell", "name": "Ash Bell", "set": "ash", "desc": "Rings without sound. +defense."},
	{"id": "ash_cloak", "name": "Ash Cloak", "set": "ash", "desc": "Sheds in the wind. +defense."},
	{"id": "spark_lens", "name": "Spark Lens", "set": "spark", "desc": "Catches stray light. +crit."},
	{"id": "spark_wire", "name": "Spark Wire", "set": "spark", "desc": "Bites the fingers. +crit."},
	{"id": "bone_ring", "name": "Bone Ring", "set": "bone", "desc": "Too small for a human. +HP."},
	{"id": "bone_splint", "name": "Bone Splint", "set": "bone", "desc": "Yellowed and kind. +HP."},
	{"id": "bone_tooth", "name": "Bone Tooth", "set": "bone", "desc": "Still sharp. +HP."},
	{"id": "veil_shard", "name": "Veil Shard", "set": "veil", "desc": "See-through stone. +speed."},
	{"id": "veil_thread", "name": "Veil Thread", "set": "veil", "desc": "Hard to hold. +speed."},
	{"id": "veil_coin", "name": "Veil Coin", "set": "veil", "desc": "Both sides the same. +speed."},
	{"id": "veil_hush", "name": "Veil Hush", "set": "veil", "desc": "Quiets the room. +speed."},
	{"id": "iron_seal", "name": "Iron Seal", "set": "iron", "desc": "A guild stamp gone dark. +defense."},
	{"id": "iron_nail", "name": "Iron Nail", "set": "iron", "desc": "Bent, not broken. +defense."},
	{"id": "iron_link", "name": "Iron Link", "set": "iron", "desc": "From a longer chain. +defense."},
	{"id": "iron_plate", "name": "Iron Plate", "set": "iron", "desc": "Thumb-sized armor. +defense."},
	{"id": "iron_heart", "name": "Iron Heart", "set": "iron", "desc": "Heavier than it looks. +defense."},
]

static func _loc(a: Dictionary) -> Dictionary:
	var d: Dictionary = a.duplicate()
	d["name"] = LocS.tr_or("item.%s.name" % a.id, str(a.name))
	d["desc"] = LocS.tr_or("item.%s.desc" % a.id, str(a.desc))
	return d

static func pick(rng: RandomNumberGenerator, n: int) -> Array:
	var pool: Array = ARTS.duplicate()
	var out: Array = []
	n = mini(n, pool.size())
	for _i in n:
		if pool.is_empty():
			break
		var j := rng.randi() % pool.size()
		out.append(_loc(pool[j]))
		pool.remove_at(j)
	return out

static func by_id(id: String) -> Dictionary:
	for a in ARTS:
		if str(a.id) == id:
			return _loc(a)
	return {}

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
