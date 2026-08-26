class_name RunState
extends RefCounted

const SkillMath := preload("res://scripts/data/skills.gd")

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
var strength_xp_run: float = 0.0
var defense_xp_run: float = 0.0
var hitpoints_xp_run: float = 0.0
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
var saw_stairs: bool = false
var guardian_low: bool = false


func _init() -> void:
	bag.resize(BAG_SIZE)
	for i in BAG_SIZE:
		bag[i] = null


func setup(save: SaveData, chosen: Dictionary) -> void:
	weapon = _copy_item(chosen.get("weapon", null))
	if weapon == null:
		weapon = ItemData.make_starter_axe()
	tool = _copy_item(chosen.get("tool", null))
	if tool == null:
		tool = ItemData.make_starter_pickaxe()
	potion = _copy_item(chosen.get("potion", null))
	if potion == null and save:
		var pots: Array = save.holds_of("potion")
		if not pots.is_empty():
			potion = _copy_item(pots[pots.size() - 1])
	armor_head = _copy_item(chosen.get("head", null))
	armor_body = _copy_item(chosen.get("body", null))
	armor_legs = _copy_item(chosen.get("legs", null))
	refresh_max_hp(true)
	mana = max_mana
	gold = 0
	seed_value = randi()
	var food_n := save.extra_food if save else 0
	if food_n > 0:
		add_item(ItemData.make_food(food_n))
	if save:
		save.extra_food = 0
		if save.extra_potion > 0:
			for _i in save.extra_potion:
				add_item(ItemData.make_potion())
			save.extra_potion = 0
	visited_deepest = 1
	_apply_armor_non_hp()


func _copy_item(it) -> ItemData:
	if it is ItemData:
		var c := (it as ItemData).duplicate_item()
		c.unique_id = it.unique_id
		return c
	return null


func _apply_armor_non_hp() -> void:
	move_mult = 1.0
	gold_mult = 1.0
	mine_mult = 1.0
	dash_cd_mult = 1.0
	slam_dmg_mult = 1.0
	dmg_mult = 1.0
	lucky_mine = false
	if artifact_ids.has("fleet_foot"):
		move_mult *= 1.12
	if artifact_ids.has("deep_pockets"):
		gold_mult *= 1.25
	if artifact_ids.has("quick_vein"):
		mine_mult *= 1.2
	if artifact_ids.has("short_fuse"):
		dash_cd_mult *= 0.85
	if artifact_ids.has("heavy_hands"):
		slam_dmg_mult *= 1.2
	if artifact_ids.has("iron_appetite"):
		dmg_mult *= 1.15
	if artifact_ids.has("lucky_spark"):
		lucky_mine = true
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
	refresh_max_hp(false)


func armor_bonus_sum(key: String) -> float:
	var t := 0.0
	for it in [armor_head, armor_body, armor_legs]:
		if it and it.bonus_key == key:
			t += it.bonus_val
	return t


func refresh_max_hp(fill: bool = false) -> void:
	var old := max_hp
	max_hp = 100.0 + armor_bonus_sum("hp") + SkillMath.hitpoints_bonus(Game.skill_level("hitpoints"))
	if artifact_ids.has("second_wind"):
		max_hp += 20.0
	if fill:
		hp = max_hp
	elif max_hp > old:
		hp += max_hp - old
	hp = minf(hp, max_hp)


func total_defense() -> float:
	var d := 0.0
	for it in [armor_head, armor_body, armor_legs]:
		if it:
			d += it.defense
	d += SkillMath.defense_points(Game.skill_level("defense"))
	return d


func xp_run_of(skill: String) -> float:
	match skill:
		"mining":
			return mining_xp_run
		"smithing":
			return smithing_xp_run
		"great_axe":
			return great_axe_xp_run
		"strength":
			return strength_xp_run
		"defense":
			return defense_xp_run
		"hitpoints":
			return hitpoints_xp_run
		_:
			return 0.0


func add_xp_run(skill: String, n: float) -> void:
	match skill:
		"mining":
			mining_xp_run += n
		"smithing":
			smithing_xp_run += n
		"great_axe":
			great_axe_xp_run += n
		"strength":
			strength_xp_run += n
		"defense":
			defense_xp_run += n
		"hitpoints":
			hitpoints_xp_run += n


func food_count() -> int:
	var n := 0
	for it in bag:
		if it and it.family == "food":
			n += it.count
	return n


func add_item(it: ItemData) -> bool:
	if it == null:
		return false
	if it.family == "food":
		var room := 20 - food_count()
		if room <= 0:
			return false
		if it.count > room:
			it.count = room
	var stackable := it.kind == ItemData.Kind.MATERIAL or (it.kind == ItemData.Kind.CONSUMABLE and it.family == "food")
	if stackable:
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
		while it.count > 0:
			var put := mini(it.count, it.stack_cap())
			var slot := -1
			for i in BAG_SIZE:
				if bag[i] == null:
					slot = i
					break
			if slot < 0:
				return false
			if put == it.count:
				bag[slot] = it
				return true
			var part := ItemData.from_dict(it.to_dict())
			part.count = put
			part.unique_id = ItemData.next_id()
			bag[slot] = part
			it.count -= put
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
	_apply_armor_non_hp()
	return true
