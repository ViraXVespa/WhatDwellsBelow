extends Object


static func roll_quests(p: Object, keep_active: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var types: PackedStringArray = PackedStringArray(["slime", "goblin", "bat", "spider", "archer", "orc", "wolf"])
	var kt: String = types[rng.randi() % types.size()]
	var nt: String = types[rng.randi() % types.size()]
	var ff: int = maxi(1, rng.randi_range(1, maxi(1, p.deepest)))
	var pool: Array = [
		{"kind": "kill", "title": "Cull the %s" % kt, "type": kt, "need": int(App.bal.quest_kill_need), "have": 0, "reward": "xp"},
		{"kind": "ore", "title": "Mail %d ore" % int(App.bal.quest_ore_need), "need": int(App.bal.quest_ore_need), "have": 0, "reward": "gold"},
		{"kind": "fetch", "title": "Retrieve a guild cache from floor %d" % ff, "floor": ff, "have": 0, "need": 1, "reward": "gear"},
		{"kind": "named", "title": "Vanquish a named foe", "type": nt, "nname": "", "need": 1, "have": 0, "reward": "xp"},
	]
	p.quests_offered = []
	var used: Dictionary = {}
	while p.quests_offered.size() < 3 and pool.size() > 0:
		var i: int = rng.randi() % pool.size()
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


static func accept_quest(p: Object, i: int) -> String:
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


static func abandon_quest(p: Object) -> String:
	if p.quest_active.is_empty():
		return "No task."
	p.quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""
	App.toast("Task abandoned.")
	return "Abandoned."


static func note_kill(p: Object, type_id: String, named: String) -> void:
	if p.quest_active.is_empty():
		return
	if str(p.quest_active.kind) == "kill" and type_id == str(p.quest_active.get("type", "")):
		p.quest_active.have = int(p.quest_active.have) + 1
	if str(p.quest_active.kind) == "named" and named != "" and named == str(p.quest_active.get("nname", "")):
		p.quest_active.have = int(p.quest_active.need)
	try_complete(p)


static func note_fetch(p: Object) -> void:
	if str(p.quest_active.get("kind", "")) == "fetch":
		p.quest_active.have = 1
		try_complete(p)


static func quest_extract_ore(p: Object, n: int) -> void:
	if str(p.quest_active.get("kind", "")) == "ore":
		p.quest_active.have = int(p.quest_active.get("have", 0)) + n
		try_complete(p)


static func try_complete(p: Object) -> void:
	if p.quest_active.is_empty():
		return
	if int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		return
	var rw: String = str(p.quest_active.get("reward", "gold"))
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


static func unowned_gear(p: Object) -> Dictionary:
	for s: String in ["head", "body", "legs"]:
		if (p.holds[s] as Array).is_empty():
			return p.make_armor(s, "green")
	return p.make_weapon(p.pick_weapon, "green")


static func _starters_of(p: Object) -> Dictionary:
	var s: Variant = p.get("starters")
	if s is Dictionary:
		return (s as Dictionary).duplicate(true)
	return {}


static func to_meta(p: Object) -> Dictionary:
	var h: Dictionary = {}
	for s: String in p.SLOTS:
		h[s] = p.holds[s]
	var sl: Dictionary = {}
	for s2: String in p.SLOTS:
		sl[s2] = p.slots[s2]
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
		"starters": _starters_of(p),
	}


static func from_meta(p: Object, d: Dictionary) -> void:
	p.reset_meta()
	var hv: Variant = d.get("holds", {})
	if hv is Dictionary:
		for s: String in p.SLOTS:
			if hv.has(s) and hv[s] is Array:
				p.holds[s] = (hv[s] as Array).duplicate(true)
	var sp: Variant = d.get("skills_perm", {})
	if sp is Dictionary:
		for id: String in p.SKILLS:
			p.skills_perm[id] = float(sp.get(id, 0.0))
	p.deepest = maxi(1, int(d.get("deepest", 1)))
	p.start_floor = clampi(int(d.get("start_floor", 1)), 1, p.deepest)
	p.tool_type = str(d.get("tool_type", "pickaxe"))
	p.pick_weapon = str(d.get("pick_weapon", "great_axe"))
	p.root = int(d.get("root", 0))
	p.next_uid = maxi(1, int(d.get("next_uid", 1)))
	var slv: Variant = d.get("slots", {})
	if slv is Dictionary:
		for s3: String in p.SLOTS:
			if slv.has(s3) and slv[s3] is Dictionary:
				p.slots[s3] = (slv[s3] as Dictionary).duplicate(true)
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
	var st: Variant = d.get("starters", {})
	if st is Dictionary:
		p.starters = (st as Dictionary).duplicate(true)
	else:
		p.starters = {}
	if str(p.quest_active.get("kind", "")) == "named":
		App.quest_named_type = str(p.quest_active.get("type", ""))
		App.quest_named_name = str(p.quest_active.get("nname", ""))
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""


static func restock(p: Object) -> String:
	var Extract := load("res://scripts/data/progress_extract.gd")
	Extract.withdraw_bank_consumables(p)
	var msg: String = ""
	if App.bank_gold < int(App.bal.restock_gold):
		App.bank_gold = int(App.bal.restock_gold)
		msg += "A few coins. "
	var need_p: int = int(App.bal.restock_potion)
	var pot: Dictionary = p.slots.get("potion", {})
	var charges: int = int(pot.get("charges", pot.get("stack", 0)))
	if need_p > 0 and (pot.is_empty() or charges < need_p):
		p.slots["potion"] = p.make_potion(maxi(2, need_p))
		msg += "Potions. "
	var need_f: int = int(App.bal.restock_food)
	var fd: Dictionary = p.slots.get("food", {})
	if need_f > 0 and (fd.is_empty() or int(fd.get("stack", 0)) < need_f):
		p.slots["food"] = p.make_food("ration", need_f)
		msg += "Rations. "
	if msg == "":
		return ""
	return "The guild slips you a restock: " + msg
