extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")


static func make_weapon(p: Object, wpn: String, rarity: String) -> Dictionary:
	var n: String = "Great Axe"
	if wpn == "staff":
		n = "Lightning Staff"
	elif wpn == "longbow":
		n = "Longbow"
	var dmg: int = int(App.bal.gear_white_dmg)
	if rarity == "green":
		dmg = int(App.bal.gear_green_dmg)
	elif rarity == "blue":
		dmg = int(App.bal.gear_blue_dmg)
	return item(p, "weapon", n, {"slot": "weapon", "weapon": wpn, "rarity": rarity, "dmg": dmg, "desc": "%s %s. +%d damage." % [rarity.capitalize(), n, dmg]})


static func make_tool(p: Object, kind: String) -> Dictionary:
	var n: String = "Pickaxe" if kind == "pickaxe" else "Hatchet"
	return item(p, "tool", n, {"slot": "tool", "tool": kind, "rarity": "white", "desc": "Run tool. Locked to %s." % kind})


static func make_armor(p: Object, slot: String, rarity: String) -> Dictionary:
	var def: int = int(App.bal.gear_white_def)
	var hp: int = int(App.bal.gear_white_hp)
	if rarity == "green":
		def = int(App.bal.gear_green_def)
		hp = int(App.bal.gear_green_hp)
	elif rarity == "blue":
		def = int(App.bal.gear_blue_def)
		hp = int(App.bal.gear_blue_hp)
	return item(p, slot, "%s %s" % [rarity.capitalize(), slot.capitalize()], {"slot": slot, "rarity": rarity, "def": def, "hp": hp, "desc": "+%d def, +%d HP." % [def, hp]})


static func make_potion(p: Object, n: int) -> Dictionary:
	return item(p, "potion", "Potion", {"slot": "potion", "stack": n, "desc": "Instant heal."})


static func make_food(p: Object, fid: String, n: int) -> Dictionary:
	var nm: String = "Ration" if fid == "ration" else "Trail Bread"
	return item(p, "food", nm, {"slot": "food", "food": fid, "stack": n, "desc": "Heal-over-time."})


static func make_artifact(p: Object, id: String) -> Dictionary:
	var a: Dictionary = CatalogS.by_id(id)
	if a.is_empty():
		a = {"id": id, "name": id, "set": "", "desc": "A curious relic."}
	return item(p, "artifact", str(a.name), {"id": id, "set": str(a.get("set", "")), "desc": str(a.get("desc", "A run-only relic.")), "extract": false})


static func item(p: Object, kind: String, name: String, extra: Dictionary) -> Dictionary:
	var it: Dictionary = {
		"uid": p.next_uid,
		"id": kind + "_" + str(p.next_uid),
		"name": name,
		"kind": kind,
		"slot": extra.get("slot", kind),
		"weapon": extra.get("weapon", ""),
		"tool": extra.get("tool", ""),
		"food": extra.get("food", ""),
		"set": extra.get("set", ""),
		"rarity": extra.get("rarity", "white"),
		"desc": extra.get("desc", ""),
		"stack": extra.get("stack", 1),
		"dmg": extra.get("dmg", 0),
		"def": extra.get("def", 0),
		"hp": extra.get("hp", 0),
		"extract": extra.get("extract", kind != "artifact"),
		"hold": false,
	}
	if extra.has("id"):
		it.id = str(extra.id)
	p.next_uid += 1
	return it


static func starter(p: Object, slot: String) -> Dictionary:
	match slot:
		"weapon":
			return make_weapon(p, "great_axe", "white")
		"tool":
			return make_tool(p, p.tool_type)
		"potion":
			return make_potion(p, 3)
		"food":
			return make_food(p, "ration", 5)
		_:
			return {}
