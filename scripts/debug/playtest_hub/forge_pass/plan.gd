extends Object

## Split from forge_pass.gd: _best_plan, _targets, _plan_slot....

const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Roll := preload("res://scripts/data/gear_roll.gd")
const Affix := preload("res://scripts/data/affixes.gd")

static func _best_plan() -> Dictionary:
	var best: Dictionary = {}
	var best_lv: int = 0
	for spec: PackedStringArray in _targets():
		var plan: Dictionary = _plan_slot(spec[0], spec[1])
		var lv: int = int(plan.get("ilvl", 0))
		if plan.is_empty() or lv <= 0:
			continue
		if best.is_empty() or lv > best_lv:
			best = plan
			best_lv = lv
	return best

static func _targets() -> Array:
	var wpn: String = str(App.prog.pick_weapon)
	var tool_id: String = str(App.prog.tool_type)
	if tool_id == "":
		tool_id = "pickaxe"
	return [
		PackedStringArray(["weapon", wpn]),
		PackedStringArray(["tool", tool_id]),
		PackedStringArray(["head", "head"]),
		PackedStringArray(["body", "body"]),
		PackedStringArray(["legs", "legs"]),
	]

static func _plan_slot(slot_name: String, type_id: String) -> Dictionary:
	if type_id == "":
		return {}
	var green_cap: int = ForgeP.max_ilvl_rarity(App.prog, slot_name, type_id, "green")
	var blue_cap: int = ForgeP.max_ilvl_rarity(App.prog, slot_name, type_id, "blue")
	var top: int = maxi(green_cap, blue_cap)
	var rarity: String = ""
	var ilvl: int = 0
	var lv: int = top
	while lv >= 1:
		var blue_ok: bool = lv <= blue_cap and _payable(slot_name, "blue", lv)
		var green_ok: bool = lv <= green_cap and _payable(slot_name, "green", lv)
		if blue_ok:
			rarity = "blue"
			ilvl = lv
			break
		if green_ok:
			rarity = "green"
			ilvl = lv
			break
		lv -= 1
	if ilvl <= 0:
		return {}
	var worn: Dictionary = {}
	var cur: Variant = App.prog.slots.get(slot_name, {})
	if cur is Dictionary:
		worn = (cur as Dictionary).duplicate(true)
	if not _could_rise(slot_name, type_id, rarity, ilvl, worn):
		return {}
	return {
		"slot": slot_name,
		"type_id": type_id,
		"rarity": rarity,
		"ilvl": ilvl,
		"worn": worn,
	}

static func _payable(slot_name: String, rarity: String, ilvl: int) -> bool:
	return App.prog.can_pay_forge(_bill(slot_name, rarity, ilvl))

static func _bill(slot_name: String, rarity: String, ilvl: int) -> Dictionary:
	var one: Dictionary = App.prog.forge_cost(slot_name, rarity, ilvl, 0)
	return {
		"gold": int(one.get("gold", 0)),
		"ore": int(one.get("ore", 0)),
		"wood": int(one.get("wood", 0)),
	}

static func _could_rise(slot_name: String, type_id: String, rarity: String, ilvl: int, worn: Dictionary) -> bool:
	var worn_lv: int = int(worn.get("ilvl", 0))
	if ilvl > worn_lv:
		return true
	if ilvl < worn_lv:
		return false
	var unlocks: Dictionary = ForgeP.unlocks_for(App.prog, slot_name, type_id, rarity)
	var raw_ids: Variant = unlocks.get("ids", [])
	var ids: Array = []
	if raw_ids is PackedStringArray:
		for id: String in raw_ids:
			ids.append(id)
	elif raw_ids is Array:
		ids = raw_ids
	for id_v: Variant in ids:
		var id: String = str(id_v)
		if id == "" or not _tracked(slot_name, id):
			continue
		if _peak_value(id, ilvl, unlocks) > _affix_value(worn, id):
			return true
	return false

static func _peak_value(id: String, ilvl: int, unlocks: Dictionary) -> float:
	# Same ceiling roll_forge can reach: book luck, quality 1.0 (its randf max).
	var max_luck: float = maxf(0.75, float(unlocks.get("luck", 0.75)))
	var use_luck: float = max_luck
	var by: Variant = unlocks.get("luck_by_id", {})
	if by is Dictionary and (by as Dictionary).has(id):
		use_luck = float((by as Dictionary)[id])
	return Roll._roll_value(id, ilvl, 1.0, use_luck)

static func _beats(forged: Dictionary, worn: Dictionary, slot_name: String) -> bool:
	var new_lv: int = int(forged.get("ilvl", 0))
	var worn_lv: int = int(worn.get("ilvl", 0))
	if new_lv != worn_lv:
		return new_lv > worn_lv
	return _affix_sum(forged, slot_name) > _affix_sum(worn, slot_name)

static func _affix_sum(it: Dictionary, slot_name: String) -> float:
	var total: float = 0.0
	var raw: Variant = it.get("affixes", [])
	if not (raw is Array):
		return total
	for one: Variant in raw:
		if one is Dictionary:
			var id: String = str((one as Dictionary).get("id", ""))
			if _tracked(slot_name, id):
				total += float((one as Dictionary).get("value", 0.0))
	return total

static func _affix_value(it: Dictionary, id: String) -> float:
	var raw: Variant = it.get("affixes", [])
	if raw is Array:
		for one: Variant in raw:
			if one is Dictionary and str((one as Dictionary).get("id", "")) == id:
				return float((one as Dictionary).get("value", 0.0))
	return float(it.get(id, 0.0))

static func _tracked(slot_name: String, id: String) -> bool:
	var want: String = Affix.GROUP_TOOL if slot_name == "tool" else Affix.GROUP_COMBAT
	for row: Dictionary in Affix.defs():
		if str(row.get("id", "")) == id:
			return str(row.get("group", "")) == want
	return false
