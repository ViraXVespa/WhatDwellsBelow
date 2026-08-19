class_name LootGen
extends Object

const WHITE_PREFIXES := ["Rusty", "Worn", "Crude", "Plain", "Nicked"]
const GREEN_PREFIXES := ["Keen", "Heavy", "Balanced", "Notched", "Hardy"]
const GREEN_SUFFIXES := ["of Iron", "of Oak", "of Bite", "of Weight", "of the Rat"]


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
	return it
