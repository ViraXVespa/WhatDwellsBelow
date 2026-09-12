extends Object

const Kit := preload("res://scripts/data/gear_rules_kit.gd")
const Norm := preload("res://scripts/data/gear_rules_norm.gd")

const BUILTIN_WEAPONS := ["great_axe", "staff", "longbow"]
const BUILTIN_TOOLS := ["pickaxe", "hatchet"]


static func book(p: Object) -> Dictionary:
	return Kit.book(p)


static func tmpl_key(it: Dictionary) -> String:
	return Kit.tmpl_key(it)


static func _weapon_id(it: Dictionary) -> String:
	return Kit._weapon_id(it)


static func _tool_id(it: Dictionary) -> String:
	return Kit._tool_id(it)


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


static func _mail_white(p: Object, it: Dictionary) -> String:
	return Kit._mail_white(p, it)


static func _apply_starter_level(p: Object, it: Dictionary, ilvl: int) -> void:
	Kit._apply_starter_level(p, it, ilvl)


static func _restat_white(it: Dictionary, ilvl: int) -> Dictionary:
	return Kit._restat_white(it, ilvl)


static func _write_starter_ilvl(it: Dictionary, ilvl: int) -> void:
	Kit._write_starter_ilvl(it, ilvl)


static func normalize_prog(p: Object) -> void:
	Norm.normalize_prog(p)


static func _norm_list(arr: Array) -> void:
	Norm._norm_list(arr)


static func normalize_item(it: Dictionary) -> Dictionary:
	return Norm.normalize_item(it)


static func _map_legacy(it: Dictionary) -> void:
	Norm._map_legacy(it)


static func _map_id(id: String) -> String:
	return Norm._map_id(id)


static func _clamp_stat(id: String, v: float, cap_flat: float, cap_pct: float) -> float:
	return Norm._clamp_stat(id, v, cap_flat, cap_pct)


static func _cap_flat(ilvl: int) -> float:
	return Norm._cap_flat(ilvl)


static func _cap_pct(ilvl: int) -> float:
	return Norm._cap_pct(ilvl)


static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Norm.drink(p, it, from_slot)


static func refill_potion(p: Object) -> void:
	Norm.refill_potion(p)


static func same_white(a: Dictionary, b: Dictionary) -> bool:
	return Kit.same_white(a, b)
