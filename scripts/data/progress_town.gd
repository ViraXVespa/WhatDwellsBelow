extends Object


static func extractable(p, role := "") -> Array:
	var out: Array = []
	var gather := role == "" or role == "gather" or role == "patty"
	var misc := role == "" or role == "misc" or role == "patty"
	if gather:
		if App.ore > 0:
			out.append({"kind": "ore", "name": "Ore", "n": App.ore})
		if App.wood > 0:
			out.append({"kind": "wood", "name": "Wood", "n": App.wood})
		if p.root > 0:
			out.append({"kind": "root", "name": "Root", "n": p.root})
	if misc:
		if App.gold > 0:
			out.append({"kind": "gold", "name": "Gold", "n": App.gold})
		for it in p.bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and str(it.kind) != "tool" and not bool(it.get("hold", false)):
				out.append(it)
	return out


static func extract_all(p, role: String) -> String:
	var g := 0
	var o := 0
	var w := 0
	var r := 0
	var items := 0
	if role == "gather" or role == "patty":
		o = App.ore
		w = App.wood
		r = p.root
		App.bank_ore += App.ore
		App.bank_wood += App.wood
		App.bank_root += p.root
		quest_extract_ore(p, App.ore)
		App.ore = 0
		App.wood = 0
		p.root = 0
		p.mailed_ore += o
		p.mailed_wood += w
		p.mailed_root += r
	if role == "misc" or role == "patty":
		g = App.gold
		App.bank_gold += App.gold
		App.gold = 0
		p.mailed_gold += g
		var keep: Array = []
		for it in p.bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and str(it.kind) != "tool" and not bool(it.get("hold", false)):
				p.bank_items.append(it)
				p.mailed_names.append(str(it.name))
				items += 1
			else:
				keep.append(it)
		p.bag = keep
	App.extracted = g + o + w + r + items > 0
	if App.extracted:
		App.toast("Sent to the surface.")
		if App.tel:
			App.tel.note_extract(g, o, w)
			App.tel.forge_n = p.forge_count
	return "Banked %dg, %d ore, %d wood, %d root, %d items." % [g, o, w, r, items]


static func extract_one(p, it: Dictionary, role: String) -> String:
	var k := str(it.get("kind", ""))
	if k == "gold" and (role == "misc" or role == "patty"):
		App.bank_gold += App.gold
		var n := App.gold
		App.gold = 0
		App.extracted = true
		p.mailed_gold += n
		return "Sent %dg." % n
	if k == "ore" and (role == "gather" or role == "patty"):
		quest_extract_ore(p, App.ore)
		App.bank_ore += App.ore
		var n := App.ore
		App.ore = 0
		App.extracted = true
		p.mailed_ore += n
		return "Sent %d ore." % n
	if k == "wood" and (role == "gather" or role == "patty"):
		App.bank_wood += App.wood
		var n := App.wood
		App.wood = 0
		App.extracted = true
		p.mailed_wood += n
		return "Sent %d wood." % n
	if k == "root" and (role == "gather" or role == "patty"):
		var n: int = p.root
		App.bank_root += p.root
		p.root = 0
		App.extracted = true
		p.mailed_root += n
		return "Sent %d root." % n
	if role == "gather":
		return "This clerk takes ore, wood, and root."
	if it.has("from_slot"):
		return "Unequip that first."
	if it.has("uid"):
		var got: Dictionary = p.remove_uid(int(it.uid))
		if got.is_empty():
			return "Gone."
		if str(got.kind) == "artifact" or bool(got.get("hold", false)):
			if str(got.kind) == "artifact":
				p.add_to_bag(got)
				return "Artifacts cannot be mailed."
			p.add_to_bag(got)
			return "Forged holds stay with you."
		p.bank_items.append(got)
		App.extracted = true
		p.mailed_names.append(str(got.name))
		return "Sent " + str(got.name)
	return "Nothing."


static func forge_cost(p, first: bool) -> Dictionary:
	var sm: int = p.skill_lv("smith")
	var g: int = int(App.bal.forge_gold) - sm * 2
	var o: int = int(App.bal.forge_ore) - sm
	var r: int = int(App.bal.forge_root)
	if not first:
		g = maxi(4, int(g * 0.55))
		o = maxi(1, int(o * 0.55))
		r = maxi(0, int(r * 0.4))
	return {"gold": maxi(4, g), "ore": maxi(1, o), "root": maxi(0, r)}


static func forge_duration(p) -> float:
	var sm: int = p.skill_lv("smith")
	return maxf(0.2, App.bal.forge_time / (1.0 + float(maxi(0, sm - 1)) * 0.12))


static func can_pay(p, c: Dictionary) -> bool:
	return App.bank_gold + App.gold >= int(c.gold) and App.bank_ore + App.ore >= int(c.ore) and App.bank_root + p.root >= int(c.root)


static func pay(p, c: Dictionary) -> void:
	var g := int(c.gold)
	var use := mini(App.gold, g)
	App.gold -= use
	g -= use
	App.bank_gold = maxi(0, App.bank_gold - g)
	var o := int(c.ore)
	use = mini(App.ore, o)
	App.ore -= use
	o -= use
	App.bank_ore = maxi(0, App.bank_ore - o)
	var rpay := int(c.root)
	use = mini(p.root, rpay)
	p.root -= use
	rpay -= use
	App.bank_root = maxi(0, App.bank_root - rpay)


static func forge_item(p, it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if p.SLOTS.find(slot) < 0 or slot == "potion" or slot == "food":
		return "The anvil won't take that."
	var h: Array = p.holds[slot]
	var first := h.size() < 3
	var cost := forge_cost(p, first and not bool(it.get("hold", false)))
	if not can_pay(p, cost):
		App.toast("Not enough gold / ore / root.")
		return "Need %dg, %d ore, %d root." % [cost.gold, cost.ore, cost.root]
	pay(p, cost)
	if bool(it.get("hold", false)):
		for i in h.size():
			if int(h[i].uid) == int(it.uid):
				var up: Dictionary = (h[i] as Dictionary).duplicate(true)
				up.dmg = int(up.dmg) + 1 + int(p.skill_lv("smith") / 4)
				up.def = int(up.def) + 1
				if str(up.rarity) == "white":
					up.rarity = "green"
				h[i] = up
				p.holds[slot] = h
				p.forge_count += 1
				p.add_perm_xp("smith", App.bal.xp_smith)
				App.sfx("slam")
				App.toast("Hold re-forged.")
				App.save_now()
				return "Re-forged hold (%d/3)." % h.size()
	var copy := it.duplicate(true)
	copy.hold = true
	copy.extract = false
	copy.rarity = "green" if copy.rarity == "white" else copy.rarity
	copy.dmg = int(copy.dmg) + 1 + int(p.skill_lv("smith") / 4)
	copy.def = int(copy.def) + 1
	if not str(copy.name).begins_with("Forged "):
		copy.name = "Forged " + str(copy.name)
	if h.size() >= 3:
		h.remove_at(0)
	h.append(copy)
	p.holds[slot] = h
	p.forge_count += 1
	consume_forge_source(p, it)
	p.add_perm_xp("smith", App.bal.xp_smith)
	App.sfx("slam")
	App.toast("Hold forged.")
	App.save_now()
	return "Forged into a hold (%d/3)." % h.size()


static func consume_forge_source(p, it: Dictionary) -> void:
	if it.has("uid"):
		p.remove_uid(int(it.uid))
		for i in p.bank_items.size():
			if int(p.bank_items[i].uid) == int(it.uid):
				p.bank_items.remove_at(i)
				break


static func roll_quests(p, keep_active: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var types: PackedStringArray = ["slime", "goblin", "bat", "spider", "archer", "orc", "wolf"]
	var kt := types[rng.randi() % types.size()]
	var nt := types[rng.randi() % types.size()]
	var ff := maxi(1, rng.randi_range(1, maxi(1, p.deepest)))
	var pool: Array = [
		{"kind": "kill", "title": "Cull the %s" % kt, "type": kt, "need": int(App.bal.quest_kill_need), "have": 0, "reward": "xp"},
		{"kind": "ore", "title": "Mail %d ore" % int(App.bal.quest_ore_need), "need": int(App.bal.quest_ore_need), "have": 0, "reward": "gold"},
		{"kind": "fetch", "title": "Retrieve a guild cache from floor %d" % ff, "floor": ff, "have": 0, "need": 1, "reward": "gear"},
		{"kind": "named", "title": "Vanquish a named foe", "type": nt, "nname": "", "need": 1, "have": 0, "reward": "xp"},
	]
	p.quests_offered = []
	var used := {}
	while p.quests_offered.size() < 3 and pool.size() > 0:
		var i := rng.randi() % pool.size()
		var q: Dictionary = pool[i]
		pool.remove_at(i)
		if used.has(q.kind):
			continue
		used[q.kind] = true
		if str(q.kind) == "named":
			q.nname = "Gra" + ["tok", "nash", "rath"][rng.randi() % 3]
			q.title = "Vanquish %s the %s" % [q.nname, q.type]
		p.quests_offered.append(q)
	if keep_active and not p.quest_active.is_empty() and int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		pass
	elif not keep_active:
		p.quest_active = {}
		App.quest_named_type = ""
		App.quest_named_name = ""


static func accept_quest(p, i: int) -> String:
	if i < 0 or i >= p.quests_offered.size():
		return "None."
	if not p.quest_active.is_empty() and int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		return "Finish or abandon the current task first."
	p.quest_active = p.quests_offered[i].duplicate(true)
	if str(p.quest_active.kind) == "named":
		if str(p.quest_active.get("nname", "")) == "":
			p.quest_active.nname = "Gra" + ["tok", "nash", "rath"][randi() % 3]
			p.quest_active.title = "Vanquish %s the %s" % [p.quest_active.nname, p.quest_active.type]
		App.quest_named_type = str(p.quest_active.type)
		App.quest_named_name = str(p.quest_active.nname)
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""
	App.toast("Quest: " + str(p.quest_active.title))
	return "Accepted."


static func abandon_quest(p) -> String:
	if p.quest_active.is_empty():
		return "No task."
	p.quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""
	App.toast("Task abandoned.")
	return "Abandoned."


static func note_kill(p, type_id: String, named: String) -> void:
	if p.quest_active.is_empty():
		return
	if str(p.quest_active.kind) == "kill" and type_id == str(p.quest_active.get("type", "")):
		p.quest_active.have = int(p.quest_active.have) + 1
	if str(p.quest_active.kind) == "named" and named != "" and named == str(p.quest_active.get("nname", "")):
		p.quest_active.have = int(p.quest_active.need)
	try_complete(p)


static func note_fetch(p) -> void:
	if str(p.quest_active.get("kind", "")) == "fetch":
		p.quest_active.have = 1
		try_complete(p)


static func quest_extract_ore(p, n: int) -> void:
	if str(p.quest_active.get("kind", "")) == "ore":
		p.quest_active.have = int(p.quest_active.get("have", 0)) + n
		try_complete(p)


static func try_complete(p) -> void:
	if p.quest_active.is_empty():
		return
	if int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		return
	var rw := str(p.quest_active.get("reward", "gold"))
	if rw == "xp":
		var sa: String = p.SKILLS[randi() % p.SKILLS.size()]
		var sb: String = p.SKILLS[randi() % p.SKILLS.size()]
		p.skills_perm[sa] = float(p.skills_perm.get(sa, 0.0)) + App.bal.quest_xp_a
		p.skills_perm[sb] = float(p.skills_perm.get(sb, 0.0)) + App.bal.quest_xp_b
		App.toast("Quest complete — %s / %s XP." % [sa, sb])
		p._refresh_player_hp()
	elif rw == "gear":
		p.bank_items.append(unowned_gear(p))
		App.toast("Quest complete — gear mailed to stash.")
	else:
		App.bank_gold += int(App.bal.quest_gold)
		App.toast("Quest complete — %dg banked." % int(App.bal.quest_gold))
	p.quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""


static func unowned_gear(p) -> Dictionary:
	for s in ["head", "body", "legs"]:
		if (p.holds[s] as Array).is_empty():
			return p.make_armor(s, "green")
	return p.make_weapon(p.pick_weapon, "green")


static func to_meta(p) -> Dictionary:
	var h := {}
	for s in p.SLOTS:
		h[s] = p.holds[s]
	var sl := {}
	for s in p.SLOTS:
		sl[s] = p.slots[s]
	return {
		"holds": h,
		"slots": sl,
		"skills_perm": p.skills_perm.duplicate(),
		"deepest": p.deepest,
		"start_floor": p.start_floor,
		"tool_type": p.tool_type,
		"pick_weapon": p.pick_weapon,
		"root": p.root,
		"next_uid": p.next_uid,
		"bank_items": p.bank_items.duplicate(true),
		"quest_active": p.quest_active.duplicate(true),
		"quests_offered": p.quests_offered.duplicate(true),
		"forge_count": p.forge_count,
		"hold_pick": p.hold_pick.duplicate(),
	}


static func from_meta(p, d: Dictionary) -> void:
	p.reset_meta()
	var h: Variant = d.get("holds", {})
	if h is Dictionary:
		for s in p.SLOTS:
			if h.has(s) and h[s] is Array:
				p.holds[s] = (h[s] as Array).duplicate(true)
	var sp: Variant = d.get("skills_perm", {})
	if sp is Dictionary:
		for id in p.SKILLS:
			p.skills_perm[id] = float(sp.get(id, 0.0))
	p.deepest = maxi(1, int(d.get("deepest", 1)))
	p.start_floor = clampi(int(d.get("start_floor", 1)), 1, p.deepest)
	p.tool_type = str(d.get("tool_type", "pickaxe"))
	p.pick_weapon = str(d.get("pick_weapon", "great_axe"))
	p.root = int(d.get("root", 0))
	p.next_uid = maxi(1, int(d.get("next_uid", 1)))
	var sl: Variant = d.get("slots", {})
	if sl is Dictionary:
		for s in p.SLOTS:
			if sl.has(s) and sl[s] is Dictionary:
				p.slots[s] = (sl[s] as Dictionary).duplicate(true)
	var bi: Variant = d.get("bank_items", [])
	if bi is Array:
		p.bank_items = bi.duplicate(true)
	var qa: Variant = d.get("quest_active", {})
	if qa is Dictionary:
		p.quest_active = qa.duplicate(true)
	var qo: Variant = d.get("quests_offered", [])
	if qo is Array:
		p.quests_offered = (qo as Array).duplicate(true)
	p.forge_count = int(d.get("forge_count", 0))
	var hpicks: Variant = d.get("hold_pick", {})
	if hpicks is Dictionary:
		p.hold_pick = (hpicks as Dictionary).duplicate(true)
	if str(p.quest_active.get("kind", "")) == "named":
		App.quest_named_type = str(p.quest_active.get("type", ""))
		App.quest_named_name = str(p.quest_active.get("nname", ""))
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""


static func withdraw_bank_consumables(p) -> void:
	var keep: Array = []
	for it in p.bank_items:
		var k := str(it.get("kind", ""))
		if k == "potion" or k == "food":
			var slot := "potion" if k == "potion" else "food"
			var cur: Dictionary = p.slots.get(slot, {})
			if cur.is_empty():
				p.slots[slot] = it
			elif k == "potion" or str(cur.get("food", "")) == str(it.get("food", "")):
				cur.stack = int(cur.get("stack", 0)) + int(it.get("stack", 1))
				p.slots[slot] = cur
			else:
				keep.append(it)
		else:
			keep.append(it)
	p.bank_items = keep


static func restock(p) -> String:
	withdraw_bank_consumables(p)
	var msg := ""
	if App.bank_gold < int(App.bal.restock_gold):
		App.bank_gold = int(App.bal.restock_gold)
		msg += "A few coins. "
	var need_p := int(App.bal.restock_potion)
	var pot: Dictionary = p.slots.get("potion", {})
	if need_p > 0 and (pot.is_empty() or int(pot.get("stack", 0)) < need_p):
		p.slots["potion"] = p.make_potion(need_p)
		msg += "Potions. "
	var need_f := int(App.bal.restock_food)
	var fd: Dictionary = p.slots.get("food", {})
	if need_f > 0 and (fd.is_empty() or int(fd.get("stack", 0)) < need_f):
		p.slots["food"] = p.make_food("ration", need_f)
		msg += "Rations. "
	if msg == "":
		return ""
	return "The guild slips you a restock: " + msg
