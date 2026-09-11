extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")
const Roll := preload("res://scripts/data/gear_roll.gd")


static func make_weapon(p: Object, wpn: String, rarity: String, ilvl: int = 0) -> Dictionary:
	var n: String = "Great Axe"
	if wpn == "staff":
		n = "Lightning Staff"
	elif wpn == "longbow":
		n = "Longbow"
	var it: Dictionary = item(p, "weapon", n, {
		"slot": "weapon",
		"weapon": wpn,
		"rarity": rarity,
		"desc": "%s %s." % [rarity.capitalize(), n],
	})
	return _roll_onto(it, "weapon", wpn, rarity, ilvl)


static func make_tool(p: Object, kind: String, rarity: String = "white", ilvl: int = 0) -> Dictionary:
	var n: String = "Pickaxe" if kind == "pickaxe" else "Hatchet"
	var it: Dictionary = item(p, "tool", n, {
		"slot": "tool",
		"tool": kind,
		"rarity": rarity,
		"desc": "Run tool. Locked to %s." % kind,
	})
	return _roll_onto(it, "tool", kind, rarity, ilvl)


static func make_armor(p: Object, slot: String, rarity: String, ilvl: int = 0) -> Dictionary:
	var it: Dictionary = item(p, slot, "%s %s" % [rarity.capitalize(), slot.capitalize()], {
		"slot": slot,
		"rarity": rarity,
		"desc": "%s %s." % [rarity.capitalize(), slot.capitalize()],
	})
	return _roll_onto(it, slot, slot, rarity, ilvl)


static func make_potion(p: Object, n: int) -> Dictionary:
	var charges: int = n if n > 0 else 2
	var cd: float = 8.0
	if App.bal and App.bal.get("potion_cooldown") != null:
		cd = float(App.bal.potion_cooldown)
	return item(p, "potion", "Potion", {
		"slot": "potion",
		"stack": 1,
		"charges": charges,
		"charge_max": charges,
		"cooldown": cd,
		"desc": "Instant heal. %d charges per run." % charges,
	})


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
		"ilvl": int(extra.get("ilvl", 1)),
		"quality": float(extra.get("quality", 1.0)),
		"affixes": extra.get("affixes", []),
		"extract": extra.get("extract", kind != "artifact"),
		"hold": false,
		"charges": int(extra.get("charges", 0)),
		"charge_max": int(extra.get("charge_max", extra.get("charges", 0))),
		"cooldown": float(extra.get("cooldown", 0.0)),
	}
	if extra.has("id"):
		it.id = str(extra.id)
	p.next_uid += 1
	return it


static func starter(p: Object, slot: String) -> Dictionary:
	match slot:
		"weapon":
			return make_weapon(p, "great_axe", "white", 1)
		"tool":
			return make_tool(p, p.tool_type, "white", 1)
		"potion":
			return make_potion(p, 2)
		"food":
			return make_food(p, "ration", 5)
		_:
			return {}


static func _roll_onto(it: Dictionary, slot: String, type_id: String, rarity: String, ilvl: int) -> Dictionary:
	var lv: int = ilvl if ilvl > 0 else _area_ilvl()
	return Roll.stamp(it, Roll.roll_dungeon(slot, type_id, rarity, lv))


static func _area_ilvl() -> int:
	var floor_n: int = 1
	if App.get("floor_n") != null:
		floor_n = maxi(1, int(App.floor_n))
	var per: float = 5.0
	var pct: float = 0.86
	if App.bal != null:
		if App.bal.get("enemy_cl_per_floor") != null:
			per = float(App.bal.enemy_cl_per_floor)
		if App.bal.get("enemy_cl_end_pct") != null:
			pct = float(App.bal.enemy_cl_end_pct)
	return maxi(1, int(round(float(floor_n) * per * pct)))
