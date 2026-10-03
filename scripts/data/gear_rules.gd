extends Object

const Kit := preload("res://scripts/data/gear_rules/rules_kit.gd")
const Norm := preload("res://scripts/data/gear_rules/rules_norm.gd")

const BUILTIN_WEAPONS := ["great_axe", "staff", "longbow"]
const BUILTIN_TOOLS := ["pickaxe", "hatchet"]

static func book(p: Object) -> Dictionary:
	return Kit.book(p)

static func tmpl_key(it: Dictionary) -> String:
	return Kit.tmpl_key(it)

static func is_starter(p: Object, it: Dictionary) -> bool:
	return Kit.is_starter(p, it)

static func locked_equip_slot(slot: String) -> bool:
	return Kit.locked_equip_slot(slot)

static func grant_smith(p: Object, it: Dictionary) -> String:
	return Kit.grant_smith(p, it)

static func handle_mail(p: Object, it: Dictionary) -> String:
	return Kit.handle_mail(p, it)

static func normalize_prog(p: Object) -> void:
	Norm.normalize_prog(p)

static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Norm.drink(p, it, from_slot)

static func refill_potion(p: Object) -> void:
	Norm.refill_potion(p)
