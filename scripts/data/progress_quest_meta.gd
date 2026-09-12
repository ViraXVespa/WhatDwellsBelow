extends Object

## Quest / gear meta serialize for progress saves.


static func starters_of(p: Object) -> Dictionary:
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
		"starters": starters_of(p),
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
