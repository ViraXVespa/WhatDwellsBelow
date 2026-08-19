class_name ItemData
extends RefCounted

enum Kind { WEAPON, TOOL, OFFHAND, ARMOR, MATERIAL, CONSUMABLE }
enum Rarity { WHITE, GREEN, BLUE, PURPLE, ORANGE }

var kind: Kind = Kind.MATERIAL
var family: String = ""
var rarity: Rarity = Rarity.WHITE
var prefix: String = ""
var suffix: String = ""
var count: int = 1
var damage: float = 0.0
var attack_period: float = 0.7
var gather_mult: float = 1.0
var heal: float = 0.0
var forged: bool = false
var unique_id: int = 0

static var _id_seq: int = 1


static func next_id() -> int:
	_id_seq += 1
	return _id_seq


func _init() -> void:
	unique_id = next_id()


func full_name() -> String:
	var base := _family_name()
	if prefix != "":
		base = prefix + " " + base
	if suffix != "":
		base = base + " " + suffix
	if count > 1 and kind != Kind.WEAPON and kind != Kind.TOOL:
		base += " x%d" % count
	return base


func _family_name() -> String:
	match family:
		"great_axe":
			return "Great Axe"
		"pickaxe":
			return "Pickaxe"
		"ore":
			return "Ore"
		"food":
			return "Ration"
		"potion":
			return "Potion"
		"bar":
			return "Metal Bar"
		_:
			return family.capitalize()


func stacks_with(other: ItemData) -> bool:
	if other == null:
		return false
	if kind in [Kind.WEAPON, Kind.TOOL, Kind.OFFHAND, Kind.ARMOR]:
		return false
	return family == other.family and kind == other.kind


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"family": family,
		"rarity": rarity,
		"prefix": prefix,
		"suffix": suffix,
		"count": count,
		"damage": damage,
		"attack_period": attack_period,
		"gather_mult": gather_mult,
		"heal": heal,
		"forged": forged,
		"unique_id": unique_id,
	}


static func from_dict(d: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.kind = int(d.get("kind", 0)) as Kind
	it.family = str(d.get("family", ""))
	it.rarity = int(d.get("rarity", 0)) as Rarity
	it.prefix = str(d.get("prefix", ""))
	it.suffix = str(d.get("suffix", ""))
	it.count = int(d.get("count", 1))
	it.damage = float(d.get("damage", 0.0))
	it.attack_period = float(d.get("attack_period", 0.7))
	it.gather_mult = float(d.get("gather_mult", 1.0))
	it.heal = float(d.get("heal", 0.0))
	it.forged = bool(d.get("forged", false))
	it.unique_id = int(d.get("unique_id", next_id()))
	return it


static func make_ore(amount: int = 1) -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.MATERIAL
	it.family = "ore"
	it.count = amount
	return it


static func make_food(amount: int = 1) -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.CONSUMABLE
	it.family = "food"
	it.count = amount
	it.heal = 30.0
	return it


static func make_potion(amount: int = 1) -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.CONSUMABLE
	it.family = "potion"
	it.count = amount
	it.heal = 50.0
	return it


static func make_starter_axe() -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.WEAPON
	it.family = "great_axe"
	it.rarity = Rarity.WHITE
	it.prefix = "Plain"
	it.damage = 14.0
	it.attack_period = 0.72
	it.forged = true
	return it


static func make_starter_pickaxe() -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.TOOL
	it.family = "pickaxe"
	it.rarity = Rarity.WHITE
	it.prefix = "Plain"
	it.gather_mult = 1.0
	it.forged = true
	return it
