extends Object

const Town := preload("res://scripts/data/progress/progress_town.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Act := preload("res://scripts/data/progress_forge/forge_act.gd")
const Roll := preload("res://scripts/data/gear_roll.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Balance := preload("res://scripts/data/balance.gd")

const Plan := preload("res://scripts/debug/playtest_hub/forge_pass/plan.gd")
const _SLOTS: PackedStringArray = ["weapon", "tool", "head", "body", "legs"]

## One forge for the campaign hub. Returns the uid to equip after the next
## telemetry reset, or 0 when the craft was skipped or the roll lost.
static func run_hub() -> int:
	Engine.time_scale = 1.0
	if App.prog == null:
		return 0
	_analyze_risk()
	var plan: Dictionary = Plan._best_plan()
	if plan.is_empty():
		return 0
	var slot_name: String = str(plan.get("slot", ""))
	var type_id: String = str(plan.get("type_id", ""))
	var rarity: String = str(plan.get("rarity", "green"))
	var ilvl: int = int(plan.get("ilvl", 0))
	var bill: Dictionary = Plan._bill(slot_name, rarity, ilvl)
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
	if not Plan._beats(forged, worn, slot_name):
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
