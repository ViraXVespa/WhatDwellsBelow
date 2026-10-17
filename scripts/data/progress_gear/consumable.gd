extends Object

## Hub potion holds and food stacks. The equipped slot is a copy of one hold.
## Potions are vendor-only (plus the starter). Moldy bread is dumpster-only.

const Affix := preload("res://scripts/data/affixes.gd")
const Make := preload("res://scripts/data/progress/progress_make.gd")

const Roll := preload("res://scripts/data/progress_gear/consumable_roll.gd")
const FOOD_IDS: PackedStringArray = ["ration", "trail_bread", "stew"]
static func kind_cap() -> int:
	return maxi(1, int(Roll._f("food_kind_max", 6.0)))

static func stack_cap() -> int:
	return maxi(1, int(Roll._f("food_bring_max", 20.0)))

static func potion_cap() -> int:
	return maxi(1, int(Roll._f("potion_hold_max", 3.0)))

static func _holds(p: Object, slot: String) -> Array:
	var raw: Variant = p.holds.get(slot, [])
	if raw is Array:
		return raw
	return []

static func grant_starters(p: Object) -> void:
	if _holds(p, "potion").is_empty() and (p.slots.get("potion", {}) as Dictionary).is_empty():
		var pot: Dictionary = Make.make_potion(p, 2)
		_put_hold(p, "potion", pot)
		p.slots["potion"] = pot.duplicate(true)
	if _holds(p, "food").is_empty() and (p.slots.get("food", {}) as Dictionary).is_empty():
		var fd: Dictionary = Make.make_food(p, "ration", 5)
		_put_hold(p, "food", fd)
		p.slots["food"] = fd.duplicate(true)

## Old saves kept a potion or ration only on the slot. Copy that into the hold list.
static func adopt(p: Object) -> void:
	_adopt_slot(p, "potion")
	_adopt_slot(p, "food")
	grant_starters(p)

static func _adopt_slot(p: Object, slot: String) -> void:
	var it: Dictionary = p.slots.get(slot, {})
	if it.is_empty():
		return
	if _find_uid(p, slot, int(it.get("uid", 0))) >= 0:
		return
	if slot == "food" and _find_food(p, str(it.get("food", ""))) >= 0:
		return
	_put_hold(p, slot, it.duplicate(true))

static func _put_hold(p: Object, slot: String, it: Dictionary) -> void:
	var h: Array = _holds(p, slot).duplicate()
	h.append(it)
	p.holds[slot] = h

static func _find_uid(p: Object, slot: String, uid: int) -> int:
	if uid == 0:
		return -1
	var h: Array = _holds(p, slot)
	for i: int in h.size():
		if int((h[i] as Dictionary).get("uid", 0)) == uid:
			return i
	return -1

static func _find_food(p: Object, fid: String) -> int:
	if fid == "":
		return -1
	var h: Array = _holds(p, "food")
	for i: int in h.size():
		if str((h[i] as Dictionary).get("food", "")) == fid:
			return i
	return -1

## Write the equipped copies back onto their holds. An empty food stack is dropped.
static func sync_slots(p: Object) -> void:
	var pot: Dictionary = p.slots.get("potion", {})
	if not pot.is_empty():
		_write_potion(p, pot)
	var fd: Dictionary = p.slots.get("food", {})
	if fd.is_empty():
		return
	if int(fd.get("stack", 0)) <= 0:
		_drop_food(p, str(fd.get("food", "")))
		return
	_write_food(p, fd)

static func _write_potion(p: Object, it: Dictionary) -> void:
	var h: Array = _holds(p, "potion").duplicate()
	var idx: int = _find_uid(p, "potion", int(it.get("uid", 0)))
	if idx < 0:
		h.append(it.duplicate(true))
	else:
		var row: Dictionary = (h[idx] as Dictionary).duplicate(true)
		row["charges"] = int(it.get("charges", 0))
		row["charge_max"] = int(it.get("charge_max", row.get("charge_max", 0)))
		h[idx] = row
	p.holds["potion"] = h

static func _write_food(p: Object, it: Dictionary) -> void:
	var h: Array = _holds(p, "food").duplicate()
	var idx: int = _find_uid(p, "food", int(it.get("uid", 0)))
	if idx < 0:
		idx = _find_food(p, str(it.get("food", "")))
	if idx < 0:
		h.append(it.duplicate(true))
	else:
		var row: Dictionary = (h[idx] as Dictionary).duplicate(true)
		row["stack"] = mini(int(it.get("stack", 0)), stack_cap())
		h[idx] = row
	p.holds["food"] = h

static func _drop_food(p: Object, fid: String) -> void:
	var h: Array = []
	for raw: Variant in _holds(p, "food"):
		if str((raw as Dictionary).get("food", "")) == fid:
			continue
		h.append(raw)
	p.holds["food"] = h

## Remember what is equipped, and refill that potion's charges for the dive.
static func note_dive(p: Object) -> void:
	var pot: Dictionary = p.slots.get("potion", {})
	if pot.is_empty():
		p.return_potion_uid = 0
	else:
		_refill(pot)
		p.slots["potion"] = pot
		_write_potion(p, pot)
		p.return_potion_uid = int(pot.get("uid", 0))
	var fd: Dictionary = p.slots.get("food", {})
	if fd.is_empty() or int(fd.get("stack", 0)) <= 0:
		p.return_food_id = ""
	else:
		p.return_food_id = str(fd.get("food", ""))

## After a dive is lost: put the pre-dive potion back, then resolve food.
static func restore_return(p: Object) -> void:
	if not bool(p.moldy_ready):
		p.moldy_ready = true
	var uid: int = int(p.return_potion_uid)
	p.return_potion_uid = 0
	p.slots["potion"] = {}
	if uid != 0:
		var pidx: int = _find_uid(p, "potion", uid)
		if pidx >= 0:
			p.slots["potion"] = (_holds(p, "potion")[pidx] as Dictionary).duplicate(true)
	var want: String = str(p.return_food_id)
	p.return_food_id = ""
	p.slots["food"] = {}
	var fidx: int = _find_food(p, want)
	if fidx >= 0 and int((_holds(p, "food")[fidx] as Dictionary).get("stack", 0)) > 0:
		p.slots["food"] = (_holds(p, "food")[fidx] as Dictionary).duplicate(true)
		return
	var nxt: int = _next_food(p)
	if nxt >= 0:
		p.slots["food"] = (_holds(p, "food")[nxt] as Dictionary).duplicate(true)

static func _next_food(p: Object) -> int:
	var h: Array = _holds(p, "food")
	for i: int in h.size():
		if int((h[i] as Dictionary).get("stack", 0)) > 0:
			return i
	return -1

static func _refill(it: Dictionary) -> void:
	var mx: int = int(it.get("charge_max", 0))
	if mx <= 0:
		mx = maxi(1, int(it.get("charges", 2)))
		it["charge_max"] = mx
	it["charges"] = mx

static func roll_three(p: Object) -> Array:
	return Roll.roll_three(p)

static func roll_potion(p: Object) -> Dictionary:
	return Roll.roll_potion(p)

## A food dict for a vendor row. Does not spend a uid.
static func preview_food(fid: String) -> Dictionary:
	return Roll.preview_food(fid)

static func decorate_food(it: Dictionary) -> Dictionary:
	return Roll.decorate_food(it)

## Vendor food rows for this moment. {"food", "mode"} mode is "new" or "stack".
static func food_rows(p: Object) -> Array:
	var owned: Array[String] = []
	var not_full: Array[String] = []
	for raw: Variant in _holds(p, "food"):
		var row: Dictionary = raw as Dictionary
		var fid: String = str(row.get("food", ""))
		if fid == "" or fid == "moldy_bread":
			if fid == "moldy_bread":
				owned.append(fid)
				if int(row.get("stack", 0)) < stack_cap():
					not_full.append(fid)
			continue
		owned.append(fid)
		if int(row.get("stack", 0)) < stack_cap():
			not_full.append(fid)
	var fresh: Array[String] = []
	for id: String in FOOD_IDS:
		if not owned.has(id):
			fresh.append(id)
	var filled: bool = owned.size() >= kind_cap()
	var all_full: bool = owned.size() > 0 and not_full.is_empty()
	var out: Array = []
	if filled and all_full:
		var n: int = mini(3, fresh.size())
		for i: int in n:
			out.append({"food": fresh[i], "mode": "new"})
		return out
	for fid2: String in not_full:
		if fid2 == "moldy_bread":
			continue
		out.append({"food": fid2, "mode": "stack"})
	if filled:
		if fresh.size() > 0:
			out.append({"food": fresh[0], "mode": "new"})
		return out
	var added: int = 0
	for fid3: String in fresh:
		out.append({"food": fid3, "mode": "new"})
		added += 1
		if added >= 3:
			break
	return out

static func hold_potion(p: Object, it: Dictionary) -> bool:
	if _holds(p, "potion").size() >= potion_cap():
		return false
	_put_hold(p, "potion", it)
	var cur: Dictionary = p.slots.get("potion", {})
	if cur.is_empty():
		p.slots["potion"] = it.duplicate(true)
	return true

static func give_food(p: Object, fid: String, n: int) -> bool:
	var it: Dictionary = Make.make_food(p, fid, maxi(1, n))
	return add_food_item(p, it)

static func add_food_item(p: Object, it: Dictionary) -> bool:
	var fid: String = str(it.get("food", ""))
	if fid == "":
		return false
	var add_n: int = maxi(1, int(it.get("stack", 1)))
	var idx: int = _find_food(p, fid)
	if idx >= 0:
		var h: Array = _holds(p, "food").duplicate()
		var row: Dictionary = (h[idx] as Dictionary).duplicate(true)
		row["stack"] = mini(int(row.get("stack", 0)) + add_n, stack_cap())
		h[idx] = row
		p.holds["food"] = h
		_mirror_food_slot(p, row)
		return true
	if _holds(p, "food").size() >= kind_cap():
		return false
	var born: Dictionary = it.duplicate(true)
	born["stack"] = mini(add_n, stack_cap())
	_put_hold(p, "food", born)
	var cur: Dictionary = p.slots.get("food", {})
	if cur.is_empty() or int(cur.get("stack", 0)) <= 0:
		p.slots["food"] = born.duplicate(true)
	return true

static func _mirror_food_slot(p: Object, row: Dictionary) -> void:
	var cur: Dictionary = p.slots.get("food", {})
	if cur.is_empty():
		return
	if str(cur.get("food", "")) != str(row.get("food", "")):
		return
	cur["stack"] = int(row.get("stack", 0))
	p.slots["food"] = cur

static func needs_toss(p: Object, fid: String) -> bool:
	if _find_food(p, fid) >= 0:
		return false
	return _holds(p, "food").size() >= kind_cap()

static func toss_food(p: Object, fid: String) -> void:
	var cur: Dictionary = p.slots.get("food", {})
	if str(cur.get("food", "")) == fid:
		p.slots["food"] = {}
	_drop_food(p, fid)

## Dumpster. Returns the en.po key for the line the player reads.
static func scavenge(p: Object) -> String:
	if not bool(p.moldy_ready):
		return "common.you_used_to_eat_from"
	var idx: int = _find_food(p, "moldy_bread")
	if idx >= 0 and int((_holds(p, "food")[idx] as Dictionary).get("stack", 0)) >= stack_cap():
		return "dumpster.moldy_max"
	if idx < 0 and _holds(p, "food").size() >= kind_cap():
		return "dumpster.moldy_full"
	if not give_food(p, "moldy_bread", 1):
		return "dumpster.moldy_full"
	p.moldy_ready = false
	return "dumpster.moldy_ok"
