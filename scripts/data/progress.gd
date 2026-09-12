
extends RefCounted

const CatalogS := preload("res://scripts/data/catalog.gd")
const Gear := preload("res://scripts/data/progress_gear.gd")
const CombatP := preload("res://scripts/data/progress_combat.gd")
const Town := preload("res://scripts/data/progress_town.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Boot := preload("res://scripts/data/progress_boot.gd")

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
var forge_book: Dictionary = {}


func _init() -> void:
	reset_meta()
	ForgeP.migrate(self)



func reset_meta() -> void:
	Boot.reset_meta(self)

func begin_run_loadout() -> void:
	Boot.begin_run_loadout(self)

func _slot_for_run(s: String) -> Dictionary:
	return Boot._slot_for_run(self, s)

func lose_unextracted() -> void:
	Boot.lose_unextracted(self)

func _clear_mailed() -> void:
	Boot._clear_mailed(self)

func _clamp_food_slot() -> void:
	Boot._clamp_food_slot(self)

func make_weapon(wpn: String, rarity: String, ilvl: int = 0) -> Dictionary:
	return Gear.make_weapon(self, wpn, rarity, ilvl)


func make_tool(kind: String, rarity := "white", ilvl: int = 0) -> Dictionary:
	return Gear.make_tool(self, kind, rarity, ilvl)


func make_armor(slot: String, rarity: String, ilvl: int = 0) -> Dictionary:
	return Gear.make_armor(self, slot, rarity, ilvl)


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
	Boot.clear_food(self)

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


func gear_stat(key: String) -> float:
	return CombatP.gear_stat(self, key)


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


func analyze_destroy(row: Dictionary) -> Dictionary:
	return Town.analyze_destroy(self, row)


func forge_cost(slot: String, rarity: String, ilvl: int, lock_n: int) -> Dictionary:
	return ForgeP.forge_cost(self, slot, rarity, ilvl, lock_n)


func forge_duration(slot: String, rarity: String, ilvl: int) -> float:
	return ForgeP.forge_duration(self, slot, rarity, ilvl)


func can_pay(c: Dictionary) -> bool:
	return ForgeP.can_pay(self, c)


func can_pay_forge(c: Dictionary) -> bool:
	return ForgeP.can_pay(self, c)


func pay(c: Dictionary) -> void:
	ForgeP.pay(self, c)


func pay_forge(c: Dictionary) -> bool:
	return ForgeP.pay(self, c)


func forge_item(it: Dictionary) -> String:
	# Player UX still points at the Forge tab when the piece is not forge-shaped.
	var slot := str(it.get("slot", ""))
	var type_id := ForgeP.type_of(it)
	if type_id == "":
		type_id = str(it.get("type_id", it.get("id", "")))
	var rarity := str(it.get("rarity", "white"))
	var ilvl := int(it.get("ilvl", 1))
	if slot == "" or type_id == "":
		return "Use the Forge tab."
	if slot not in ForgeP.FORGE_SLOTS:
		return "Use the Forge tab."
	return ForgeP.forge_hold(self, slot, type_id, rarity, ilvl)


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
	return Boot.to_meta(self)

func from_meta(d: Dictionary) -> void:
	Boot.from_meta(self, d)

func restock() -> String:
	return Town.restock(self)
