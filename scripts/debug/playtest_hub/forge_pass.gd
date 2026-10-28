extends Object

const Town := preload("res://scripts/data/progress/progress_town.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Act := preload("res://scripts/data/progress_forge/forge_act.gd")
const Roll := preload("res://scripts/data/gear_roll.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Balance := preload("res://scripts/data/balance.gd")

const _SLOTS: PackedStringArray = ["weapon", "tool", "head", "body", "legs"]

## One forge for the campaign hub. Returns the uid to equip after the next
## telemetry reset, or 0 when the craft was skipped or the roll lost.
static func run_hub() -> int:
	Engine.time_scale = 1.0
	if App.prog == null:
		return 0
	_analyze_risk()
	var plan: Dictionary = _best_plan()
	if plan.is_empty():
		return 0
	var slot_name: String = str(plan.get("slot", ""))
	var type_id: String = str(plan.get("type_id", ""))
	var rarity: String = str(plan.get("rarity", "green"))
	var ilvl: int = int(plan.get("ilvl", 0))
	var bill: Dictionary = _bill(slot_name, rarity, ilvl)
	if not App.prog.pay_forge(bill):
		return 0
	var forged: Dictionary = ForgeP.make_forged(App.prog, slot_name, type_id, rarity, ilvl, PackedStringArray())
	if forged.is_empty():
		return 0
	_keep_hold(slot_name, type_id, forged, false)
	_grant_smith()
	var worn: Dictionary = {}
	var worn_v: Variant = plan.get("worn", {})
	if worn_v is Dictionary:
		worn = worn_v
	if not _beats(forged, worn, slot_name):
		return 0
	return int(forged.get("uid", 0))

## Equip the kept roll onto the open run. Call this after that run's telemetry reset.
static func equip_pending(uid: int) -> void:
	if uid <= 0 or App.prog == null:
		return
	if not _bag_has(uid) and not _stage_hold(uid):
		return
	var marked: int = 0
	if App.tel:
		marked = App.tel.changes.size()
	App.prog.equip_uid(uid)
	if App.tel:
		var i: int = marked
		while i < App.tel.changes.size():
			var row: Dictionary = App.tel.changes[i]
			row["phase"] = "hub"
			App.tel.changes[i] = row
			i += 1
	_point_hold(uid)

static func _analyze_risk() -> void:
	var rows: Array = _risk_rows()
	for raw: Variant in rows:
		if raw is Dictionary:
			Town.analyze_destroy(App.prog, raw)

static func _risk_rows() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	_add_src(out, seen, App.prog.bag, "bag")
	_add_src(out, seen, App.prog.bank_items, "bank")
	for slot_name: String in _SLOTS:
		var eq: Variant = App.prog.slots.get(slot_name, {})
		if eq is Dictionary and not (eq as Dictionary).is_empty():
			_try_add(out, seen, eq, "equipped")
	return out

static func _add_src(out: Array, seen: Dictionary, arr: Array, src: String) -> void:
	for raw: Variant in arr:
		if raw is Dictionary:
			_try_add(out, seen, raw, src)

static func _try_add(out: Array, seen: Dictionary, it: Dictionary, src: String) -> void:
	var rarity: String = str(it.get("rarity", "white"))
	if rarity != "green" and rarity != "blue":
		return
	if not ForgeP.can_analyze(App.prog, it):
		return
	var uid: int = int(it.get("uid", 0))
	if uid != 0 and seen.has(uid):
		return
	if uid != 0:
		seen[uid] = true
	var row_it: Dictionary = it.duplicate(true)
	if src == "bank":
		row_it["kit_src"] = "bank"
	out.append({"it": row_it, "src": src, "uid": uid})

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

static func _keep_hold(slot_name: String, type_id: String, forged: Dictionary, point_new: bool) -> void:
	var old_uid: int = _picked_uid(slot_name)
	var keep: Array = [forged.duplicate(true)]
	var raw: Variant = App.prog.holds.get(slot_name, [])
	if raw is Array:
		for one: Variant in raw:
			if keep.size() >= Act.HOLD_CAP:
				break
			if one is Dictionary and ForgeP.type_of(one) == type_id:
				var uid: int = int((one as Dictionary).get("uid", 0))
				if uid != int(forged.get("uid", 0)):
					keep.append((one as Dictionary).duplicate(true))
	ForgeP.set_holds_for_type(App.prog, slot_name, type_id, keep)
	var point_uid: int = int(forged.get("uid", 0)) if point_new else old_uid
	if point_uid > 0:
		_point_uid(slot_name, point_uid)

static func _picked_uid(slot_name: String) -> int:
	var raw: Variant = App.prog.holds.get(slot_name, [])
	if not (raw is Array):
		return 0
	var arr: Array = raw
	var idx: int = int(App.prog.hold_pick.get(slot_name, -1))
	if idx < 0 or idx >= arr.size() or not (arr[idx] is Dictionary):
		return 0
	return int((arr[idx] as Dictionary).get("uid", 0))

static func _bag_has(uid: int) -> bool:
	for one: Variant in App.prog.bag:
		if one is Dictionary and int((one as Dictionary).get("uid", 0)) == uid:
			return true
	return false

static func _stage_hold(uid: int) -> bool:
	var copy: Dictionary = {}
	var found: bool = false
	for slot_name: String in _SLOTS:
		var raw: Variant = App.prog.holds.get(slot_name, [])
		if not (raw is Array):
			continue
		for one: Variant in raw:
			if one is Dictionary and int((one as Dictionary).get("uid", 0)) == uid:
				copy = (one as Dictionary).duplicate(true)
				found = true
				break
		if found:
			break
	if not found:
		return false
	copy["hold"] = false
	copy["kit_src"] = ""
	if App.prog.bag_full() and App.prog.bag.size() > 0:
		var moved: Variant = App.prog.bag[0]
		App.prog.bag.remove_at(0)
		if moved is Dictionary:
			App.prog.bank_items.append(moved)
	return App.prog.add_to_bag(copy)

static func _point_hold(uid: int) -> void:
	for slot_name: String in _SLOTS:
		if _point_uid(slot_name, uid):
			return

static func _point_uid(slot_name: String, uid: int) -> bool:
	var raw: Variant = App.prog.holds.get(slot_name, [])
	if not (raw is Array):
		return false
	var i: int = 0
	for one: Variant in raw:
		if one is Dictionary and int((one as Dictionary).get("uid", 0)) == uid:
			App.prog.hold_pick[slot_name] = i
			return true
		i += 1
	return false

static func _grant_smith() -> void:
	App.prog.forge_count += 1
	App.prog.add_perm_xp("smith", Balance.f("xp_smith", 12.0))
