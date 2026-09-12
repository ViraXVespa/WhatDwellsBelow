extends Object

const Gear := preload("res://scripts/data/progress_gear.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Town := preload("res://scripts/data/progress_town.gd")

static func reset_meta(p: Object) -> void:
	p.holds.clear()
	p.starters.clear()
	for s in p.SLOTS:
		p.holds[s] = []
		p.slots[s] = {}
		p.starters[s] = []
	p.skills_run.clear()
	p.skills_perm.clear()
	for id in p.SKILLS:
		p.skills_run[id] = 0.0
		p.skills_perm[id] = 0.0
	p.bag.clear()
	p.bank_items.clear()
	p.analyzed.clear()
	p.forge_book.clear()
	p.tool_type = "pickaxe"
	p.deepest = 1
	p.start_floor = 1
	p.root = 0
	p.next_uid = 1
	p.quests_offered = []
	p.quest_active = {}
	p.forge_count = 0
	p.hold_pick.clear()
	p._clear_mailed()
	p.clear_food()
	Gear.ensure_required_slots(p)



static func begin_run_loadout(p: Object) -> void:
	for it in p.bag:
		if str(it.get("kind", "")) != "artifact":
			p.bank_items.append(it)
	p.bag.clear()
	p.clear_food()
	p.potion_cd = 0.0
	for id in p.SKILLS:
		p.skills_run[id] = 0.0
	var keep_pot: Dictionary = (p.slots.get("potion", {}) as Dictionary).duplicate(true)
	var keep_food: Dictionary = (p.slots.get("food", {}) as Dictionary).duplicate(true)
	for s in p.SLOTS:
		if s == "potion" or s == "food":
			continue
		p.slots[s] = p._slot_for_run(s)
	if not keep_pot.is_empty():
		p.slots["potion"] = keep_pot
	else:
		p.slots["potion"] = p._slot_for_run("potion")
	if not keep_food.is_empty() and int(keep_food.get("stack", 0)) > 0:
		p.slots["food"] = keep_food
	else:
		p.slots["food"] = p._slot_for_run("food")
	Rules.refill_potion(p)
	p.tool_type = str(p.slots.tool.get("tool", p.tool_type))
	App.weapon = str(p.slots.weapon.get("weapon", p.pick_weapon))
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.run_artifacts.clear()
	p._sync_artifacts()
	p._clamp_food_slot()
	p._clear_mailed()
	if str(p.quest_active.get("kind", "")) == "ore":
		p.quest_active.have = 0



static func _slot_for_run(p: Object, s: String) -> Dictionary:
	if s == "weapon" or s == "tool":
		return Gear.required_piece(p, s)
	var h: Array = p.holds[s]
	var fallback := 0 if h.size() > 0 else -1
	var pi := int(p.hold_pick.get(s, fallback))
	if pi >= 0 and pi < h.size():
		return (h[pi] as Dictionary).duplicate(true)
	return Gear.starter(p, s)



static func lose_unextracted(p: Object) -> void:
	p.bag.clear()
	App.gold = 0
	App.ore = 0
	App.wood = 0
	p.root = 0
	App.run_artifacts.clear()
	p.clear_food()
	for s in p.SLOTS:
		p.slots[s] = {}
	p._sync_artifacts()
	Gear.ensure_required_slots(p)



static func _clear_mailed(p: Object) -> void:
	p.mailed_gold = 0
	p.mailed_ore = 0
	p.mailed_wood = 0
	p.mailed_root = 0
	p.mailed_names = PackedStringArray()



static func _clamp_food_slot(p: Object) -> void:
	if App.in_dungeon:
		return
	var cap := int(App.bal.food_bring_max)
	var fd: Dictionary = p.slots.get("food", {})
	if fd.is_empty():
		return
	if int(fd.get("stack", 0)) > cap:
		fd.stack = cap
		p.slots["food"] = fd



static func clear_food(p: Object) -> void:
	p.food_id = ""
	p.food_t = 0.0
	p.food_left = 0.0



static func to_meta(p: Object) -> Dictionary:
	var m := Town.to_meta(p)
	m["analyzed"] = p.analyzed.duplicate(true)
	m["forge_book"] = p.forge_book.duplicate(true)
	return m



static func from_meta(p: Object, d: Dictionary) -> void:
	Town.from_meta(p, d)
	var raw: Variant = d.get("analyzed", [])
	p.analyzed = raw.duplicate(true) if raw is Array else []
	var book: Variant = d.get("forge_book", {})
	p.forge_book = book.duplicate(true) if book is Dictionary else {}
	ForgeP.migrate(p)
	Gear.ensure_required_slots(p)



