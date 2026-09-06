extends RefCounted

const CatalogS := preload("res://scripts/data/catalog.gd")
const Gear := preload("res://scripts/data/progress_gear.gd")
const CombatP := preload("res://scripts/data/progress_combat.gd")
const Town := preload("res://scripts/data/progress_town.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")

const SKILLS: PackedStringArray = ["axe", "staff", "bow", "str", "mag", "rng", "def", "hp", "mine", "wood", "smith"]
const SLOTS: PackedStringArray = ["weapon", "tool", "potion", "food", "head", "body", "legs"]
const SETS: PackedStringArray = ["cinder", "tide", "root", "ash", "spark", "bone", "veil", "iron"]

var bag: Array = []
var slots: Dictionary = {}
var holds: Dictionary = {}
var starters: Dictionary = {}
var tool_type := "pickaxe"
var pick_weapon := "great_axe"
var skills_run: Dictionary = {}
var skills_perm: Dictionary = {}
var next_uid := 1
var deepest := 1
var start_floor := 1
var food_id := ""
var food_t := 0.0
var food_left := 0.0
var potion_cd := 0.0
var root := 0
var bank_items: Array = []
var quests_offered: Array = []
var quest_active: Dictionary = {}
var forge_count := 0
var hold_pick: Dictionary = {}
var mailed_gold := 0
var mailed_ore := 0
var mailed_wood := 0
var mailed_root := 0
var mailed_names: PackedStringArray = PackedStringArray()
var analyzed: Array = []


func _init() -> void:
	reset_meta()


func reset_meta() -> void:
	holds.clear()
	starters.clear()
	for s in SLOTS:
		holds[s] = []
		slots[s] = {}
		starters[s] = []
	skills_run.clear()
	skills_perm.clear()
	for id in SKILLS:
		skills_run[id] = 0.0
		skills_perm[id] = 0.0
	bag.clear()
	bank_items.clear()
	analyzed.clear()
	tool_type = "pickaxe"
	deepest = 1
	start_floor = 1
	root = 0
	next_uid = 1
	quests_offered = []
	quest_active = {}
	forge_count = 0
	hold_pick.clear()
	_clear_mailed()
	clear_food()
	Gear.ensure_required_slots(self)


func begin_run_loadout() -> void:
	for it in bag:
		if str(it.get("kind", "")) != "artifact":
			bank_items.append(it)
	bag.clear()
	clear_food()
	potion_cd = 0.0
	for id in SKILLS:
		skills_run[id] = 0.0
	var keep_pot: Dictionary = (slots.get("potion", {}) as Dictionary).duplicate(true)
	var keep_food: Dictionary = (slots.get("food", {}) as Dictionary).duplicate(true)
	for s in SLOTS:
		if s == "potion" or s == "food":
			continue
		slots[s] = _slot_for_run(s)
	if not keep_pot.is_empty():
		slots["potion"] = keep_pot
	else:
		slots["potion"] = _slot_for_run("potion")
	if not keep_food.is_empty() and int(keep_food.get("stack", 0)) > 0:
		slots["food"] = keep_food
	else:
		slots["food"] = _slot_for_run("food")
	Rules.refill_potion(self)
	tool_type = str(slots.tool.get("tool", tool_type))
	App.weapon = str(slots.weapon.get("weapon", pick_weapon))
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.run_artifacts.clear()
	_sync_artifacts()
	_clamp_food_slot()
	_clear_mailed()
	if str(quest_active.get("kind", "")) == "ore":
		quest_active.have = 0


func _slot_for_run(s: String) -> Dictionary:
	if s == "weapon" or s == "tool":
		return Gear.required_piece(self, s)
	var h: Array = holds[s]
	var fallback := 0 if h.size() > 0 else -1
	var pi := int(hold_pick.get(s, fallback))
	if pi >= 0 and pi < h.size():
		return (h[pi] as Dictionary).duplicate(true)
	return Gear.starter(self, s)


func lose_unextracted() -> void:
	bag.clear()
	App.gold = 0
	App.ore = 0
	App.wood = 0
	root = 0
	App.run_artifacts.clear()
	clear_food()
	for s in SLOTS:
		slots[s] = {}
	_sync_artifacts()
	Gear.ensure_required_slots(self)


func _clear_mailed() -> void:
	mailed_gold = 0
	mailed_ore = 0
	mailed_wood = 0
	mailed_root = 0
	mailed_names = PackedStringArray()


func _clamp_food_slot() -> void:
	if App.in_dungeon:
		return
	var cap := int(App.bal.food_bring_max)
	var fd: Dictionary = slots.get("food", {})
	if fd.is_empty():
		return
	if int(fd.get("stack", 0)) > cap:
		fd.stack = cap
		slots["food"] = fd


func make_weapon(wpn: String, rarity: String) -> Dictionary:
	return Gear.make_weapon(self, wpn, rarity)


func make_tool(kind: String) -> Dictionary:
	return Gear.make_tool(self, kind)


func make_armor(slot: String, rarity: String) -> Dictionary:
	return Gear.make_armor(self, slot, rarity)


func make_potion(n: int) -> Dictionary:
	return Gear.make_potion(self, n)


func make_food(fid: String, n: int) -> Dictionary:
	return Gear.make_food(self, fid, n)


func make_artifact(id: String) -> Dictionary:
	return Gear.make_artifact(self, id)


func bag_count() -> int:
	return bag.size()


func bag_full() -> bool:
	return bag.size() >= int(App.bal.bag_cap)


func add_item(it: Dictionary) -> bool:
	return Gear.add_item(self, it)


func bag_can_accept(it: Dictionary) -> bool:
	return Gear.bag_can_accept(self, it)


func add_to_bag(it: Dictionary) -> bool:
	return Gear.add_to_bag(self, it)


func remove_uid(uid: int) -> Dictionary:
	return Gear.remove_uid(self, uid)


func equip_uid(uid: int) -> String:
	return Gear.equip_uid(self, uid)


func drop_uid(uid: int) -> String:
	return Gear.drop_uid(self, uid)


func unequip_slot(slot: String) -> String:
	return Gear.unequip_slot(self, slot)


func drop_slot(slot: String) -> String:
	return Gear.drop_slot(self, slot)


func take_slot(slot: String) -> Dictionary:
	return Gear.take_slot(self, slot)


func drop_stash(uid: int) -> String:
	return Gear.drop_stash(self, uid)


func give_or_drop(it: Dictionary, pos: Vector3) -> bool:
	return Gear.give_or_drop(self, it, pos)


func use_from_bag(uid: int) -> String:
	return Gear.use_from_bag(self, uid)


func use_potion() -> String:
	return Gear.use_potion(self)


func use_food() -> String:
	return Gear.use_food(self)


func tick_food(delta: float) -> void:
	Gear.tick_food(self, delta)


func clear_food() -> void:
	food_id = ""
	food_t = 0.0
	food_left = 0.0


func skill_xp(id: String) -> float:
	return CombatP.skill_xp(self, id)


func skill_lv(id: String) -> int:
	return CombatP.skill_lv(self, id)


func xp_period() -> float:
	return CombatP.xp_period()


func xp_unit() -> float:
	return CombatP.xp_unit()


func xp_to_reach(level: int) -> float:
	return CombatP.xp_to_reach(level)


func level_from_xp(total: float) -> int:
	return CombatP.level_from_xp(self, total)


func xp_to_next(total: float) -> float:
	return CombatP.xp_to_next(self, total)


func xp_ratio(total: float) -> float:
	return CombatP.xp_ratio(self, total)


func add_run_xp(id: String, amt: float) -> void:
	CombatP.add_run_xp(self, id, amt)


func add_perm_xp(id: String, amt: float) -> void:
	CombatP.add_perm_xp(self, id, amt)


func skill_dmg_mult(is_special := false) -> float:
	return CombatP.skill_dmg_mult(self, is_special)


func skill_def() -> float:
	return CombatP.skill_def(self)


func skill_hp() -> float:
	return CombatP.skill_hp(self)


func tool_quality() -> float:
	return CombatP.tool_quality(self)


func skill_grant_hit(is_special := false) -> void:
	CombatP.skill_grant_hit(self, is_special)


func keep_fragments() -> void:
	CombatP.keep_fragments(self)


func melee_lv_f() -> float:
	return CombatP.melee_lv_f(self)


func magic_lv_f() -> float:
	return CombatP.magic_lv_f(self)


func ranged_lv_f() -> float:
	return CombatP.ranged_lv_f(self)


func combat_lv_f() -> float:
	return CombatP.combat_lv_f(self)


func style_lv_f() -> float:
	return CombatP.style_lv_f(self)


func melee_lv() -> int:
	return CombatP.combat_iv(self, "axe", "str")


func magic_lv() -> int:
	return CombatP.combat_iv(self, "staff", "mag")


func ranged_lv() -> int:
	return CombatP.combat_iv(self, "bow", "rng")


func combat_lv() -> int:
	return maxi(1, int(round(combat_lv_f())))


func style_lv() -> int:
	return maxi(1, int(round(style_lv_f())))


func gear_dmg() -> float:
	return CombatP.gear_stat(self, "dmg")


func gear_def() -> float:
	return CombatP.gear_stat(self, "def")


func gear_hp() -> float:
	return CombatP.gear_stat(self, "hp")


func set_counts() -> Dictionary:
	return CombatP.set_counts(self)


func set_stats() -> Dictionary:
	return CombatP.set_stats(self)


func set_bonus_text(set_id: String) -> String:
	return CombatP.set_bonus_text(self, set_id)


func _sync_artifacts() -> void:
	CombatP.sync_artifacts(self)


func extractable(role := "") -> Array:
	return Town.extractable(self, role)


func extract_all(role: String) -> String:
	return Town.extract_all(self, role)


func extract_one(it: Dictionary, role: String) -> String:
	return Town.extract_one(self, it, role)


func forge_cost(first: bool) -> Dictionary:
	return Town.forge_cost(self, first)


func forge_duration() -> float:
	return Town.forge_duration(self)


func can_pay(c: Dictionary) -> bool:
	return Town.can_pay(self, c)


func pay(c: Dictionary) -> void:
	Town.pay(self, c)


func forge_item(it: Dictionary) -> String:
	if bool(it.get("hold", false)) or str(it.get("anvil_src", "")) == "hold":
		return Town.forge_item(self, it)
	if str(it.get("anvil_src", "")) == "analyzed" or Town.has_analyzed(self, int(it.get("uid", 0))):
		return Town.forge_item(self, it)
	if not Rules.can_forge(self, it):
		return "Starters cannot be forged."
	return "Analyze the piece first."


func roll_quests(keep_active: bool) -> void:
	Town.roll_quests(self, keep_active)


func accept_quest(i: int) -> String:
	return Town.accept_quest(self, i)


func abandon_quest() -> String:
	return Town.abandon_quest(self)


func note_kill(type_id: String, named: String) -> void:
	Town.note_kill(self, type_id, named)


func note_fetch() -> void:
	Town.note_fetch(self)


func _refresh_player_hp() -> void:
	CombatP.refresh_player_hp(self)


func _player() -> Node:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	return (tree as SceneTree).get_first_node_in_group("player")


func to_meta() -> Dictionary:
	var m := Town.to_meta(self)
	m["analyzed"] = analyzed.duplicate(true)
	return m


func from_meta(d: Dictionary) -> void:
	Town.from_meta(self, d)
	var raw: Variant = d.get("analyzed", [])
	analyzed = raw.duplicate(true) if raw is Array else []
	Gear.ensure_required_slots(self)


func restock() -> String:
	return Town.restock(self)
