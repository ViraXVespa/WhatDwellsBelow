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
