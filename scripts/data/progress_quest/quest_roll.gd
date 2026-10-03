extends Object

## Quest board offer roll / accept / abandon.

static func roll_quests(p: Object, keep_active: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var types: PackedStringArray = PackedStringArray(["slime", "goblin", "bat", "spider", "archer", "orc", "wolf"])
	var kt: String = types[rng.randi() % types.size()]
	var nt: String = types[rng.randi() % types.size()]
	var ff: int = maxi(1, rng.randi_range(1, maxi(1, p.deepest)))
	var pool: Array = [
		{"kind": "kill", "title": App.tr("quest_roll.cull_the") % kt, "type": kt, "need": int(App.bal.quest_kill_need), "have": 0, "reward": "xp"},
		{"kind": "ore", "title": App.tr("quest_roll.mail_ore") % int(App.bal.quest_ore_need), "need": int(App.bal.quest_ore_need), "have": 0, "reward": "gold"},
		{"kind": "fetch", "title": App.tr("quest_roll.retrieve_a_guild_cache_from") % ff, "floor": ff, "have": 0, "need": 1, "reward": "gear"},
		{"kind": "named", "title": App.tr("quest_roll.vanquish_a_named_foe"), "type": nt, "nname": "", "need": 1, "have": 0, "reward": "xp"},
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
			q.title = App.tr("common.vanquish_the") % [q.nname, q.type]
		p.quests_offered.append(q)
	if keep_active and not p.quest_active.is_empty() and int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		pass
	elif not keep_active:
		p.quest_active = {}
		App.quest_named_type = ""
		App.quest_named_name = ""

static func accept_quest(p: Object, i: int) -> String:
	if i < 0 or i >= p.quests_offered.size():
		return App.tr("quest_roll.none")
	if not p.quest_active.is_empty() and int(p.quest_active.get("have", 0)) < int(p.quest_active.get("need", 1)):
		return App.tr("quest_roll.finish_or_abandon_the_current")
	p.quest_active = p.quests_offered[i].duplicate(true)
	if str(p.quest_active.kind) == "named":
		if str(p.quest_active.get("nname", "")) == "":
			p.quest_active.nname = "Gra" + ["tok", "nash", "rath"][randi() % 3]
			p.quest_active.title = App.tr("common.vanquish_the") % [p.quest_active.nname, p.quest_active.type]
		App.quest_named_type = str(p.quest_active.type)
		App.quest_named_name = str(p.quest_active.nname)
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""
	App.toast("Quest: " + str(p.quest_active.title))
	return App.tr("quest_roll.accepted")

static func abandon_quest(p: Object) -> String:
	if p.quest_active.is_empty():
		return App.tr("quest_roll.no_task")
	p.quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""
	App.toast(App.tr("quest_roll.task_abandoned"))
	return App.tr("quest_roll.abandoned")
