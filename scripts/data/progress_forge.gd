extends Object

const Book := preload("res://scripts/data/progress_forge_book.gd")
const Act := preload("res://scripts/data/progress_forge_act.gd")

const HOLD_CAP := 3
const FORGE_SLOTS: PackedStringArray = ["weapon", "tool", "head", "body", "legs"]


static func book(p: Object) -> Dictionary:
	return Book.book(p)


static func entry(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	return Book.entry(p, slot, type_id, rarity)


static func unlocks_for(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	return Book.unlocks_for(p, slot, type_id, rarity)


static func max_ilvl_rarity(p: Object, slot: String, type_id: String, rarity: String) -> int:
	return Book.max_ilvl_rarity(p, slot, type_id, rarity)


static func max_ilvl_type(p: Object, slot: String, type_id: String) -> int:
	return Book.max_ilvl_type(p, slot, type_id)


static func max_ilvl(p: Object, slot: String, type_id: String) -> int:
	return Book.max_ilvl(p, slot, type_id)


static func types_for(p: Object, slot: String) -> PackedStringArray:
	return Book.types_for(p, slot)


static func can_forge_rarity(p: Object, slot: String, type_id: String, rarity: String) -> bool:
	return Book.can_forge_rarity(p, slot, type_id, rarity)


static func can_analyze(p: Object, it: Dictionary) -> bool:
	return Book.can_analyze(p, it)


static func is_duplicate(p: Object, it: Dictionary) -> bool:
	return Book.is_duplicate(p, it)


static func grant(p: Object, it: Dictionary) -> void:
	Book.grant(p, it)


static func migrate(p: Object) -> void:
	Book.migrate(p)


static func forge_cost(p: Object, slot: String, rarity: String, ilvl: int, lock_n: int) -> Dictionary:
	return Act.forge_cost(p, slot, rarity, ilvl, lock_n)


static func forge_duration(p: Object, slot_or_lv = 1, _rarity: String = "", ilvl: int = -1) -> float:
	return Act.forge_duration(p, slot_or_lv, _rarity, ilvl)


static func can_pay(p: Object, c: Dictionary) -> bool:
	return Act.can_pay(p, c)


static func pay(p: Object, c: Dictionary) -> bool:
	return Act.pay(p, c)


static func holds_of(p: Object, slot: String, type_id: String) -> Array:
	return Act.holds_of(p, slot, type_id)


static func hold_open(p: Object, slot: String, type_id: String) -> int:
	return Act.hold_open(p, slot, type_id)


static func set_holds_for_type(p: Object, slot: String, type_id: String, keep: Array) -> String:
	return Act.set_holds_for_type(p, slot, type_id, keep)


static func make_forged(p: Object, slot: String, type_id: String, rarity: String, ilvl: int, locked: PackedStringArray) -> Dictionary:
	return Act.make_forged(p, slot, type_id, rarity, ilvl, locked)


static func add_hold(p: Object, it: Dictionary) -> String:
	return Act.add_hold(p, it)


static func place_hold(p: Object, it: Dictionary) -> void:
	Act.place_hold(p, it)


static func replace_hold(p: Object, a, b, c = 0, d = {}) -> String:
	return Act.replace_hold(p, a, b, c, d)


static func to_meta(p: Object) -> Dictionary:
	return Act.to_meta(p)


static func from_meta(p: Object, d: Dictionary) -> void:
	Act.from_meta(p, d)


static func type_of(it: Dictionary) -> String:
	return Book.type_of(it)


static func _type_of(it: Dictionary) -> String:
	return Book._type_of(it)


static func _stat_key(id: String) -> String:
	return Book._stat_key(id)


static func _traits_of(it: Dictionary) -> Array:
	return Book._traits_of(it)


static func _blank(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	return Act._blank(p, slot, type_id, rarity)


static func _spend_pair(need: int, pocket: String, bank: String) -> void:
	Act._spend_pair(need, pocket, bank)


static func _bal(key: String, fallback: float) -> float:
	return Act._bal(key, fallback)
