extends Object

const Roll := preload("res://scripts/data/gear_roll.gd")

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


static func same_white(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("rarity", "white")) != "white" or str(b.get("rarity", "white")) != "white":
		return false
	return tmpl_key(a) == tmpl_key(b)
