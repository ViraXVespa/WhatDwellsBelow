extends Object

const CatalogS := preload("res://scripts/data/catalog.gd")


static func make_weapon(p, wpn: String, rarity: String) -> Dictionary:
	var n := "Great Axe"
	if wpn == "staff":
		n = "Lightning Staff"
	elif wpn == "longbow":
		n = "Longbow"
	var dmg := int(App.bal.gear_white_dmg)
	if rarity == "green":
		dmg = int(App.bal.gear_green_dmg)
	elif rarity == "blue":
		dmg = int(App.bal.gear_blue_dmg)
	return item(p, "weapon", n, {"slot": "weapon", "weapon": wpn, "rarity": rarity, "dmg": dmg, "desc": "%s %s. +%d damage." % [rarity.capitalize(), n, dmg]})


static func make_tool(p, kind: String) -> Dictionary:
	var n := "Pickaxe" if kind == "pickaxe" else "Hatchet"
	return item(p, "tool", n, {"slot": "tool", "tool": kind, "rarity": "white", "desc": "Run tool. Locked to %s." % kind})


static func make_armor(p, slot: String, rarity: String) -> Dictionary:
	var def := int(App.bal.gear_white_def)
	var hp := int(App.bal.gear_white_hp)
	if rarity == "green":
		def = int(App.bal.gear_green_def)
		hp = int(App.bal.gear_green_hp)
	elif rarity == "blue":
		def = int(App.bal.gear_blue_def)
		hp = int(App.bal.gear_blue_hp)
	return item(p, slot, "%s %s" % [rarity.capitalize(), slot.capitalize()], {"slot": slot, "rarity": rarity, "def": def, "hp": hp, "desc": "+%d def, +%d HP." % [def, hp]})


static func make_potion(p, n: int) -> Dictionary:
	return item(p, "potion", "Potion", {"slot": "potion", "stack": n, "desc": "Instant heal."})


static func make_food(p, fid: String, n: int) -> Dictionary:
	var nm := "Ration" if fid == "ration" else "Trail Bread"
	return item(p, "food", nm, {"slot": "food", "food": fid, "stack": n, "desc": "Heal-over-time."})


static func make_artifact(p, id: String) -> Dictionary:
	var a: Dictionary = CatalogS.by_id(id)
	if a.is_empty():
		a = {"id": id, "name": id, "set": "", "desc": "A curious relic."}
	return item(p, "artifact", str(a.name), {"id": id, "set": str(a.get("set", "")), "desc": str(a.get("desc", "A run-only relic.")), "extract": false})


static func item(p, kind: String, name: String, extra: Dictionary) -> Dictionary:
	var it := {
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
		"extract": extra.get("extract", kind != "artifact"),
		"hold": false,
	}
	if extra.has("id"):
		it.id = str(extra.id)
	p.next_uid += 1
	return it


static func starter(p, slot: String) -> Dictionary:
	match slot:
		"weapon":
			return make_weapon(p, "great_axe", "white")
		"tool":
			return make_tool(p, p.tool_type)
		"potion":
			return make_potion(p, 3)
		"food":
			return make_food(p, "ration", 5)
		_:
			return {}


static func bag_stack_index(p, it: Dictionary) -> int:
	var k := str(it.get("kind", ""))
	if k != "potion" and k != "food":
		return -1
	for i in p.bag.size():
		var b: Dictionary = p.bag[i]
		if str(b.get("kind", "")) != k:
			continue
		if k == "food" and str(b.get("food", "")) != str(it.get("food", "")):
			continue
		return i
	return -1


static func bag_can_accept(p, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if bag_stack_index(p, it) >= 0:
		return true
	return not p.bag_full()


static func add_item(p, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if str(it.kind) == "potion" or str(it.kind) == "food":
		var slot_it: Dictionary = p.slots.get(str(it.slot), {})
		if not slot_it.is_empty() and str(slot_it.get("food", "")) == str(it.get("food", "")) and str(it.kind) == "food":
			var nxt := int(slot_it.stack) + int(it.stack)
			if not App.in_dungeon:
				nxt = mini(nxt, int(App.bal.food_bring_max))
			slot_it.stack = nxt
			p.slots[str(it.slot)] = slot_it
			return true
		if not slot_it.is_empty() and str(it.kind) == "potion" and str(slot_it.kind) == "potion":
			slot_it.stack = int(slot_it.stack) + int(it.stack)
			p.slots["potion"] = slot_it
			return true
	return add_to_bag(p, it)


static func add_to_bag(p, it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var idx := bag_stack_index(p, it)
	if idx >= 0:
		var b: Dictionary = p.bag[idx]
		var nxt := int(b.get("stack", 1)) + int(it.get("stack", 1))
		if str(it.kind) == "food" and not App.in_dungeon:
			nxt = mini(nxt, int(App.bal.food_bring_max))
		b.stack = nxt
		p.bag[idx] = b
		return true
	if p.bag_full():
		App.toast("Bag full.")
		return false
	p.bag.append(it)
	if str(it.kind) == "artifact":
		p._sync_artifacts()
		p._refresh_player_hp()
	return true


static func remove_uid(p, uid: int) -> Dictionary:
	for i in p.bag.size():
		if int(p.bag[i].uid) == uid:
			var it: Dictionary = p.bag[i]
			p.bag.remove_at(i)
			p._sync_artifacts()
			if str(it.kind) == "artifact":
				p._refresh_player_hp()
			return it
	return {}


static func equip_uid(p, uid: int) -> String:
	var it := remove_uid(p, uid)
	if it.is_empty():
		return "Gone."
	var slot := str(it.get("slot", ""))
	if p.SLOTS.find(slot) < 0:
		add_to_bag(p, it)
		return "Can't equip that."
	if slot == "tool":
		var t := str(it.get("tool", ""))
		if t != "" and t != p.tool_type:
			add_to_bag(p, it)
			return "Tool locked to %s this run." % p.tool_type
	var cur: Dictionary = p.slots.get(slot, {})
	if not cur.is_empty():
		if not bag_can_accept(p, cur):
			add_to_bag(p, it)
			return "Bag full."
		p.slots[slot] = {}
		if not add_to_bag(p, cur):
			p.slots[slot] = cur
			add_to_bag(p, it)
			return "Bag full."
	p.slots[slot] = it
	if slot == "food":
		p._clamp_food_slot()
	if slot == "weapon":
		App.weapon = str(it.get("weapon", "great_axe"))
		var pl: CharacterBody3D = p._player()
		if pl and pl.has_method("set_weapon"):
			pl.set_weapon(App.weapon)
	p._sync_artifacts()
	p._refresh_player_hp()
	return "Equipped " + str(it.name)


static func drop_uid(p, uid: int) -> String:
	var it := remove_uid(p, uid)
	if it.is_empty():
		return "Gone."
	App.spawn_floor_item(it)
	App.toast("Dropped " + str(it.name))
	return "Dropped."


static func unequip_slot(p, slot: String) -> String:
	if p.SLOTS.find(slot) < 0:
		return "No slot."
	var it: Dictionary = p.slots.get(slot, {})
	if it.is_empty():
		return "Empty."
	if not bag_can_accept(p, it):
		App.toast("Bag full.")
		return "Bag full."
	p.slots[slot] = {}
	if not add_to_bag(p, it):
		p.slots[slot] = it
		return "Bag full."
	if slot == "weapon":
		var pl: CharacterBody3D = p._player()
		if pl and pl.has_method("set_weapon") and App.weapon != "":
			pl.set_weapon(App.weapon)
	p._sync_artifacts()
	p._refresh_player_hp()
	return "Unequipped " + str(it.name)


static func fill_slot_after_remove(p, slot: String) -> void:
	if slot == "weapon":
		p.slots["weapon"] = make_weapon(p, p.pick_weapon, "white")
		App.weapon = str(p.slots.weapon.get("weapon", p.pick_weapon))
		var pl: CharacterBody3D = p._player()
		if pl and pl.has_method("set_weapon"):
			pl.set_weapon(App.weapon)
	elif slot == "tool":
		p.slots["tool"] = make_tool(p, p.tool_type)
	else:
		p.slots[slot] = {}


static func drop_slot(p, slot: String) -> String:
	if p.SLOTS.find(slot) < 0:
		return "No slot."
	var it: Dictionary = p.slots.get(slot, {})
	if it.is_empty():
		return "Empty."
	fill_slot_after_remove(p, slot)
	p._refresh_player_hp()
	App.spawn_floor_item(it)
	App.toast("Dropped " + str(it.name))
	return "Dropped."


static func take_slot(p, slot: String) -> Dictionary:
	if p.SLOTS.find(slot) < 0:
		return {}
	var it: Dictionary = p.slots.get(slot, {})
	if it.is_empty():
		return {}
	fill_slot_after_remove(p, slot)
	p._refresh_player_hp()
	return it


static func drop_stash(p, uid: int) -> String:
	for i in p.bank_items.size():
		if int(p.bank_items[i].uid) == uid:
			var it: Dictionary = p.bank_items[i]
			p.bank_items.remove_at(i)
			App.toast("Discarded " + str(it.name))
			return "Discarded."
	return "Gone."


static func give_or_drop(p, it: Dictionary, pos: Vector3) -> bool:
	if it.is_empty():
		return false
	if add_item(p, it):
		return true
	App.spawn_floor_item(it, pos)
	return false


static func use_from_bag(p, uid: int) -> String:
	var it: Dictionary = {}
	for b in p.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		return "Gone."
	if str(it.kind) == "potion":
		return drink(p, it, false)
	if str(it.kind) == "food":
		return eat(p, it, false)
	return equip_uid(p, uid)


static func use_potion(p) -> String:
	var it: Dictionary = p.slots.get("potion", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast("No potion equipped.")
		return "No potion equipped."
	return drink(p, it, true)


static func use_food(p) -> String:
	var it: Dictionary = p.slots.get("food", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast("No food equipped.")
		return "No food equipped."
	return eat(p, it, true)


static func drink(p, it: Dictionary, from_slot: bool) -> String:
	if p.potion_cd > 0.0:
		App.toast("Potion cooling down.")
		return "Not ready."
	var pl: CharacterBody3D = p._player()
	if pl == null or not pl.has_method("heal"):
		return "Not now."
	pl.heal(App.bal.potion_heal if App.bal.potion_heal > 1.0 else App.bal.player_max_hp * App.bal.potion_heal)
	p.potion_cd = App.bal.potion_cooldown
	App.sfx("potion")
	App.toast("Potion — instant.")
	consume(p, it, from_slot)
	return "Potion."


static func eat(p, it: Dictionary, from_slot: bool) -> String:
	var fid := str(it.get("food", "ration"))
	if p.food_t > 0.0 and fid == p.food_id:
		App.toast("That food is already working.")
		return "Already eating that."
	if p.food_t > 0.0 and fid != p.food_id:
		p.clear_food()
	p.food_id = fid
	p.food_t = App.bal.food_hot_y
	p.food_left = App.bal.food_hot_x
	App.sfx("food")
	App.toast("Food — healing over time.")
	consume(p, it, from_slot)
	return "Food."


static func consume(p, it: Dictionary, from_slot: bool) -> void:
	it.stack = int(it.stack) - 1
	if from_slot:
		if int(it.stack) <= 0:
			p.slots[str(it.slot)] = {}
		else:
			p.slots[str(it.slot)] = it
	else:
		if int(it.stack) <= 0:
			remove_uid(p, int(it.uid))
		else:
			for i in p.bag.size():
				if int(p.bag[i].uid) == int(it.uid):
					p.bag[i] = it
					break


static func tick_food(p, delta: float) -> void:
	p.potion_cd = maxf(0.0, p.potion_cd - delta)
	if p.food_t <= 0.0:
		return
	var pl: CharacterBody3D = p._player()
	var step: float = App.bal.food_hot_x * delta / maxf(0.1, App.bal.food_hot_y)
	step = minf(step, p.food_left)
	p.food_left -= step
	p.food_t = maxf(0.0, p.food_t - delta)
	if pl and pl.has_method("heal"):
		pl.heal(step)
	if p.food_t <= 0.0 or p.food_left <= 0.0:
		p.clear_food()
