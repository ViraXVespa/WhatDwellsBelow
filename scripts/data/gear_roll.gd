extends Object

const Affix := preload("res://scripts/data/affixes.gd")


static func roll_dungeon(slot: String, type_id: String, rarity: String, ilvl: int) -> Dictionary:
	var lv: int = maxi(1, ilvl)
	return _build(slot, type_id, rarity, lv, randf_range(0.5, 1.0), randf_range(0.75, 1.0), PackedStringArray(), {}, false)


static func roll_forge(
	slot: String,
	type_id: String,
	rarity: String,
	ilvl: int,
	smith_lv: int,
	locked: PackedStringArray,
	unlocks: Dictionary,
) -> Dictionary:
	var lv: int = maxi(1, ilvl)
	var max_luck: float = maxf(0.75, float(unlocks.get("luck", 0.75)))
	var min_luck: float = maxf(0.75, max_luck - 0.25)
	var luck: float = randf_range(min_luck, max_luck)
	var quality: float = randf_range(0.5, 1.0)
	if smith_lv >= lv:
		quality = minf(1.0, quality + 0.08 * float(smith_lv - lv + 1))
	else:
		quality = maxf(0.35, quality - 0.06 * float(lv - smith_lv))
	return _build(slot, type_id, rarity, lv, quality, luck, locked, unlocks, true)


static func stamp(it: Dictionary, rolled: Dictionary) -> Dictionary:
	for k: Variant in rolled.keys():
		it[k] = rolled[k]
	return it


static func _build(
	slot: String,
	type_id: String,
	rarity: String,
	ilvl: int,
	quality: float,
	luck: float,
	locked: PackedStringArray,
	unlocks: Dictionary,
	from_forge: bool,
) -> Dictionary:
	var it: Dictionary = {
		"slot": slot,
		"rarity": rarity,
		"ilvl": ilvl,
		"quality": quality,
		"luck": luck,
		"hold": from_forge,
		"kit_src": "hold" if from_forge else "",
		"affixes": [],
	}
	if slot == "weapon":
		it["weapon"] = type_id
		it["name"] = _wpn_name(type_id)
	elif slot == "tool":
		it["tool"] = type_id
		it["name"] = type_id.capitalize()
	else:
		it["name"] = slot.capitalize()
	if from_forge:
		it["name"] = "Forged " + str(it.get("name", "item"))
	var ids: PackedStringArray = _pick_ids(slot, rarity, locked, unlocks, from_forge)
	var rows: Array = []
	for id: String in ids:
		var val: float = _roll_value(id, ilvl, quality, luck)
		rows.append({"id": id, "value": val})
		it[id] = val
	it["affixes"] = rows
	it["dmg"] = int(round(float(it.get(Affix.ID_DMG, 0.0))))
	it["def"] = int(round(float(it.get(Affix.ID_DEF, 0.0))))
	it["hp"] = int(round(float(it.get(Affix.ID_HP, 0.0))))
	return it


static func _pick_ids(
	slot: String,
	rarity: String,
	locked: PackedStringArray,
	unlocks: Dictionary,
	from_forge: bool,
) -> PackedStringArray:
	var out := PackedStringArray()
	var used: Dictionary = {}
	var prim := Affix.primary_id(slot)
	out.append(prim)
	used[prim] = true
	var bonus_n := 0 if rarity == "white" else (1 if rarity == "green" else 2)
	var pool: Array = []
	for id: String in Affix.bonus_pool(slot):
		pool.append(id)
	if from_forge:
		var known: PackedStringArray = PackedStringArray()
		var raw_ids: Variant = unlocks.get("traits", unlocks.get("ids", []))
		if raw_ids is PackedStringArray:
			known = raw_ids
		elif raw_ids is Array:
			for x: Variant in raw_ids:
				known.append(str(x))
		var trimmed: Array = []
		for id: String in pool:
			if id in known or id == Affix.ID_DMG or id == Affix.ID_DEF:
				trimmed.append(id)
		if not trimmed.is_empty():
			pool = trimmed
	for id: String in locked:
		if used.has(id):
			continue
		if out.size() >= 1 + bonus_n:
			break
		out.append(id)
		used[id] = true
	pool.shuffle()
	for id3: Variant in pool:
		var id := str(id3)
		if used.has(id):
			continue
		if out.size() >= 1 + bonus_n:
			break
		out.append(id)
		used[id] = true
	return out


static func _roll_value(id: String, ilvl: int, quality: float, luck: float) -> float:
	var q: float = clampf(quality, 0.35, 1.25)
	var lk: float = clampf(luck, 0.5, 1.25)
	if Affix.kind_of(id) == Affix.KIND_PCT:
		return (0.02 + _bal("affix_pct_per_lv", 0.004) * float(ilvl)) * q * lk
	return (_bal("affix_flat_base", 2.0) + _bal("affix_flat_per_lv", 0.65) * float(ilvl)) * q * lk


static func _wpn_name(type_id: String) -> String:
	match type_id:
		"great_axe":
			return "Great Axe"
		"staff":
			return "Staff"
		"longbow":
			return "Longbow"
		_:
			return type_id.capitalize()


static func _bal(key: String, fallback: float) -> float:
	if App.bal != null and App.bal.get(key) != null:
		return float(App.bal.get(key))
	return fallback
