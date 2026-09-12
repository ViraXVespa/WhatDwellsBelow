extends Object

## Quest kill/fetch/ore notes and completion.


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
