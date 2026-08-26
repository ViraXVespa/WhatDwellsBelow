class_name ItemData
extends RefCounted

enum Kind { WEAPON, TOOL, OFFHAND, ARMOR, MATERIAL, CONSUMABLE, POTION }
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
var armor_slot: String = ""
var defense: float = 0.0
var bonus_key: String = ""
var bonus_val: float = 0.0
var potion_cd: float = 8.0
var potion_cdr: float = 0.0
var forged_once: bool = false

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
	if count > 1 and kind in [Kind.MATERIAL, Kind.CONSUMABLE]:
		base += " x%d" % count
	return base


func stat_line() -> String:
	var bits: PackedStringArray = []
	match kind:
		Kind.WEAPON:
			bits.append("%.0f dmg" % damage)
		Kind.TOOL:
			bits.append("mine x%.2f" % gather_mult)
		Kind.ARMOR:
			bits.append("Def %.0f" % defense)
			if bonus_key != "" and bonus_val != 0.0:
				bits.append(_bonus_label())
		Kind.POTION:
			bits.append("heal %.0f" % heal)
			bits.append("cd %.1fs" % potion_cd)
			if potion_cdr > 0.0:
				bits.append("CDR %d%%" % int(potion_cdr * 100.0))
		Kind.CONSUMABLE:
			bits.append("heal %.0f" % heal)
	if rarity == Rarity.GREEN:
		bits.append("green")
	return "  ·  ".join(bits)


func _bonus_label() -> String:
	match bonus_key:
		"hp":
			return "+%d HP" % int(bonus_val)
		"speed":
			return "+%d%% speed" % int(bonus_val * 100.0)
		"gold":
			return "+%d%% gold" % int(bonus_val * 100.0)
		"mine":
			return "+%d%% mine" % int(bonus_val * 100.0)
		_:
			return bonus_key


func hold_key() -> String:
	if kind == Kind.ARMOR:
		return armor_slot if armor_slot != "" else "body"
	if kind == Kind.POTION:
		return "potion"
	return family


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
		"head":
			return "Helm"
		"body":
			return "Mail"
		"legs":
			return "Greaves"
		"bar":
			return "Metal Bar"
		_:
			return family.capitalize()


func stacks_with(other: ItemData) -> bool:
	if other == null:
		return false
	if kind in [Kind.WEAPON, Kind.TOOL, Kind.OFFHAND, Kind.ARMOR, Kind.POTION]:
		return false
	if family == "potion":
		return false
	return family == other.family and kind == other.kind


func stack_cap() -> int:
	if family == "food":
		return 20
	if kind == Kind.MATERIAL:
		return 99999
	return 20


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
		"armor_slot": armor_slot,
		"defense": defense,
		"bonus_key": bonus_key,
		"bonus_val": bonus_val,
		"potion_cd": potion_cd,
		"potion_cdr": potion_cdr,
		"forged_once": forged_once,
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
	it.armor_slot = str(d.get("armor_slot", ""))
	it.defense = float(d.get("defense", 0.0))
	it.bonus_key = str(d.get("bonus_key", ""))
	it.bonus_val = float(d.get("bonus_val", 0.0))
	it.potion_cd = float(d.get("potion_cd", 8.0))
	it.potion_cdr = float(d.get("potion_cdr", 0.0))
	it.forged_once = bool(d.get("forged_once", it.forged))
	if it.family == "potion" and it.kind == Kind.CONSUMABLE:
		it.kind = Kind.POTION
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
	it.kind = Kind.POTION
	it.family = "potion"
	it.count = 1
	it.heal = 50.0
	it.potion_cd = 8.0
	it.prefix = "Plain"
	it.forged = true
	it.forged_once = true
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
	it.forged_once = true
	return it


static func make_starter_pickaxe() -> ItemData:
	var it := ItemData.new()
	it.kind = Kind.TOOL
	it.family = "pickaxe"
	it.rarity = Rarity.WHITE
	it.prefix = "Plain"
	it.gather_mult = 1.0
	it.forged = true
	it.forged_once = true
	return it


func duplicate_item() -> ItemData:
	var it := from_dict(to_dict())
	it.unique_id = next_id()
	return it
