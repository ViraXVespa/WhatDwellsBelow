extends Object

const Affix := preload("res://scripts/data/affixes.gd")
const Roll := preload("res://scripts/data/gear_roll.gd")

const HOLD_CAP := 3


static func forge_cost(p: Object, slot: String, rarity: String, ilvl: int, lock_n: int) -> Dictionary:
	var smith: int = p.skill_lv("smith")
	var lv: float = float(maxi(1, ilvl))
	var gold: float = _bal("forge_gold", 18.0) + _bal("forge_gold_per_lv", 3.0) * (lv - 1.0)
	var ore: float = _bal("forge_ore", 6.0) + _bal("forge_ore_per_lv", 1.0) * (lv - 1.0)
	var wood: float = 0.0
	if slot == "weapon" or slot == "tool":
		wood = _bal("forge_wood", 4.0) + _bal("forge_wood_per_lv", 1.0) * (lv - 1.0)
	if rarity == "blue":
		var bm: float = _bal("forge_blue_mult", 1.45)
		gold *= bm
		ore *= bm
		wood *= bm
	if lock_n > 0:
		var lm: float = pow(_bal("forge_lock_mult", 2.0), float(lock_n))
		gold *= lm
		ore *= lm
		wood *= lm
	var disc: float = 1.0 / (1.0 + _bal("forge_smith_disc", 0.03) * float(maxi(0, smith - 1)))
	gold *= disc
	ore *= disc
	wood *= disc
	var out: Dictionary = {
		"gold": maxi(1, int(round(gold))),
		"ore": maxi(1, int(round(ore))),
		"wood": 0,
	}
	if slot == "weapon" or slot == "tool":
		out["wood"] = maxi(1, int(round(wood)))
	return out


static func forge_duration(p: Object, slot_or_lv = 1, _rarity: String = "", ilvl: int = -1) -> float:
	var lv: int = 1
	if typeof(slot_or_lv) == TYPE_INT or typeof(slot_or_lv) == TYPE_FLOAT:
		lv = int(slot_or_lv)
	elif ilvl > 0:
		lv = ilvl
	var base: float = _bal("forge_time", 2.0)
	var lo: float = _bal("forge_time_min", 0.35)
	var hi: float = _bal("forge_time_max", 8.0)
	var step: float = _bal("forge_time_step", 1.15)
	var delta: int = maxi(1, lv) - p.skill_lv("smith")
	return clampf(base * pow(step, float(delta)), lo, hi)


static func can_pay(_p: Object, c: Dictionary) -> bool:
	var need_w: int = int(c.get("wood", 0))
	return App.bank_gold + App.gold >= int(c.get("gold", 0)) and App.bank_ore + App.ore >= int(c.get("ore", 0)) and App.bank_wood + App.wood >= need_w


static func pay(_p: Object, c: Dictionary) -> bool:
	if not can_pay(_p, c):
		return false
	_spend_pair(int(c.get("gold", 0)), "gold", "bank_gold")
	_spend_pair(int(c.get("ore", 0)), "ore", "bank_ore")
	_spend_pair(int(c.get("wood", 0)), "wood", "bank_wood")
	return true


static func holds_of(p: Object, slot: String, type_id: String) -> Array:
	var out: Array = []
	for raw: Variant in p.holds.get(slot, []):
		if raw is Dictionary and type_of(raw) == type_id:
			out.append(raw)
	return out


static func hold_open(p: Object, slot: String, type_id: String) -> int:
	return HOLD_CAP - holds_of(p, slot, type_id).size()


static func set_holds_for_type(p: Object, slot: String, type_id: String, keep: Array) -> String:
	var rest: Array = []
	for raw: Variant in p.holds.get(slot, []):
		if raw is Dictionary and type_of(raw) != type_id:
			rest.append(raw)
	var n := 0
	for raw2: Variant in keep:
		if n >= HOLD_CAP:
			break
		if not (raw2 is Dictionary):
			continue
		var it: Dictionary = (raw2 as Dictionary).duplicate(true)
		it["hold"] = true
		it["kit_src"] = "hold"
		it["extract"] = false
		rest.append(it)
		n += 1
	p.holds[slot] = rest
	App.save_now()
	return "Kept %d hold%s." % [n, "" if n == 1 else "s"]


static func make_forged(p: Object, slot: String, type_id: String, rarity: String, ilvl: int, locked: PackedStringArray) -> Dictionary:
	var Book = load("res://scripts/data/progress_forge_book.gd")
	var cap_lv: int = Book.max_ilvl_rarity(p, slot, type_id, rarity)
	var lv: int = clampi(ilvl, 1, maxi(1, cap_lv))
	var unlocks: Dictionary = Book.unlocks_for(p, slot, type_id, rarity)
	var roll: Dictionary = Roll.roll_forge(slot, type_id, rarity, lv, p.skill_lv("smith"), locked, unlocks)
	var it: Dictionary = _blank(p, slot, type_id, rarity)
	Roll.stamp(it, roll)
	it["hold"] = true
	it["extract"] = false
	it["kit_src"] = "hold"
	if not str(it.get("name", "")).begins_with("Forged "):
		it["name"] = "Forged " + str(it.get("name", "item"))
	return it


static func add_hold(p: Object, it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	var type_id := type_of(it)
	if slot == "" or type_id == "":
		return "The anvil won't take that."
	var h: Array = p.holds.get(slot, [])
	if holds_of(p, slot, type_id).size() >= HOLD_CAP:
		return "Holds full."
	h.append(it)
	p.holds[slot] = h
	p.forge_count += 1
	p.add_perm_xp("smith", _bal("xp_smith", 12.0))
	App.save_now()
	return "Forged into a hold (%d/%d)." % [holds_of(p, slot, type_id).size(), HOLD_CAP]


static func place_hold(p: Object, it: Dictionary) -> void:
	add_hold(p, it)


static func replace_hold(p: Object, a, b, c = 0, d = {}) -> String:
	if a is Dictionary:
		var it_a: Dictionary = a
		var idx: int = int(b)
		var slot_a := str(it_a.get("slot", ""))
		var type_a := type_of(it_a)
		var drop_uid := 0
		var arr: Array = p.holds.get(slot_a, [])
		if idx >= 0 and idx < arr.size() and arr[idx] is Dictionary:
			drop_uid = int(arr[idx].get("uid", 0))
		return replace_hold(p, slot_a, type_a, drop_uid, it_a)
	var slot := str(a)
	var type_id := str(b)
	var drop_uid2: int = int(c)
	var it: Dictionary = d if d is Dictionary else {}
	var h: Array = p.holds.get(slot, [])
	if drop_uid2 != 0:
		for i: int in h.size():
			if int(h[i].get("uid", 0)) == drop_uid2 and type_of(h[i]) == type_id:
				h.remove_at(i)
				break
	if holds_of(p, slot, type_id).size() >= HOLD_CAP:
		return "Holds full."
	h.append(it)
	p.holds[slot] = h
	p.forge_count += 1
	p.add_perm_xp("smith", _bal("xp_smith", 12.0))
	App.save_now()
	return "Forged into a hold (%d/%d)." % [holds_of(p, slot, type_id).size(), HOLD_CAP]


static func to_meta(p: Object) -> Dictionary:
	var Book = load("res://scripts/data/progress_forge_book.gd")
	return {"forge_book": Book.book(p)}


static func from_meta(p: Object, d: Dictionary) -> void:
	var Book = load("res://scripts/data/progress_forge_book.gd")
	var raw: Variant = d.get("forge_book", {})
	if raw is Dictionary:
		p.set("forge_book", raw)
	else:
		p.set("forge_book", {})
	Book.migrate(p)


static func type_of(it: Dictionary) -> String:
	return Affix.type_of(it)


static func _blank(p: Object, slot: String, type_id: String, rarity: String) -> Dictionary:
	if slot == "weapon":
		return p.make_weapon(type_id, rarity)
	if slot == "tool":
		return p.make_tool(type_id)
	return p.make_armor(slot, rarity)


static func _spend_pair(need: int, pocket: String, bank: String) -> void:
	if need <= 0:
		return
	var have: int = int(App.get(pocket))
	var use: int = mini(have, need)
	App.set(pocket, have - use)
	need -= use
	if need > 0:
		App.set(bank, maxi(0, int(App.get(bank)) - need))


static func _bal(key: String, fallback: float) -> float:
	if App.bal != null and App.bal.get(key) != null:
		return float(App.bal.get(key))
	return fallback
