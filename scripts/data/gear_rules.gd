extends Object

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
		return "weapon:" + str(it.get("weapon", it.get("name", "")))
	if slot == "tool":
		return "tool:" + str(it.get("tool", ""))
	if slot == "potion":
		return "potion:" + str(it.get("name", "Potion"))
	if slot == "food":
		return "food:" + str(it.get("food", it.get("name", "")))
	return "%s:%s" % [slot, str(it.get("name", ""))]


static func is_builtin_starter(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var slot := str(it.get("slot", ""))
	if slot == "weapon" and str(it.get("rarity", "white")) == "white":
		return BUILTIN_WEAPONS.find(str(it.get("weapon", ""))) >= 0
	if slot == "tool" and str(it.get("rarity", "white")) == "white":
		return BUILTIN_TOOLS.find(str(it.get("tool", ""))) >= 0
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
	if is_starter(p, it):
		return false
	if str(it.get("rarity", "white")) == "white" and is_builtin_starter(it):
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
			return
	var copy: Dictionary = it.duplicate(true)
	copy["hold"] = false
	copy["kit_src"] = "starter"
	copy["rarity"] = "white"
	arr.append(copy)
	b[slot] = arr
	p.starters = b


static func handle_mail(p: Object, it: Dictionary) -> String:
	if it.is_empty():
		return "Nothing."
	if str(it.get("kind", "")) == "artifact" or bool(it.get("hold", false)):
		return ""
	if is_starter(p, it):
		return grant_smith(p, it)
	if str(it.get("rarity", "white")) == "white":
		unlock_starter(p, it)
		App.extracted = true
		p.mailed_names.append(str(it.get("name", "item")))
		App.toast("Unlocked as a starter.")
		return "Unlocked starter: " + str(it.get("name", "item"))
	return ""


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
