extends Object

const Roll := preload("res://scripts/data/gear_roll.gd")
const Affix := preload("res://scripts/data/affixes.gd")

const BUILTIN_WEAPONS := ["great_axe", "staff", "longbow"]
const BUILTIN_TOOLS := ["pickaxe", "hatchet"]


static func book(p: Object) -> Dictionary:
	var s: Variant = p.get("starters")
	if s is Dictionary:
		return s
	p.set("starters", {})
	return p.starters


static func tmpl_key(it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if slot == "weapon":
		return "weapon:" + _weapon_id(it)
	if slot == "tool":
		return "tool:" + _tool_id(it)
	if slot == "potion":
		return "potion:" + str(it.get("name", "Potion"))
	if slot == "food":
		return "food:" + str(it.get("food", it.get("name", "")))
	return "%s:%s" % [slot, str(it.get("name", ""))]


static func _weapon_id(it: Dictionary) -> String:
	var w := str(it.get("weapon", ""))
	if w != "":
		return w
	var nm := str(it.get("name", "")).to_lower()
	if nm.find("great axe") >= 0 or nm.find("greataxe") >= 0:
		return "great_axe"
	if nm.find("staff") >= 0:
		return "staff"
	if nm.find("longbow") >= 0:
		return "longbow"
	return nm


static func _tool_id(it: Dictionary) -> String:
	var t := str(it.get("tool", ""))
	if t != "":
		return t
	var nm := str(it.get("name", "")).to_lower()
	if nm.find("hatchet") >= 0:
		return "hatchet"
	if nm.find("pick") >= 0:
		return "pickaxe"
	return nm


static func is_builtin_starter(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var slot := str(it.get("slot", ""))
	if slot == "weapon" and str(it.get("rarity", "white")) == "white":
		return BUILTIN_WEAPONS.find(_weapon_id(it)) >= 0
	if slot == "tool" and str(it.get("rarity", "white")) == "white":
		return BUILTIN_TOOLS.find(_tool_id(it)) >= 0
	if slot == "potion" and str(it.get("name", "Potion")) == "Potion" and str(it.get("rarity", "white")) == "white":
		return true
	return false


static func is_starter(p: Object, it: Dictionary) -> bool:
	if is_builtin_starter(it):
		return true
	if str(it.get("kit_src", "")) == "starter":
		return true
	var slot := str(it.get("slot", ""))
	var key := tmpl_key(it)
	var arr: Array = book(p).get(slot, [])
	for raw: Variant in arr:
		if raw is Dictionary and tmpl_key(raw) == key:
			return true
	return false


static func can_forge(p: Object, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if str(it.get("kind", "")) == "artifact":
		return false
	if str(it.get("slot", "")) == "potion" or str(it.get("slot", "")) == "food":
		return false
	if bool(it.get("hold", false)) or str(it.get("kit_src", "")) == "hold":
		return false
	if str(it.get("rarity", "white")) == "white":
		return false
	if is_starter(p, it):
		return false
	return true


static func can_bank(p: Object, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if str(it.get("kind", "")) == "artifact":
		return false
	if bool(it.get("hold", false)):
		return false
	if is_starter(p, it):
		return false
	return true


static func locked_equip_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "tool"


static func smith_xp_for(it: Dictionary) -> float:
	var base := 12.0
	if App.bal and App.bal.get("xp_smith") != null:
		base = float(App.bal.xp_smith)
	match str(it.get("rarity", "white")):
		"green":
			return base * 1.5
		"blue":
			return base * 2.5
		_:
			return base


static func grant_smith(p: Object, it: Dictionary) -> String:
	var xp := smith_xp_for(it)
	p.add_perm_xp("smith", xp)
	App.extracted = true
	App.toast("Broken down for smithing.")
	return "Converted %s to smithing XP." % str(it.get("name", "item"))


static func unlock_starter(p: Object, it: Dictionary) -> void:
	var slot := str(it.get("slot", ""))
	if slot == "":
		return
	var b := book(p)
	var arr: Array = b.get(slot, [])
	var key := tmpl_key(it)
	for raw: Variant in arr:
		if raw is Dictionary and tmpl_key(raw) == key:
			_write_starter_ilvl(raw, int(it.get("ilvl", 1)))
			b[slot] = arr
			p.starters = b
			return
	var copy: Dictionary = it.duplicate(true)
	copy["hold"] = false
	copy["kit_src"] = "starter"
	copy["rarity"] = "white"
	arr.append(copy)
	b[slot] = arr
	p.starters = b


static func starter_ilvl(p: Object, it: Dictionary) -> int:
	var key := tmpl_key(it)
	var slot := str(it.get("slot", ""))
	var best: int = 1
	for raw: Variant in book(p).get(slot, []):
		if raw is Dictionary and tmpl_key(raw) == key:
			best = maxi(best, int(raw.get("ilvl", 1)))
	return best


static func handle_mail(p: Object, it: Dictionary) -> String:
	if it.is_empty():
		return "Nothing."
	if str(it.get("kind", "")) == "artifact" or bool(it.get("hold", false)):
		return ""
	if str(it.get("rarity", "white")) == "white":
		if is_starter(p, it):
			return _mail_white(p, it)
		unlock_starter(p, it)
		App.extracted = true
		p.mailed_names.append(str(it.get("name", "item")))
		App.toast("Unlocked as a starter.")
		return "Unlocked starter: " + str(it.get("name", "item"))
	if is_starter(p, it):
		return grant_smith(p, it)
	return ""


static func _mail_white(p: Object, it: Dictionary) -> String:
	var have: int = starter_ilvl(p, it)
	var incoming: int = maxi(1, int(it.get("ilvl", 1)))
	if incoming <= have:
		return grant_smith(p, it)
	unlock_starter(p, it)
	_apply_starter_level(p, it, incoming)
	App.extracted = true
	p.mailed_names.append(str(it.get("name", "item")))
	App.toast("Starter leveled to %d." % incoming)
	return "Starter leveled to %d." % incoming


static func _apply_starter_level(p: Object, it: Dictionary, ilvl: int) -> void:
	var slot := str(it.get("slot", ""))
	var key := tmpl_key(it)
	var b := book(p)
	var arr: Array = b.get(slot, [])
	for i: int in arr.size():
		if arr[i] is Dictionary and tmpl_key(arr[i]) == key:
			arr[i] = _restat_white(arr[i], ilvl)
	b[slot] = arr
	p.starters = b
	var eq: Dictionary = p.slots.get(slot, {})
	if not eq.is_empty() and str(eq.get("rarity", "white")) == "white" and tmpl_key(eq) == key:
		p.slots[slot] = _restat_white(eq, ilvl)
		if p.has_method("_refresh_player_hp"):
			p._refresh_player_hp()


static func _restat_white(it: Dictionary, ilvl: int) -> Dictionary:
	var copy: Dictionary = it.duplicate(true)
	var slot := str(copy.get("slot", ""))
	var type_id := str(copy.get("weapon", copy.get("tool", slot)))
	if slot == "weapon":
		type_id = _weapon_id(copy)
	elif slot == "tool":
		type_id = _tool_id(copy)
	Roll.stamp(copy, Roll.roll_dungeon(slot, type_id, "white", ilvl))
	copy["rarity"] = "white"
	copy["hold"] = false
	copy["kit_src"] = "starter"
	return copy


static func _write_starter_ilvl(it: Dictionary, ilvl: int) -> void:
	it["ilvl"] = maxi(int(it.get("ilvl", 1)), ilvl)


static func normalize_prog(p: Object) -> void:
	if p == null:
		return
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		var eq: Variant = p.slots.get(s, {})
		if eq is Dictionary and not eq.is_empty():
			p.slots[s] = normalize_item(eq)
	_norm_list(p.bag)
	if p.get("bank_items") is Array:
		_norm_list(p.bank_items)
	if p.get("holds") is Dictionary:
		for s2: Variant in p.holds.keys():
			var h: Variant = p.holds[s2]
			if h is Array:
				_norm_list(h)
	if p.get("starters") is Dictionary:
		for s3: Variant in p.starters.keys():
			var st: Variant = p.starters[s3]
			if st is Array:
				_norm_list(st)


static func _norm_list(arr: Array) -> void:
	for i: int in arr.size():
		if arr[i] is Dictionary:
			arr[i] = normalize_item(arr[i])


static func normalize_item(it: Dictionary) -> Dictionary:
	if it.is_empty():
		return it
	var kind := str(it.get("kind", ""))
	var slot := str(it.get("slot", ""))
	if kind == "artifact" or slot == "potion" or slot == "food" or kind == "food":
		return it
	if slot != "weapon" and slot != "tool" and slot != "head" and slot != "body" and slot != "legs":
		return it
	_map_legacy(it)
	it["ilvl"] = maxi(1, int(it.get("ilvl", 1)))
	if not it.has("quality"):
		it["quality"] = 0.5 if str(it.get("rarity", "white")) == "white" else 0.75
	if not it.has("luck"):
		it["luck"] = 0.75
	var lv: int = int(it.ilvl)
	var cap_flat := _cap_flat(lv)
	var cap_pct := _cap_pct(lv)
	var rows: Array = []
	var raw: Variant = it.get("affixes", [])
	if raw is Array:
		for row: Variant in raw:
			if not (row is Dictionary):
				continue
			var id := _map_id(str(row.get("id", "")))
			if id == "":
				continue
			var val := float(row.get("value", it.get(id, 0.0)))
			val = _clamp_stat(id, val, cap_flat, cap_pct)
			rows.append({"id": id, "value": val, "luck": float(it.get("luck", 0.75))})
			it[id] = val
	if rows.is_empty():
		for id2: String in [
			Affix.ID_DMG, Affix.ID_DEF, Affix.ID_HP,
			Affix.ID_CRIT_CHANCE, Affix.ID_CRIT_DMG, Affix.ID_MOVE,
			Affix.ID_ATK_SPD, Affix.ID_ATK_RANGE, Affix.ID_HP_HIT, Affix.ID_HP_KILL,
			Affix.ID_GATHER_SPD, Affix.ID_GATHER_POW, Affix.ID_YIELD,
		]:
			var n := float(it.get(id2, 0.0))
			if absf(n) < 0.001:
				continue
			n = _clamp_stat(id2, n, cap_flat, cap_pct)
			it[id2] = n
			rows.append({"id": id2, "value": n, "luck": float(it.get("luck", 0.75))})
	it["affixes"] = rows
	it["dmg"] = int(round(float(it.get(Affix.ID_DMG, 0.0))))
	it["def"] = int(round(float(it.get(Affix.ID_DEF, 0.0))))
	it["hp"] = int(round(float(it.get(Affix.ID_HP, 0.0))))
	return it


static func _map_legacy(it: Dictionary) -> void:
	if it.has("crit") and not it.has(Affix.ID_CRIT_CHANCE):
		it[Affix.ID_CRIT_CHANCE] = float(it.get("crit", 0.0))
	if it.has("spd") and not it.has(Affix.ID_MOVE):
		it[Affix.ID_MOVE] = float(it.get("spd", 0.0))
	if it.has("gather") and not it.has(Affix.ID_GATHER_SPD):
		it[Affix.ID_GATHER_SPD] = float(it.get("gather", 0.0))


static func _map_id(id: String) -> String:
	match id:
		"crit":
			return Affix.ID_CRIT_CHANCE
		"spd":
			return Affix.ID_MOVE
		"gather":
			return Affix.ID_GATHER_SPD
		_:
			return id


static func _clamp_stat(id: String, v: float, cap_flat: float, cap_pct: float) -> float:
	if Affix.kind_of(id) == Affix.KIND_PCT:
		return clampf(v, 0.0, cap_pct)
	return clampf(v, 0.0, cap_flat)


static func _cap_flat(ilvl: int) -> float:
	return (2.0 + 0.65 * float(maxi(1, ilvl))) * 1.25 * 1.25


static func _cap_pct(ilvl: int) -> float:
	return (0.02 + 0.004 * float(maxi(1, ilvl))) * 1.25 * 1.25


static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	if p.potion_cd > 0.0:
		App.toast("Potion cooling down.")
		return "Not ready."
	var ch := int(it.get("charges", it.get("stack", 0)))
	if ch <= 0:
		App.toast("No charges left this run.")
		return "Empty."
	var pl: CharacterBody3D = p._player()
	if pl == null or not pl.has_method("heal"):
		return "Not now."
	var heal := 1.0
	if App.bal:
		heal = float(App.bal.get("potion_heal"))
		if heal <= 1.0:
			heal = float(App.bal.player_max_hp) * heal
	pl.heal(heal)
	var cd := float(it.get("cooldown", 0.0))
	if cd <= 0.0 and App.bal:
		cd = float(App.bal.get("potion_cooldown"))
	p.potion_cd = cd
	it.charges = ch - 1
	it.stack = 1
	if from_slot:
		p.slots["potion"] = it
	App.sfx("potion")
	App.toast("Potion — instant.")
	return "Potion."


static func refill_potion(p: Object) -> void:
	var it: Dictionary = p.slots.get("potion", {})
	if it.is_empty():
		return
	var mx := int(it.get("charge_max", 0))
	if mx <= 0:
		mx = int(it.get("charges", 2))
		if mx <= 0:
			mx = 2
		it.charge_max = mx
	it.charges = mx
	it.stack = 1
	p.slots["potion"] = it


static func same_white(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("rarity", "white")) != "white" or str(b.get("rarity", "white")) != "white":
		return false
	return tmpl_key(a) == tmpl_key(b)
