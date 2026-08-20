class_name RunState
extends RefCounted

const BAG_SIZE := 28

var current_floor: int = 1
var hp: float = 100.0
var max_hp: float = 100.0
var mana: float = 50.0
var max_mana: float = 50.0
var gold: int = 0
var bag: Array = []
var weapon: ItemData
var tool: ItemData
var potion: ItemData
var armor_head: ItemData
var armor_body: ItemData
var armor_legs: ItemData
var mining_xp_run: float = 0.0
var great_axe_xp_run: float = 0.0
var smithing_xp_run: float = 0.0
var ore_extracted: int = 0
var gold_mailed: int = 0
var gear_extracted: Array = []
var potion_cd: float = 0.0
var visited_deepest: int = 1
var seed_value: int = 0
var gathering_spent: Dictionary = {}
var misc_spent: Dictionary = {}
var shrine_buff_t: float = 0.0
var artifact_ids: Array = []
var move_mult: float = 1.0
var dash_cd_mult: float = 1.0
var slam_dmg_mult: float = 1.0
var dmg_mult: float = 1.0
var gold_mult: float = 1.0
var mine_mult: float = 1.0
var lucky_mine: bool = false
var shop_buys: int = 0
var shop_locked: bool = false
var saw_stairs: bool = false
var guardian_low: bool = false


func _init() -> void:
	bag.resize(BAG_SIZE)
	for i in BAG_SIZE:
		bag[i] = null


func setup(save: SaveData, chosen: Dictionary) -> void:
	weapon = chosen.get("weapon", ItemData.make_starter_axe())
	tool = chosen.get("tool", ItemData.make_starter_pickaxe())
	potion = chosen.get("potion", null)
	armor_head = chosen.get("head", null)
	armor_body = chosen.get("body", null)
	armor_legs = chosen.get("legs", null)
	max_hp = 100.0 + armor_bonus_sum("hp")
	hp = max_hp
	mana = max_mana
	gold = 0
	seed_value = randi()
	var food_n := 3 + (save.extra_food if save else 0)
	add_item(ItemData.make_food(food_n))
	if save:
		save.extra_food = 0
		if save.extra_potion > 0:
			for _i in save.extra_potion:
				add_item(ItemData.make_potion())
			save.extra_potion = 0
	if potion == null and save:
		var pots: Array = save.holds_of("potion")
		if not pots.is_empty():
			potion = pots[0]
	visited_deepest = 1
	_apply_armor_non_hp()


func _apply_armor_non_hp() -> void:
	move_mult = 1.0
	gold_mult = 1.0
	mine_mult = 1.0
	for it in [armor_head, armor_body, armor_legs]:
		if it == null:
			continue
		match it.bonus_key:
			"speed":
				move_mult += it.bonus_val
			"gold":
				gold_mult += it.bonus_val
			"mine":
				mine_mult += it.bonus_val


func armor_bonus_sum(key: String) -> float:
	var t := 0.0
	for it in [armor_head, armor_body, armor_legs]:
		if it and it.bonus_key == key:
			t += it.bonus_val
	return t


func total_defense() -> float:
	var d := 0.0
	for it in [armor_head, armor_body, armor_legs]:
		if it:
			d += it.defense
	return d


func add_item(it: ItemData) -> bool:
	if it == null:
		return false
	if it.kind == ItemData.Kind.MATERIAL or (it.kind == ItemData.Kind.CONSUMABLE and it.family == "food"):
		for i in BAG_SIZE:
			var mar := bag[i] as ItemData
			if mar and mar.stacks_with(it):
				var room := mar.stack_cap() - mar.count
				if room <= 0:
					continue
				var take: int = mini(room, it.count)
				mar.count += take
				it.count -= take
				if it.count <= 0:
					return true
	for i in BAG_SIZE:
		if bag[i] == null:
			bag[i] = it
			return true
	return false


func bag_count() -> int:
	var n := 0
	for it in bag:
		if it != null:
			n += 1
	return n


func remove_item_at(index: int, amount: int = -1) -> ItemData:
	if index < 0 or index >= BAG_SIZE:
		return null
	var it: ItemData = bag[index]
	if it == null:
		return null
	if amount < 0 or amount >= it.count:
		bag[index] = null
		return it
	it.count -= amount
	var copy := ItemData.from_dict(it.to_dict())
	copy.count = amount
	copy.unique_id = ItemData.next_id()
	return copy


func items_of_family(family: String) -> Array:
	var out: Array = []
	for i in BAG_SIZE:
		var it: ItemData = bag[i]
		if it and it.family == family:
			out.append({"index": i, "item": it})
	return out


func items_of_kind(kind: ItemData.Kind) -> Array:
	var out: Array = []
	for i in BAG_SIZE:
		var it: ItemData = bag[i]
		if it and it.kind == kind:
			out.append({"index": i, "item": it})
	return out


func mailable_gear() -> Array:
	var out: Array = []
	for i in BAG_SIZE:
		var it: ItemData = bag[i]
		if it == null:
			continue
		if it.kind in [ItemData.Kind.WEAPON, ItemData.Kind.TOOL, ItemData.Kind.ARMOR, ItemData.Kind.POTION]:
			out.append({"index": i, "item": it})
	return out


func consume_family(family: String) -> ItemData:
	if family == "potion":
		return null
	for i in BAG_SIZE:
		var it: ItemData = bag[i]
		if it and it.family == family:
			return remove_item_at(i, 1)
	return null


func drop_equipped(slot: String) -> ItemData:
	var it: ItemData = null
	match slot:
		"weapon":
			it = weapon
			weapon = null
		"tool":
			it = tool
			tool = null
		"potion":
			it = potion
			potion = null
		"head":
			it = armor_head
			armor_head = null
		"body":
			it = armor_body
			armor_body = null
		"legs":
			it = armor_legs
			armor_legs = null
	_apply_armor_non_hp()
	return it


func equip_from_bag(index: int, slot: String) -> bool:
	if index < 0 or index >= BAG_SIZE:
		return false
	var it: ItemData = bag[index]
	if it == null:
		return false
	var cur: ItemData = null
	match slot:
		"weapon":
			if it.kind != ItemData.Kind.WEAPON:
				return false
			cur = weapon
			weapon = it
		"tool":
			if it.kind != ItemData.Kind.TOOL:
				return false
			cur = tool
			tool = it
		"potion":
			if it.kind != ItemData.Kind.POTION and it.family != "potion":
				return false
			cur = potion
			potion = it
		"head", "body", "legs":
			if it.kind != ItemData.Kind.ARMOR or it.armor_slot != slot:
				return false
			match slot:
				"head":
					cur = armor_head
					armor_head = it
				"body":
					cur = armor_body
					armor_body = it
				"legs":
					cur = armor_legs
					armor_legs = it
		_:
			return false
	bag[index] = cur
	max_hp = 100.0 + armor_bonus_sum("hp")
	hp = minf(hp, max_hp)
	_apply_armor_non_hp()
	return true
