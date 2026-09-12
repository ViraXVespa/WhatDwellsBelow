extends Object

const Bag := preload("res://scripts/data/progress_gear_bag.gd")
const Use := preload("res://scripts/data/progress_gear_use.gd")

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

static func required_ok(slot: String, it: Dictionary) -> bool:
	return Bag.required_ok(slot, it)

static func required_piece(p: Object, slot: String) -> Dictionary:
	return Bag.required_piece(p, slot)

static func ensure_required_slots(p: Object) -> void:
	Bag.ensure_required_slots(p)

static func bag_stack_index(p: Object, it: Dictionary) -> int:
	return Bag.bag_stack_index(p, it)

static func bag_can_accept(p: Object, it: Dictionary) -> bool:
	return Bag.bag_can_accept(p, it)

static func _has_white_copy(p: Object, it: Dictionary) -> bool:
	return Bag._has_white_copy(p, it)

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

static func fill_slot_after_remove(p: Object, slot: String) -> void:
	Bag.fill_slot_after_remove(p, slot)

static func drop_slot(p: Object, slot: String) -> String:
	return Bag.drop_slot(p, slot)

static func take_slot(p: Object, slot: String) -> Dictionary:
	return Bag.take_slot(p, slot)

static func drop_stash(p: Object, uid: int) -> String:
	return Bag.drop_stash(p, uid)

static func give_or_drop(p: Object, it: Dictionary, pos: Vector3) -> bool:
	return Bag.give_or_drop(p, it, pos)

static func use_from_bag(p: Object, uid: int) -> String:
	return Use.use_from_bag(p, uid)

static func use_potion(p: Object) -> String:
	return Use.use_potion(p)

static func use_food(p: Object) -> String:
	return Use.use_food(p)

static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Use.drink(p, it, from_slot)

static func eat(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Use.eat(p, it, from_slot)

static func consume(p: Object, it: Dictionary, from_slot: bool) -> void:
	Use.consume(p, it, from_slot)

static func tick_food(p: Object, delta: float) -> void:
	Use.tick_food(p, delta)

static func dmg(p: Object) -> int:
	return Use.dmg(p)

static func def(p: Object) -> int:
	return Use.def(p)

static func hp(p: Object) -> int:
	return Use.hp(p)

static func stat(p: Object, key: String) -> float:
	return Use.stat(p, key)

static func tool_quality(p: Object) -> float:
	return Use.tool_quality(p)

static func set_counts(p: Object) -> Dictionary:
	return Use.set_counts(p)

static func set_stats(p: Object) -> Dictionary:
	return Use.set_stats(p)

static func set_bonus_text(p: Object, sid: String) -> String:
	return Use.set_bonus_text(p, sid)

static func sync_artifacts(p: Object) -> void:
	Use.sync_artifacts(p)

