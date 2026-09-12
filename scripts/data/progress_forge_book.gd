extends Object

const Affix := preload("res://scripts/data/affixes.gd")

const FORGE_SLOTS: PackedStringArray = ["weapon", "tool", "head", "body", "legs"]


static func book(p: Object) -> Dictionary:
	var raw: Variant = p.get("forge_book")
	if raw is Dictionary:
		return raw
	p.set("forge_book", {})
	return p.forge_book


static func entry(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	var raw: Variant = book(p).get(Affix.book_key(slot, type_id, rarity), {})
	if raw is Dictionary:
		return raw
	return {}


static func unlocks_for(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	var ent: Dictionary = entry(p, slot, type_id, rarity)
	var ids := PackedStringArray()
	for raw: Variant in ent.get("ids", []):
		var id := str(raw)
		if id != "":
			ids.append(id)
	var lucks: Dictionary = {}
	var src: Variant = ent.get("luck", {})
	if src is Dictionary:
		lucks = src
	var peak := 0.75
	for v: Variant in lucks.values():
		peak = maxf(peak, float(v))
	return {
		"ids": ids,
		"traits": ids,
		"luck": peak,
		"luck_by_id": lucks,
		"ilvl": int(ent.get("ilvl", 0)),
	}


static func max_ilvl_rarity(p: Object, slot: String, type_id: String, rarity: String) -> int:
	return int(entry(p, slot, type_id, rarity).get("ilvl", 0))


static func max_ilvl_type(p: Object, slot: String, type_id: String) -> int:
	return maxi(max_ilvl_rarity(p, slot, type_id, "green"), max_ilvl_rarity(p, slot, type_id, "blue"))


static func max_ilvl(p: Object, slot: String, type_id: String) -> int:
	return max_ilvl_type(p, slot, type_id)


static func types_for(p: Object, slot: String) -> PackedStringArray:
	var seen: Dictionary = {}
	for k: Variant in book(p).keys():
		var parts: PackedStringArray = str(k).split(":")
		if parts.size() >= 2 and parts[0] == slot and parts[1] != "":
			seen[parts[1]] = true
	var out := PackedStringArray()
	for id: Variant in seen.keys():
		out.append(str(id))
	return out


static func can_forge_rarity(p: Object, slot: String, type_id: String, rarity: String) -> bool:
	return rarity != "white" and max_ilvl_rarity(p, slot, type_id, rarity) > 0


static func can_analyze(p: Object, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if str(it.get("kind", "")) == "artifact":
		return false
	if bool(it.get("hold", false)) or str(it.get("kit_src", "")) == "hold":
		return false
	var slot := str(it.get("slot", ""))
	if FORGE_SLOTS.find(slot) < 0:
		return false
	if str(it.get("rarity", "white")) == "white":
		return false
	var Rules = load("res://scripts/data/gear_rules.gd")
	if Rules.is_starter(p, it):
		return false
	return true


static func is_duplicate(p: Object, it: Dictionary) -> bool:
	if it.is_empty() or not can_analyze(p, it):
		return false
	var slot := str(it.get("slot", ""))
	var type_id := type_of(it)
	var rarity := str(it.get("rarity", "white"))
	if type_id == "":
		return false
	if int(it.get("ilvl", 1)) > max_ilvl_type(p, slot, type_id):
		return false
	if max_ilvl_type(p, slot, type_id) <= 0:
		return false
	var ent: Dictionary = entry(p, slot, type_id, rarity)
	if int(ent.get("ilvl", 0)) <= 0:
		return false
	var traits: Array = _traits_of(it)
	if traits.is_empty():
		return false
	var lucks: Dictionary = {}
	var raw_l: Variant = ent.get("luck", {})
	if raw_l is Dictionary:
		lucks = raw_l
	var ids: Array = ent.get("ids", [])
	for row: Variant in traits:
		if not (row is Dictionary):
			return false
		var id := str(row.get("id", ""))
		if id == "" or ids.find(id) < 0:
			return false
		if float(lucks.get(id, 0.0)) < float(row.get("luck", 0.0)):
			return false
	return true


static func grant(p: Object, it: Dictionary) -> void:
	if it.is_empty():
		return
	var slot := str(it.get("slot", ""))
	var type_id := type_of(it)
	var rarity := str(it.get("rarity", "white"))
	if type_id == "" or rarity == "white":
		return
	var ent: Dictionary = entry(p, slot, type_id, rarity).duplicate(true)
	if ent.is_empty():
		ent = {"ilvl": 0, "ids": [], "luck": {}}
	ent["ilvl"] = maxi(int(ent.get("ilvl", 0)), maxi(1, int(it.get("ilvl", 1))))
	var ids: Array = []
	for raw_id: Variant in ent.get("ids", []):
		ids.append(str(raw_id))
	var lucks: Dictionary = {}
	var raw_l: Variant = ent.get("luck", {})
	if raw_l is Dictionary:
		lucks = raw_l.duplicate(true)
	var prim := Affix.primary_id(slot)
	if prim != "" and ids.find(prim) < 0:
		ids.append(prim)
	for row: Variant in _traits_of(it):
		if not (row is Dictionary):
			continue
		var id := str(row.get("id", ""))
		if id == "":
			continue
		if ids.find(id) < 0:
			ids.append(id)
		lucks[id] = maxf(float(lucks.get(id, 0.0)), float(row.get("luck", 0.0)))
	ent["ids"] = ids
	ent["luck"] = lucks
	var b: Dictionary = book(p)
	b[Affix.book_key(slot, type_id, rarity)] = ent
	p.set("forge_book", b)


static func migrate(p: Object) -> void:
	var old: Variant = p.get("analyzed")
	if not (old is Array) or old.is_empty():
		return
	for raw: Variant in old:
		if raw is Dictionary:
			grant(p, raw)
	p.analyzed = []


static func type_of(it: Dictionary) -> String:
	return Affix.type_of(it)


static func _type_of(it: Dictionary) -> String:
	return Affix.type_of(it)


static func _stat_key(id: String) -> String:
	return Affix.stat_key(id)


static func _traits_of(it: Dictionary) -> Array:
	var raw: Variant = it.get("affixes", [])
	if raw is Array and not raw.is_empty():
		return raw
	var slot := str(it.get("slot", ""))
	var prim := Affix.primary_id(slot)
	if prim == "":
		return []
	return [{"id": prim, "role": "primary", "luck": float(it.get("luck", 0.75)), "value": float(it.get(_stat_key(prim), 0.0))}]
