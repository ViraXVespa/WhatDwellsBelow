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


func _init() -> void:
	bag.resize(BAG_SIZE)
	for i in BAG_SIZE:
		bag[i] = null


func setup(save: SaveData, chosen_weapon: ItemData, chosen_tool: ItemData) -> void:
	weapon = chosen_weapon if chosen_weapon else ItemData.make_starter_axe()
	tool = chosen_tool if chosen_tool else ItemData.make_starter_pickaxe()
	hp = max_hp
	mana = max_mana
	gold = 0
	seed_value = randi()
	add_item(ItemData.make_food(3 + (save.extra_food if save else 0)))
	add_item(ItemData.make_potion(1 + (save.extra_potion if save else 0)))
	if save:
		save.extra_food = 0
		save.extra_potion = 0
	visited_deepest = 1


func add_item(it: ItemData) -> bool:
	if it == null:
		return false
	if it.kind == ItemData.Kind.MATERIAL or it.kind == ItemData.Kind.CONSUMABLE:
		for i in BAG_SIZE:
			var mar := bag[i] as ItemData
			if mar and mar.stacks_with(it):
				var room := 50 - mar.count
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


func consume_family(family: String) -> ItemData:
	for i in BAG_SIZE:
		var it: ItemData = bag[i]
		if it and it.family == family:
			return remove_item_at(i, 1)
	return null
