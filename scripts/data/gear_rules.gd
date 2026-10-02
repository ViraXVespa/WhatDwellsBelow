extends Object

const Kit := preload("res://scripts/data/gear_rules_kit.gd")
const Norm := preload("res://scripts/data/gear_rules_norm.gd")

const BUILTIN_WEAPONS := ["great_axe", "staff", "longbow"]
const BUILTIN_TOOLS := ["pickaxe", "hatchet"]

static func book(p: Object) -> Dictionary:
	return Kit.book(p)

static func tmpl_key(it: Dictionary) -> String:
	return Kit.tmpl_key(it)

static func is_builtin_starter(it: Dictionary) -> bool:
	return Kit.is_builtin_starter(it)

static func is_starter(p: Object, it: Dictionary) -> bool:
	return Kit.is_starter(p, it)

static func can_forge(p: Object, it: Dictionary) -> bool:
	return Kit.can_forge(p, it)

static func can_bank(p: Object, it: Dictionary) -> bool:
	return Kit.can_bank(p, it)

static func locked_equip_slot(slot: String) -> bool:
	return Kit.locked_equip_slot(slot)

static func smith_xp_for(it: Dictionary) -> float:
	return Kit.smith_xp_for(it)

static func grant_smith(p: Object, it: Dictionary) -> String:
	return Kit.grant_smith(p, it)

static func unlock_starter(p: Object, it: Dictionary) -> void:
	Kit.unlock_starter(p, it)

static func starter_ilvl(p: Object, it: Dictionary) -> int:
	return Kit.starter_ilvl(p, it)

static func handle_mail(p: Object, it: Dictionary) -> String:
	return Kit.handle_mail(p, it)

static func normalize_prog(p: Object) -> void:
	Norm.normalize_prog(p)

static func normalize_item(it: Dictionary) -> Dictionary:
	return Norm.normalize_item(it)

static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Norm.drink(p, it, from_slot)

static func refill_potion(p: Object) -> void:
	Norm.refill_potion(p)

static func same_white(a: Dictionary, b: Dictionary) -> bool:
	return Kit.same_white(a, b)
