extends Object

const Affix := preload("res://scripts/data/affixes.gd")


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
