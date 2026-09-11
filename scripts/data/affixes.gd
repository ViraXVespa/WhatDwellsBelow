extends Object

const GROUP_COMBAT := "combat"
const GROUP_TOOL := "tool"
const KIND_FLAT := "flat"
const KIND_PCT := "pct"

const ID_DMG := "dmg"
const ID_DEF := "def"
const ID_HP := "hp"
const ID_CRIT_CHANCE := "crit_chance"
const ID_CRIT_DMG := "crit_dmg"
const ID_MOVE := "move_spd"
const ID_ATK_SPD := "atk_spd"
const ID_ATK_RANGE := "atk_range"
const ID_HP_HIT := "hp_on_hit"
const ID_HP_KILL := "hp_on_kill"
const ID_GATHER_SPD := "gather_spd"
const ID_GATHER_POW := "gather_pow"
const ID_YIELD := "yield_chance"

const FORGE_SLOTS: PackedStringArray = ["weapon", "tool", "head", "body", "legs"]


static func defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_row(ID_DMG, "Damage", KIND_FLAT, GROUP_COMBAT, true))
	out.append(_row(ID_DEF, "Defense", KIND_FLAT, GROUP_COMBAT, true))
	out.append(_row(ID_HP, "Health", KIND_FLAT, GROUP_COMBAT, true))
	out.append(_row(ID_CRIT_CHANCE, "Crit Chance", KIND_PCT, GROUP_COMBAT, false))
	out.append(_row(ID_CRIT_DMG, "Crit Damage", KIND_PCT, GROUP_COMBAT, false))
	out.append(_row(ID_MOVE, "Movement Speed", KIND_PCT, GROUP_COMBAT, false))
	out.append(_row(ID_ATK_SPD, "Attack Speed", KIND_PCT, GROUP_COMBAT, false))
	out.append(_row(ID_ATK_RANGE, "Attack Range", KIND_FLAT, GROUP_COMBAT, false))
	out.append(_row(ID_HP_HIT, "Health on Hit", KIND_FLAT, GROUP_COMBAT, false))
	out.append(_row(ID_HP_KILL, "Health on Kill", KIND_FLAT, GROUP_COMBAT, false))
	out.append(_row(ID_GATHER_SPD, "Gather Speed", KIND_PCT, GROUP_TOOL, true))
	out.append(_row(ID_GATHER_POW, "Gather Power", KIND_FLAT, GROUP_TOOL, false))
	out.append(_row(ID_YIELD, "Yield Chance", KIND_PCT, GROUP_TOOL, false))
	return out


static func _row(id: String, label: String, kind: String, group: String, primary: bool) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"kind": kind,
		"group": group,
		"primary": primary,
	}


static func by_id(id: String) -> Dictionary:
	for row: Dictionary in defs():
		if str(row.get("id", "")) == id:
			return row
	return {}


static func label_of(id: String) -> String:
	var row: Dictionary = by_id(id)
	if row.is_empty():
		return id.capitalize()
	return str(row.get("label", id))


static func kind_of(id: String) -> String:
	var row: Dictionary = by_id(id)
	return str(row.get("kind", KIND_FLAT))


static func stat_key(id: String) -> String:
	return id


static func type_of(it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if slot == "weapon":
		return str(it.get("weapon", ""))
	if slot == "tool":
		return str(it.get("tool", ""))
	return slot


static func primary_id(slot: String) -> String:
	if slot == "tool":
		return ID_GATHER_SPD
	if slot == "weapon":
		return ID_DMG
	if slot == "head" or slot == "body" or slot == "legs":
		return ID_DEF
	return ID_HP


static func bonus_pool(slot: String) -> PackedStringArray:
	var group := GROUP_TOOL if slot == "tool" else GROUP_COMBAT
	var out := PackedStringArray()
	var prim := primary_id(slot)
	for row: Dictionary in defs():
		if str(row.get("group", "")) != group:
			continue
		var id := str(row.get("id", ""))
		if id == prim:
			continue
		out.append(id)
	return out


static func format_value(id: String, value: float) -> String:
	if kind_of(id) == KIND_PCT:
		return "%+.1f%%" % (value * 100.0)
	if is_equal_approx(value, roundf(value)):
		return "%+d" % int(roundf(value))
	return "%+.1f" % value


static func book_key(slot: String, type_id: String, rarity: String) -> String:
	return "%s:%s:%s" % [slot, type_id, rarity]


static func type_label(slot: String, type_id: String) -> String:
	if type_id == "":
		return slot.capitalize()
	return str(type_id).capitalize()
