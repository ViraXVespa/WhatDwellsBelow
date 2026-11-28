extends Object

const Bag := preload("res://scripts/data/progress_gear/gear_bag.gd")
const Use := preload("res://scripts/data/progress_gear/gear_use.gd")
const Extract := preload("res://scripts/data/progress_gear/extract.gd")
const Restock := preload("res://scripts/data/progress_gear/restock.gd")

static func make_weapon(p: Object, wpn: String, rarity: String, ilvl: int = 0) -> Dictionary:
	return Bag.make_weapon(p, wpn, rarity, ilvl)

static func make_tool(p: Object, kind: String, rarity := "white", ilvl: int = 0) -> Dictionary:
	return Bag.make_tool(p, kind, rarity, ilvl)

static func make_armor(p: Object, slot: String, rarity: String, ilvl: int = 0) -> Dictionary:
	return Bag.make_armor(p, slot, rarity, ilvl)

static func make_potion(p: Object, n: int) -> Dictionary:
	return Bag.make_potion(p, n)

static func make_food(p: Object, fid: String, n: int) -> Dictionary:
	return Bag.make_food(p, fid, n)

static func make_artifact(p: Object, id: String) -> Dictionary:
	return Bag.make_artifact(p, id)

static func item(p: Object, kind: String, name: String, extra: Dictionary) -> Dictionary:
	return Bag.item(p, kind, name, extra)

static func starter(p: Object, slot: String) -> Dictionary:
	return Bag.starter(p, slot)

static func required_piece(p: Object, slot: String) -> Dictionary:
	return Bag.required_piece(p, slot)

static func ensure_required_slots(p: Object) -> void:
	Bag.ensure_required_slots(p)

static func add_item(p: Object, it: Dictionary) -> bool:
	return Bag.add_item(p, it)

static func add_to_bag(p: Object, it: Dictionary) -> bool:
	return Bag.add_to_bag(p, it)

static func remove_uid(p: Object, uid: int) -> Dictionary:
	return Bag.remove_uid(p, uid)

static func equip_uid(p: Object, uid: int) -> String:
	return Bag.equip_uid(p, uid)

static func drop_uid(p: Object, uid: int) -> String:
	return Bag.drop_uid(p, uid)

static func unequip_slot(p: Object, slot: String) -> String:
	return Bag.unequip_slot(p, slot)

static func drop_slot(p: Object, slot: String) -> String:
	return Bag.drop_slot(p, slot)

static func take_slot(p: Object, slot: String) -> Dictionary:
	return Bag.take_slot(p, slot)

static func drop_stash(p: Object, uid: int) -> String:
	return Bag.drop_stash(p, uid)

static func use_from_bag(p: Object, uid: int) -> String:
	return Use.use_from_bag(p, uid)

static func use_potion(p: Object) -> String:
	return Use.use_potion(p)

static func use_food(p: Object) -> String:
	return Use.use_food(p)

static func tick_food(p: Object, delta: float) -> void:
	Use.tick_food(p, delta)

## Extraction mailing (inventory.meta): what may be mailed, and the mail itself.
static func extractable(p: Object, role: String = "") -> Array:
	return Extract.extractable(p, role)

static func extract_all(p: Object, role: String) -> String:
	return Extract.extract_all(p, role)

static func extract_one(p: Object, it: Dictionary, role: String) -> String:
	return Extract.extract_one(p, it, role)

static func stock_extract_shot(p: Object) -> void:
	Extract.stock_extract_shot(p)

static func bag_mailable(it: Variant) -> bool:
	return Extract._bag_mailable(it)

static func equipped_mailable(it: Dictionary, slot: String) -> bool:
	return Extract._equipped_listed(it, slot)

## Guild restock after a run (inventory.meta).
static func restock(p: Object) -> String:
	return Restock.restock(p)
