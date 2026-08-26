class_name LootGen
extends RefCounted

const SkillMath := preload("res://scripts/data/skills.gd")

const WHITE_PREFIXES := ["Rusty", "Worn", "Crude", "Plain", "Nicked"]
const GREEN_PREFIXES := ["Keen", "Heavy", "Balanced", "Notched", "Hardy"]
const GREEN_SUFFIXES := ["of Iron", "of Oak", "of Bite", "of Weight", "of the Rat"]
const ARMOR_BONUSES := ["hp", "speed", "gold", "mine"]


static func roll_gear(family: String, rng: RandomNumberGenerator) -> ItemData:
	var it := ItemData.new()
	var green := rng.randf() < 0.18
	it.rarity = ItemData.Rarity.GREEN if green else ItemData.Rarity.WHITE
	it.family = family
	if family == "great_axe":
		it.kind = ItemData.Kind.WEAPON
		it.attack_period = 0.72
		if green:
			it.prefix = GREEN_PREFIXES[rng.randi_range(0, GREEN_PREFIXES.size() - 1)]
			it.suffix = GREEN_SUFFIXES[rng.randi_range(0, GREEN_SUFFIXES.size() - 1)]
			it.damage = rng.randf_range(18.0, 24.0)
			it.attack_period = rng.randf_range(0.64, 0.74)
		else:
			it.prefix = WHITE_PREFIXES[rng.randi_range(0, WHITE_PREFIXES.size() - 1)]
			it.damage = rng.randf_range(12.0, 16.5)
	elif family == "pickaxe":
		it.kind = ItemData.Kind.TOOL
		if green:
			it.prefix = GREEN_PREFIXES[rng.randi_range(0, GREEN_PREFIXES.size() - 1)]
			it.suffix = GREEN_SUFFIXES[rng.randi_range(0, GREEN_SUFFIXES.size() - 1)]
			it.gather_mult = rng.randf_range(1.15, 1.35)
		else:
			it.prefix = WHITE_PREFIXES[rng.randi_range(0, WHITE_PREFIXES.size() - 1)]
			it.gather_mult = rng.randf_range(0.95, 1.08)
	elif family in ["head", "body", "legs"]:
		it.kind = ItemData.Kind.ARMOR
		it.armor_slot = family
		if green:
			it.prefix = GREEN_PREFIXES[rng.randi_range(0, GREEN_PREFIXES.size() - 1)]
			it.suffix = GREEN_SUFFIXES[rng.randi_range(0, GREEN_SUFFIXES.size() - 1)]
			it.defense = rng.randf_range(7.0, 12.0)
			it.bonus_key = ARMOR_BONUSES[rng.randi_range(0, ARMOR_BONUSES.size() - 1)]
			match it.bonus_key:
				"hp":
					it.bonus_val = float(rng.randi_range(6, 12))
				"speed":
					it.bonus_val = rng.randf_range(0.04, 0.08)
				"gold":
					it.bonus_val = rng.randf_range(0.06, 0.12)
				"mine":
					it.bonus_val = rng.randf_range(0.05, 0.10)
		else:
			it.prefix = WHITE_PREFIXES[rng.randi_range(0, WHITE_PREFIXES.size() - 1)]
			it.defense = rng.randf_range(3.0, 6.0)
	elif family == "potion":
		it.kind = ItemData.Kind.POTION
		it.family = "potion"
		if green:
			it.prefix = GREEN_PREFIXES[rng.randi_range(0, GREEN_PREFIXES.size() - 1)]
			it.suffix = GREEN_SUFFIXES[rng.randi_range(0, GREEN_SUFFIXES.size() - 1)]
			it.heal = rng.randf_range(58.0, 72.0)
			it.potion_cd = rng.randf_range(6.2, 7.6)
			it.potion_cdr = rng.randf_range(0.08, 0.18)
		else:
			it.prefix = WHITE_PREFIXES[rng.randi_range(0, WHITE_PREFIXES.size() - 1)]
			it.heal = rng.randf_range(46.0, 54.0)
			it.potion_cd = rng.randf_range(7.4, 8.6)
	return it


static func roll_any(rng: RandomNumberGenerator) -> ItemData:
	var roll := rng.randf()
	if roll < 0.34:
		return roll_gear("great_axe", rng)
	if roll < 0.52:
		return roll_gear("pickaxe", rng)
	if roll < 0.66:
		return roll_gear("potion", rng)
	var slots: PackedStringArray = ["head", "body", "legs"]
	return roll_gear(slots[rng.randi_range(0, 2)], rng)


static func forge_cost(it: ItemData, first: bool, smith_lv: int = 1) -> Dictionary:
	var gold := 12
	var ore := 2
	if it == null:
		return {"gold": gold, "ore": ore}
	if it.rarity == ItemData.Rarity.GREEN:
		gold = 40
		ore = 8
	else:
		gold = 15
		ore = 3
	if it.kind == ItemData.Kind.ARMOR:
		gold += 4
		ore += 1
	if not first:
		gold = int(ceil(float(gold) * 0.7))
		ore = maxi(1, int(ceil(float(ore) * 0.7)))
	var m: float = SkillMath.smith_cost_mult(maxi(1, smith_lv))
	gold = maxi(1, int(ceil(float(gold) * m)))
	ore = maxi(1, int(ceil(float(ore) * m)))
	return {"gold": gold, "ore": ore}
