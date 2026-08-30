extends RefCounted

## Run + meta progression for Phase 6.

const CatalogS := preload("res://scripts/data/catalog.gd")

const SKILLS: PackedStringArray = ["axe", "staff", "bow", "str", "mag", "rng", "def", "hp", "mine", "wood", "smith"]
const SLOTS: PackedStringArray = ["weapon", "tool", "potion", "food", "head", "body", "legs"]
const SETS: PackedStringArray = ["cinder", "tide", "root", "ash", "spark", "bone", "veil", "iron"]

var bag: Array = []
var slots: Dictionary = {}
var holds: Dictionary = {}
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


func _init() -> void:
	reset_meta()


func reset_meta() -> void:
	holds.clear()
	for s in SLOTS:
		holds[s] = []
		slots[s] = {}
	skills_run.clear()
	skills_perm.clear()
	for id in SKILLS:
		skills_run[id] = 0.0
		skills_perm[id] = 0.0
	bag.clear()
	bank_items.clear()
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
	if not keep_pot.is_empty() and int(keep_pot.get("stack", 0)) > 0:
		slots["potion"] = keep_pot
	else:
		slots["potion"] = _slot_for_run("potion")
	if not keep_food.is_empty() and int(keep_food.get("stack", 0)) > 0:
		slots["food"] = keep_food
	else:
		slots["food"] = _slot_for_run("food")
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
	var h: Array = holds[s]
	var fallback := 0 if h.size() > 0 else -1
	var pi := int(hold_pick.get(s, fallback))
	if pi >= 0 and pi < h.size():
		return (h[pi] as Dictionary).duplicate(true)
	if s == "weapon":
		return make_weapon(pick_weapon, "white")
	if s == "tool":
		return make_tool(tool_type)
	return _starter(s)


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


func _starter(slot: String) -> Dictionary:
	match slot:
		"weapon":
			return make_weapon("great_axe", "white")
		"tool":
			return make_tool(tool_type)
		"potion":
			return make_potion(3)
		"food":
			return make_food("ration", 5)
		_:
			return {}


func make_weapon(wpn: String, rarity: String) -> Dictionary:
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
	return _item("weapon", n, {"slot": "weapon", "weapon": wpn, "rarity": rarity, "dmg": dmg, "desc": "%s %s. +%d damage." % [rarity.capitalize(), n, dmg]})


func make_tool(kind: String) -> Dictionary:
	var n := "Pickaxe" if kind == "pickaxe" else "Hatchet"
	return _item("tool", n, {"slot": "tool", "tool": kind, "rarity": "white", "desc": "Run tool. Locked to %s." % kind})


func make_armor(slot: String, rarity: String) -> Dictionary:
	var def := int(App.bal.gear_white_def)
	var hp := int(App.bal.gear_white_hp)
	if rarity == "green":
		def = int(App.bal.gear_green_def)
		hp = int(App.bal.gear_green_hp)
	elif rarity == "blue":
		def = int(App.bal.gear_blue_def)
		hp = int(App.bal.gear_blue_hp)
	return _item(slot, "%s %s" % [rarity.capitalize(), slot.capitalize()], {"slot": slot, "rarity": rarity, "def": def, "hp": hp, "desc": "+%d def, +%d HP." % [def, hp]})


func make_potion(n: int) -> Dictionary:
	return _item("potion", "Potion", {"slot": "potion", "stack": n, "desc": "Instant heal."})


func make_food(fid: String, n: int) -> Dictionary:
	var nm := "Ration" if fid == "ration" else "Trail Bread"
	return _item("food", nm, {"slot": "food", "food": fid, "stack": n, "desc": "Heal-over-time."})


func make_artifact(id: String) -> Dictionary:
	var a: Dictionary = CatalogS.by_id(id)
	if a.is_empty():
		a = {"id": id, "name": id, "set": "", "desc": "A curious relic."}
	return _item("artifact", str(a.name), {"id": id, "set": str(a.get("set", "")), "desc": str(a.get("desc", "A run-only relic.")), "extract": false})


func _item(kind: String, name: String, extra: Dictionary) -> Dictionary:
	var it := {
		"uid": next_uid,
		"id": kind + "_" + str(next_uid),
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
	next_uid += 1
	return it


func bag_count() -> int:
	return bag.size()


func bag_full() -> bool:
	return bag.size() >= int(App.bal.bag_cap)


func add_item(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if str(it.kind) == "potion" or str(it.kind) == "food":
		var slot_it: Dictionary = slots.get(str(it.slot), {})
		if not slot_it.is_empty() and str(slot_it.get("food", "")) == str(it.get("food", "")) and str(it.kind) == "food":
			var nxt := int(slot_it.stack) + int(it.stack)
			if not App.in_dungeon:
				nxt = mini(nxt, int(App.bal.food_bring_max))
			slot_it.stack = nxt
			slots[str(it.slot)] = slot_it
			return true
		if not slot_it.is_empty() and str(it.kind) == "potion" and str(slot_it.kind) == "potion":
			slot_it.stack = int(slot_it.stack) + int(it.stack)
			slots["potion"] = slot_it
			return true
	return add_to_bag(it)


func _bag_stack_index(it: Dictionary) -> int:
	var k := str(it.get("kind", ""))
	if k != "potion" and k != "food":
		return -1
	for i in bag.size():
		var b: Dictionary = bag[i]
		if str(b.get("kind", "")) != k:
			continue
		if k == "food" and str(b.get("food", "")) != str(it.get("food", "")):
			continue
		return i
	return -1


func bag_can_accept(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if _bag_stack_index(it) >= 0:
		return true
	return not bag_full()


func add_to_bag(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var idx := _bag_stack_index(it)
	if idx >= 0:
		var b: Dictionary = bag[idx]
		var nxt := int(b.get("stack", 1)) + int(it.get("stack", 1))
		if str(it.kind) == "food" and not App.in_dungeon:
			nxt = mini(nxt, int(App.bal.food_bring_max))
		b.stack = nxt
		bag[idx] = b
		return true
	if bag_full():
		App.toast("Bag full.")
		return false
	bag.append(it)
	if str(it.kind) == "artifact":
		_sync_artifacts()
		_refresh_player_hp()
	return true


func remove_uid(uid: int) -> Dictionary:
	for i in bag.size():
		if int(bag[i].uid) == uid:
			var it: Dictionary = bag[i]
			bag.remove_at(i)
			_sync_artifacts()
			if str(it.kind) == "artifact":
				_refresh_player_hp()
			return it
	return {}


func equip_uid(uid: int) -> String:
	var it := remove_uid(uid)
	if it.is_empty():
		return "Gone."
	var slot := str(it.get("slot", ""))
	if SLOTS.find(slot) < 0:
		add_to_bag(it)
		return "Can't equip that."
	if slot == "tool":
		var t := str(it.get("tool", ""))
		if t != "" and t != tool_type:
			add_to_bag(it)
			return "Tool locked to %s this run." % tool_type
	var cur: Dictionary = slots.get(slot, {})
	if not cur.is_empty():
		if not bag_can_accept(cur):
			add_to_bag(it)
			return "Bag full."
		slots[slot] = {}
		if not add_to_bag(cur):
			slots[slot] = cur
			add_to_bag(it)
			return "Bag full."
	slots[slot] = it
	if slot == "food":
		_clamp_food_slot()
	if slot == "weapon":
		App.weapon = str(it.get("weapon", "great_axe"))
		var p := _player()
		if p and p.has_method("set_weapon"):
			p.set_weapon(App.weapon)
	_sync_artifacts()
	_refresh_player_hp()
	return "Equipped " + str(it.name)


func drop_uid(uid: int) -> String:
	var it := remove_uid(uid)
	if it.is_empty():
		return "Gone."
	App.spawn_floor_item(it)
	App.toast("Dropped " + str(it.name))
	return "Dropped."


func unequip_slot(slot: String) -> String:
	if SLOTS.find(slot) < 0:
		return "No slot."
	var it: Dictionary = slots.get(slot, {})
	if it.is_empty():
		return "Empty."
	if not bag_can_accept(it):
		App.toast("Bag full.")
		return "Bag full."
	slots[slot] = {}
	if not add_to_bag(it):
		slots[slot] = it
		return "Bag full."
	if slot == "weapon":
		var p := _player()
		if p and p.has_method("set_weapon") and App.weapon != "":
			p.set_weapon(App.weapon)
	_sync_artifacts()
	_refresh_player_hp()
	return "Unequipped " + str(it.name)


func drop_slot(slot: String) -> String:
	if SLOTS.find(slot) < 0:
		return "No slot."
	var it: Dictionary = slots.get(slot, {})
	if it.is_empty():
		return "Empty."
	_fill_slot_after_remove(slot)
	_refresh_player_hp()
	App.spawn_floor_item(it)
	App.toast("Dropped " + str(it.name))
	return "Dropped."


func _fill_slot_after_remove(slot: String) -> void:
	if slot == "weapon":
		slots["weapon"] = make_weapon(pick_weapon, "white")
		App.weapon = str(slots.weapon.get("weapon", pick_weapon))
		var p := _player()
		if p and p.has_method("set_weapon"):
			p.set_weapon(App.weapon)
	elif slot == "tool":
		slots["tool"] = make_tool(tool_type)
	else:
		slots[slot] = {}


func take_slot(slot: String) -> Dictionary:
	if SLOTS.find(slot) < 0:
		return {}
	var it: Dictionary = slots.get(slot, {})
	if it.is_empty():
		return {}
	_fill_slot_after_remove(slot)
	_refresh_player_hp()
	return it


func drop_stash(uid: int) -> String:
	for i in bank_items.size():
		if int(bank_items[i].uid) == uid:
			var it: Dictionary = bank_items[i]
			bank_items.remove_at(i)
			App.toast("Discarded " + str(it.name))
			return "Discarded."
	return "Gone."


func give_or_drop(it: Dictionary, pos: Vector3) -> bool:
	if it.is_empty():
		return false
	if add_item(it):
		return true
	App.spawn_floor_item(it, pos)
	return false


func use_from_bag(uid: int) -> String:
	var it: Dictionary = {}
	for b in bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		return "Gone."
	if str(it.kind) == "potion":
		return _drink(it, false)
	if str(it.kind) == "food":
		return _eat(it, false)
	return equip_uid(uid)


func use_potion() -> String:
	var it: Dictionary = slots.get("potion", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast("No potion equipped.")
		return "No potion equipped."
	return _drink(it, true)


func use_food() -> String:
	var it: Dictionary = slots.get("food", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast("No food equipped.")
		return "No food equipped."
	return _eat(it, true)


func _drink(it: Dictionary, from_slot: bool) -> String:
	if potion_cd > 0.0:
		App.toast("Potion cooling down.")
		return "Not ready."
	var p := _player()
	if p == null or not p.has_method("heal"):
		return "Not now."
	p.heal(App.bal.potion_heal if App.bal.potion_heal > 1.0 else App.bal.player_max_hp * App.bal.potion_heal)
	potion_cd = App.bal.potion_cooldown
	App.sfx("potion")
	App.toast("Potion — instant.")
	_consume(it, from_slot)
	return "Potion."


func _eat(it: Dictionary, from_slot: bool) -> String:
	var fid := str(it.get("food", "ration"))
	if food_t > 0.0 and fid == food_id:
		App.toast("That food is already working.")
		return "Already eating that."
	if food_t > 0.0 and fid != food_id:
		clear_food()
	food_id = fid
	food_t = App.bal.food_hot_y
	food_left = App.bal.food_hot_x
	App.sfx("food")
	App.toast("Food — healing over time.")
	_consume(it, from_slot)
	return "Food."


func _consume(it: Dictionary, from_slot: bool) -> void:
	it.stack = int(it.stack) - 1
	if from_slot:
		if int(it.stack) <= 0:
			slots[str(it.slot)] = {}
		else:
			slots[str(it.slot)] = it
	else:
		if int(it.stack) <= 0:
			remove_uid(int(it.uid))
		else:
			for i in bag.size():
				if int(bag[i].uid) == int(it.uid):
					bag[i] = it
					break


func tick_food(delta: float) -> void:
	potion_cd = maxf(0.0, potion_cd - delta)
	if food_t <= 0.0:
		return
	var p := _player()
	var step: float = App.bal.food_hot_x * delta / maxf(0.1, App.bal.food_hot_y)
	step = minf(step, food_left)
	food_left -= step
	food_t = maxf(0.0, food_t - delta)
	if p and p.has_method("heal"):
		p.heal(step)
	if food_t <= 0.0 or food_left <= 0.0:
		clear_food()


func clear_food() -> void:
	food_id = ""
	food_t = 0.0
	food_left = 0.0


func skill_xp(id: String) -> float:
	return float(skills_run.get(id, 0.0)) + float(skills_perm.get(id, 0.0))


func skill_lv(id: String) -> int:
	return level_from_xp(skill_xp(id))


## Cumulative XP required to *be* `level`. Level 1 is 0.
## Totals grow so T(L + period) approaches 2 × T(L). The 1→2 step stays `xp_level`.
func xp_period() -> float:
	return maxf(1.0, App.bal.xp_double_every)


func xp_unit() -> float:
	return maxf(1.0, App.bal.xp_level)


func xp_to_reach(level: int) -> float:
	var lv := maxi(1, level)
	if lv <= 1:
		return 0.0
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	return unit * (pow(r, float(lv - 1)) - 1.0) / (r - 1.0)


func level_from_xp(total: float) -> int:
	var t := maxf(0.0, total)
	var period := xp_period()
	var unit := xp_unit()
	var r := pow(2.0, 1.0 / period)
	var n := 1.0 + log(1.0 + t * (r - 1.0) / unit) / log(r)
	return maxi(1, int(n))


func xp_to_next(total: float) -> float:
	var lv := level_from_xp(total)
	return maxf(0.0, xp_to_reach(lv + 1) - maxf(0.0, total))


func xp_ratio(total: float) -> float:
	var lv := level_from_xp(total)
	var a := xp_to_reach(lv)
	var b := xp_to_reach(lv + 1)
	var span := b - a
	if span <= 0.0001:
		return 1.0
	return clampf((maxf(0.0, total) - a) / span, 0.0, 1.0)


func add_run_xp(id: String, amt: float) -> void:
	if App.adrenaline:
		amt *= App.adrenaline_xp
	var before := skill_lv(id)
	skills_run[id] = float(skills_run.get(id, 0.0)) + amt
	if skill_lv(id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, skill_lv(id)])
		_refresh_player_hp()


func skill_dmg_mult(is_special := false) -> float:
	var wpn := "axe"
	var sty := "str"
	if App.weapon == "staff":
		wpn = "staff"
		sty = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		wpn = "bow"
		sty = "rng"
	var m := 1.0
	m += float(maxi(0, skill_lv(wpn) - 1)) * App.bal.skill_dmg_weapon
	m += float(maxi(0, skill_lv(sty) - 1)) * App.bal.skill_dmg_style
	if is_special:
		m += float(maxi(0, skill_lv(wpn) - 1)) * App.bal.skill_special_bonus
	return m


func skill_def() -> float:
	return float(maxi(0, skill_lv("def") - 1)) * App.bal.skill_def_per_lv


func skill_hp() -> float:
	return float(maxi(0, skill_lv("hp") - 1)) * App.bal.skill_hp_per_lv


func tool_quality() -> float:
	var it: Dictionary = slots.get("tool", {})
	if it.is_empty():
		return 1.0
	var q := 1.0
	var r := str(it.get("rarity", "white"))
	if r == "green":
		q = 2.0
	elif r == "blue":
		q = 3.0
	if bool(it.get("hold", false)):
		q += 1.0
	return q


func skill_grant_hit(is_special := false) -> void:
	if App.weapon == "staff":
		add_run_xp("staff", App.bal.xp_hit_weapon)
		add_run_xp("mag" if is_special else "str", App.bal.xp_hit_style)
		App.last_style = "mag" if is_special else "str"
	elif App.weapon == "longbow":
		add_run_xp("bow", App.bal.xp_hit_weapon)
		add_run_xp("rng", App.bal.xp_hit_style)
		App.last_style = "rng"
	else:
		add_run_xp("axe", App.bal.xp_hit_weapon)
		add_run_xp("str", App.bal.xp_hit_style)
		App.last_style = "str"


func keep_fragments() -> void:
	var keep: float = App.bal.xp_keep
	for id in SKILLS:
		skills_perm[id] = float(skills_perm.get(id, 0.0)) + float(skills_run.get(id, 0.0)) * keep
		skills_run[id] = 0.0


func _survive_pair() -> float:
	return float(skill_lv("def") + skill_lv("hp"))


func _combat_score(wpn: String, sty: String) -> float:
	return (float(skill_lv(wpn) + skill_lv(sty)) + _survive_pair()) / 4.0


func _combat_iv(wpn: String, sty: String) -> int:
	return maxi(1, int(round(_combat_score(wpn, sty))))


func melee_lv_f() -> float:
	return _combat_score("axe", "str")


func magic_lv_f() -> float:
	return _combat_score("staff", "mag")


func ranged_lv_f() -> float:
	return _combat_score("bow", "rng")


func combat_lv_f() -> float:
	return maxf(melee_lv_f(), maxf(magic_lv_f(), ranged_lv_f()))


func style_lv_f() -> float:
	if App.weapon == "staff":
		return magic_lv_f()
	if App.weapon == "longbow":
		return ranged_lv_f()
	return melee_lv_f()


func melee_lv() -> int:
	return _combat_iv("axe", "str")


func magic_lv() -> int:
	return _combat_iv("staff", "mag")


func ranged_lv() -> int:
	return _combat_iv("bow", "rng")


func combat_lv() -> int:
	return maxi(1, int(round(combat_lv_f())))


func style_lv() -> int:
	return maxi(1, int(round(style_lv_f())))


func gear_dmg() -> float:
	var n := 0.0
	for s in SLOTS:
		var it: Dictionary = slots.get(s, {})
		if not it.is_empty():
			n += float(it.get("dmg", 0))
	n += set_stats().dmg
	return n


func gear_def() -> float:
	var n := 0.0
	for s in SLOTS:
		var it: Dictionary = slots.get(s, {})
		if not it.is_empty():
			n += float(it.get("def", 0))
	n += set_stats().def
	return n


func gear_hp() -> float:
	var n := 0.0
	for s in SLOTS:
		var it: Dictionary = slots.get(s, {})
		if not it.is_empty():
			n += float(it.get("hp", 0))
	n += set_stats().hp
	return n


func set_counts() -> Dictionary:
	var c := {}
	for s in SETS:
		c[s] = 0
	for it in bag:
		var sid := str(it.get("set", ""))
		if c.has(sid):
			c[sid] = int(c[sid]) + 1
	for s in SLOTS:
		var it: Dictionary = slots.get(s, {})
		var sid := str(it.get("set", ""))
		if c.has(sid):
			c[sid] = int(c[sid]) + 1
	return c


func set_stats() -> Dictionary:
	var c := set_counts()
	var dmg := 0.0
	var def := 0.0
	var hp := 0.0
	var crit := 0.0
	var gather := 0.0
	var spd := 0.0
	if int(c.cinder) >= 1:
		dmg += App.bal.set_cinder_1 * int(c.cinder)
	if int(c.cinder) >= 2:
		dmg += App.bal.set_cinder_2
	if int(c.tide) >= 1:
		hp += App.bal.set_tide_1 * int(c.tide)
	if int(c.tide) >= 2:
		hp += App.bal.set_tide_2
	if int(c.root) >= 1:
		gather += App.bal.set_root_1 * int(c.root)
	if int(c.root) >= 2:
		gather += App.bal.set_root_2
	if int(c.root) >= 3:
		gather += App.bal.set_root_3
	if int(c.ash) >= 1:
		def += App.bal.set_ash_1 * int(c.ash)
	if int(c.ash) >= 2:
		def += App.bal.set_ash_2
	if int(c.ash) >= 3:
		def += App.bal.set_ash_3
	if int(c.spark) >= 1:
		crit += App.bal.set_spark_1 * int(c.spark)
	if int(c.spark) >= 2:
		crit += App.bal.set_spark_2
	if int(c.bone) >= 1:
		hp += App.bal.set_bone_1 * int(c.bone)
	if int(c.bone) >= 2:
		hp += App.bal.set_bone_2
	if int(c.bone) >= 3:
		hp += App.bal.set_bone_3
	if int(c.veil) >= 1:
		spd += App.bal.set_veil_1 * int(c.veil)
	if int(c.veil) >= 2:
		spd += App.bal.set_veil_2
	if int(c.veil) >= 3:
		spd += App.bal.set_veil_3
	if int(c.veil) >= 4:
		spd += App.bal.set_veil_4
	if int(c.iron) >= 1:
		def += App.bal.set_iron_1 * int(c.iron)
	if int(c.iron) >= 2:
		def += App.bal.set_iron_2
	if int(c.iron) >= 3:
		def += App.bal.set_iron_3
	if int(c.iron) >= 4:
		def += App.bal.set_iron_4
	if int(c.iron) >= 5:
		def += App.bal.set_iron_5
	return {"dmg": dmg, "def": def, "hp": hp, "crit": crit, "gather": gather, "spd": spd}


func set_bonus_text(set_id: String) -> String:
	var n: int = int(set_counts().get(set_id, 0))
	var need := CatalogS.set_size(set_id)
	var lines := "Set %s  %d/%d" % [set_id.capitalize(), n, need]
	if n >= 2:
		lines += "\nActive: " + CatalogS.set_bonus_line(set_id, n)
	else:
		lines += "\nBonus from 2 pieces."
	return lines


func _sync_artifacts() -> void:
	App.run_artifacts.clear()
	for it in bag:
		if str(it.kind) == "artifact":
			App.run_artifacts.append(str(it.id))


func extractable(role := "") -> Array:
	var out: Array = []
	var gather := role == "" or role == "gather" or role == "patty"
	var misc := role == "" or role == "misc" or role == "patty"
	if gather:
		if App.ore > 0:
			out.append({"kind": "ore", "name": "Ore", "n": App.ore})
		if App.wood > 0:
			out.append({"kind": "wood", "name": "Wood", "n": App.wood})
		if root > 0:
			out.append({"kind": "root", "name": "Root", "n": root})
	if misc:
		if App.gold > 0:
			out.append({"kind": "gold", "name": "Gold", "n": App.gold})
		for it in bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and str(it.kind) != "tool" and not bool(it.get("hold", false)):
				out.append(it)
	return out


func extract_all(role: String) -> String:
	var g := 0
	var o := 0
	var w := 0
	var r := 0
	var items := 0
	if role == "gather" or role == "patty":
		o = App.ore
		w = App.wood
		r = root
		App.bank_ore += App.ore
		App.bank_wood += App.wood
		App.bank_root += root
		_quest_extract_ore(App.ore)
		App.ore = 0
		App.wood = 0
		root = 0
		mailed_ore += o
		mailed_wood += w
		mailed_root += r
	if role == "misc" or role == "patty":
		g = App.gold
		App.bank_gold += App.gold
		App.gold = 0
		mailed_gold += g
		var keep: Array = []
		for it in bag:
			if it.get("extract", true) and str(it.kind) != "artifact" and str(it.kind) != "tool" and not bool(it.get("hold", false)):
				bank_items.append(it)
				mailed_names.append(str(it.name))
				items += 1
			else:
				keep.append(it)
		bag = keep
	App.extracted = g + o + w + r + items > 0
	if App.extracted:
		App.toast("Sent to the surface.")
		if App.tel:
			App.tel.note_extract(g, o, w)
			App.tel.forge_n = forge_count
	return "Banked %dg, %d ore, %d wood, %d root, %d items." % [g, o, w, r, items]


func extract_one(it: Dictionary, role: String) -> String:
	var k := str(it.get("kind", ""))
	if k == "gold" and (role == "misc" or role == "patty"):
		App.bank_gold += App.gold
		var n := App.gold
		App.gold = 0
		App.extracted = true
		mailed_gold += n
		return "Sent %dg." % n
	if k == "ore" and (role == "gather" or role == "patty"):
		_quest_extract_ore(App.ore)
		App.bank_ore += App.ore
		var n := App.ore
		App.ore = 0
		App.extracted = true
		mailed_ore += n
		return "Sent %d ore." % n
	if k == "wood" and (role == "gather" or role == "patty"):
		App.bank_wood += App.wood
		var n := App.wood
		App.wood = 0
		App.extracted = true
		mailed_wood += n
		return "Sent %d wood." % n
	if k == "root" and (role == "gather" or role == "patty"):
		var n := root
		App.bank_root += root
		root = 0
		App.extracted = true
		mailed_root += n
		return "Sent %d root." % n
	if role == "gather":
		return "This clerk takes ore, wood, and root."
	if it.has("from_slot"):
		return "Unequip that first."
	if it.has("uid"):
		var got := remove_uid(int(it.uid))
		if got.is_empty():
			return "Gone."
		if str(got.kind) == "artifact" or bool(got.get("hold", false)):
			if str(got.kind) == "artifact":
				add_to_bag(got)
				return "Artifacts cannot be mailed."
			add_to_bag(got)
			return "Forged holds stay with you."
		bank_items.append(got)
		App.extracted = true
		mailed_names.append(str(got.name))
		return "Sent " + str(got.name)
	return "Nothing."


func forge_cost(first: bool) -> Dictionary:
	var sm := skill_lv("smith")
	var g := int(App.bal.forge_gold) - sm * 2
	var o := int(App.bal.forge_ore) - sm
	var r := int(App.bal.forge_root)
	if not first:
		g = maxi(4, int(g * 0.55))
		o = maxi(1, int(o * 0.55))
		r = maxi(0, int(r * 0.4))
	return {"gold": maxi(4, g), "ore": maxi(1, o), "root": maxi(0, r)}


func forge_duration() -> float:
	var sm := skill_lv("smith")
	return maxf(0.2, App.bal.forge_time / (1.0 + float(maxi(0, sm - 1)) * 0.12))


func can_pay(c: Dictionary) -> bool:
	return App.bank_gold + App.gold >= int(c.gold) and App.bank_ore + App.ore >= int(c.ore) and App.bank_root + root >= int(c.root)


func pay(c: Dictionary) -> void:
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
	use = mini(root, rpay)
	root -= use
	rpay -= use
	App.bank_root = maxi(0, App.bank_root - rpay)


func forge_item(it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if SLOTS.find(slot) < 0 or slot == "potion" or slot == "food":
		return "The anvil won't take that."
	var h: Array = holds[slot]
	var first := h.size() < 3
	var cost := forge_cost(first and not bool(it.get("hold", false)))
	if not can_pay(cost):
		App.toast("Not enough gold / ore / root.")
		return "Need %dg, %d ore, %d root." % [cost.gold, cost.ore, cost.root]
	pay(cost)
	if bool(it.get("hold", false)):
		for i in h.size():
			if int(h[i].uid) == int(it.uid):
				var up: Dictionary = (h[i] as Dictionary).duplicate(true)
				up.dmg = int(up.dmg) + 1 + int(skill_lv("smith") / 4)
				up.def = int(up.def) + 1
				if str(up.rarity) == "white":
					up.rarity = "green"
				h[i] = up
				holds[slot] = h
				forge_count += 1
				add_perm_xp("smith", App.bal.xp_smith)
				App.sfx("slam")
				App.toast("Hold re-forged.")
				App.save_now()
				return "Re-forged hold (%d/3)." % h.size()
	var copy := it.duplicate(true)
	copy.hold = true
	copy.extract = false
	copy.rarity = "green" if copy.rarity == "white" else copy.rarity
	copy.dmg = int(copy.dmg) + 1 + int(skill_lv("smith") / 4)
	copy.def = int(copy.def) + 1
	if not str(copy.name).begins_with("Forged "):
		copy.name = "Forged " + str(copy.name)
	if h.size() >= 3:
		h.remove_at(0)
	h.append(copy)
	holds[slot] = h
	forge_count += 1
	_consume_forge_source(it)
	add_perm_xp("smith", App.bal.xp_smith)
	App.sfx("slam")
	App.toast("Hold forged.")
	App.save_now()
	return "Forged into a hold (%d/3)." % h.size()


func add_perm_xp(id: String, amt: float) -> void:
	var before := skill_lv(id)
	skills_perm[id] = float(skills_perm.get(id, 0.0)) + amt
	if skill_lv(id) > before:
		App.sfx("level")
		App.toast("Level up — %s %d" % [id, skill_lv(id)])


func _consume_forge_source(it: Dictionary) -> void:
	if it.has("uid"):
		remove_uid(int(it.uid))
		for i in bank_items.size():
			if int(bank_items[i].uid) == int(it.uid):
				bank_items.remove_at(i)
				break


func roll_quests(keep_active: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var types: PackedStringArray = ["slime", "goblin", "bat", "spider", "archer", "orc", "wolf"]
	var kt := types[rng.randi() % types.size()]
	var nt := types[rng.randi() % types.size()]
	var ff := maxi(1, rng.randi_range(1, maxi(1, deepest)))
	var pool: Array = [
		{"kind": "kill", "title": "Cull the %s" % kt, "type": kt, "need": int(App.bal.quest_kill_need), "have": 0, "reward": "xp"},
		{"kind": "ore", "title": "Mail %d ore" % int(App.bal.quest_ore_need), "need": int(App.bal.quest_ore_need), "have": 0, "reward": "gold"},
		{"kind": "fetch", "title": "Retrieve a guild cache from floor %d" % ff, "floor": ff, "have": 0, "need": 1, "reward": "gear"},
		{"kind": "named", "title": "Vanquish a named foe", "type": nt, "nname": "", "need": 1, "have": 0, "reward": "xp"},
	]
	quests_offered = []
	var used := {}
	while quests_offered.size() < 3 and pool.size() > 0:
		var i := rng.randi() % pool.size()
		var q: Dictionary = pool[i]
		pool.remove_at(i)
		if used.has(q.kind):
			continue
		used[q.kind] = true
		if str(q.kind) == "named":
			q.nname = "Gra" + ["tok", "nash", "rath"][rng.randi() % 3]
			q.title = "Vanquish %s the %s" % [q.nname, q.type]
		quests_offered.append(q)
	if keep_active and not quest_active.is_empty() and int(quest_active.get("have", 0)) < int(quest_active.get("need", 1)):
		pass
	elif not keep_active:
		quest_active = {}
		App.quest_named_type = ""
		App.quest_named_name = ""


func accept_quest(i: int) -> String:
	if i < 0 or i >= quests_offered.size():
		return "None."
	if not quest_active.is_empty() and int(quest_active.get("have", 0)) < int(quest_active.get("need", 1)):
		return "Finish or abandon the current task first."
	quest_active = quests_offered[i].duplicate(true)
	if str(quest_active.kind) == "named":
		if str(quest_active.get("nname", "")) == "":
			quest_active.nname = "Gra" + ["tok", "nash", "rath"][randi() % 3]
			quest_active.title = "Vanquish %s the %s" % [quest_active.nname, quest_active.type]
		App.quest_named_type = str(quest_active.type)
		App.quest_named_name = str(quest_active.nname)
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""
	App.toast("Quest: " + str(quest_active.title))
	return "Accepted."


func abandon_quest() -> String:
	if quest_active.is_empty():
		return "No task."
	quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""
	App.toast("Task abandoned.")
	return "Abandoned."


func note_kill(type_id: String, named: String) -> void:
	if quest_active.is_empty():
		return
	if str(quest_active.kind) == "kill" and type_id == str(quest_active.get("type", "")):
		quest_active.have = int(quest_active.have) + 1
	if str(quest_active.kind) == "named" and named != "" and named == str(quest_active.get("nname", "")):
		quest_active.have = int(quest_active.need)
	_try_complete()


func note_fetch() -> void:
	if str(quest_active.get("kind", "")) == "fetch":
		quest_active.have = 1
		_try_complete()


func _quest_extract_ore(n: int) -> void:
	if str(quest_active.get("kind", "")) == "ore":
		quest_active.have = int(quest_active.get("have", 0)) + n
		_try_complete()


func _try_complete() -> void:
	if quest_active.is_empty():
		return
	if int(quest_active.get("have", 0)) < int(quest_active.get("need", 1)):
		return
	var rw := str(quest_active.get("reward", "gold"))
	if rw == "xp":
		var sa := SKILLS[randi() % SKILLS.size()]
		var sb := SKILLS[randi() % SKILLS.size()]
		skills_perm[sa] = float(skills_perm.get(sa, 0.0)) + App.bal.quest_xp_a
		skills_perm[sb] = float(skills_perm.get(sb, 0.0)) + App.bal.quest_xp_b
		App.toast("Quest complete — %s / %s XP." % [sa, sb])
		_refresh_player_hp()
	elif rw == "gear":
		bank_items.append(_unowned_gear())
		App.toast("Quest complete — gear mailed to stash.")
	else:
		App.bank_gold += int(App.bal.quest_gold)
		App.toast("Quest complete — %dg banked." % int(App.bal.quest_gold))
	quest_active = {}
	App.quest_named_type = ""
	App.quest_named_name = ""


func _unowned_gear() -> Dictionary:
	for s in ["head", "body", "legs"]:
		if (holds[s] as Array).is_empty():
			return make_armor(s, "green")
	return make_weapon(pick_weapon, "green")


func _refresh_player_hp() -> void:
	var p := _player()
	if p == null:
		return
	var maxh: float = App.bal.player_max_hp + gear_hp() + skill_hp()
	var old := float(p.get("max_hp"))
	p.set("max_hp", maxh)
	var cur := float(p.get("hp"))
	if maxh > old:
		p.set("hp", cur + (maxh - old))
	else:
		p.set("hp", minf(cur, maxh))


func _player() -> Node:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	return (tree as SceneTree).get_first_node_in_group("player")


func to_meta() -> Dictionary:
	var h := {}
	for s in SLOTS:
		h[s] = holds[s]
	var sl := {}
	for s in SLOTS:
		sl[s] = slots[s]
	return {
		"holds": h,
		"slots": sl,
		"skills_perm": skills_perm.duplicate(),
		"deepest": deepest,
		"start_floor": start_floor,
		"tool_type": tool_type,
		"pick_weapon": pick_weapon,
		"root": root,
		"next_uid": next_uid,
		"bank_items": bank_items.duplicate(true),
		"quest_active": quest_active.duplicate(true),
		"quests_offered": quests_offered.duplicate(true),
		"forge_count": forge_count,
		"hold_pick": hold_pick.duplicate(),
	}


func from_meta(d: Dictionary) -> void:
	reset_meta()
	var h: Variant = d.get("holds", {})
	if h is Dictionary:
		for s in SLOTS:
			if h.has(s) and h[s] is Array:
				holds[s] = (h[s] as Array).duplicate(true)
	var sp: Variant = d.get("skills_perm", {})
	if sp is Dictionary:
		for id in SKILLS:
			skills_perm[id] = float(sp.get(id, 0.0))
	deepest = maxi(1, int(d.get("deepest", 1)))
	start_floor = clampi(int(d.get("start_floor", 1)), 1, deepest)
	tool_type = str(d.get("tool_type", "pickaxe"))
	pick_weapon = str(d.get("pick_weapon", "great_axe"))
	root = int(d.get("root", 0))
	next_uid = maxi(1, int(d.get("next_uid", 1)))
	var sl: Variant = d.get("slots", {})
	if sl is Dictionary:
		for s in SLOTS:
			if sl.has(s) and sl[s] is Dictionary:
				slots[s] = (sl[s] as Dictionary).duplicate(true)
	var bi: Variant = d.get("bank_items", [])
	if bi is Array:
		bank_items = bi.duplicate(true)
	var qa: Variant = d.get("quest_active", {})
	if qa is Dictionary:
		quest_active = qa.duplicate(true)
	var qo: Variant = d.get("quests_offered", [])
	if qo is Array:
		quests_offered = (qo as Array).duplicate(true)
	forge_count = int(d.get("forge_count", 0))
	var hpicks: Variant = d.get("hold_pick", {})
	if hpicks is Dictionary:
		hold_pick = (hpicks as Dictionary).duplicate(true)
	if str(quest_active.get("kind", "")) == "named":
		App.quest_named_type = str(quest_active.get("type", ""))
		App.quest_named_name = str(quest_active.get("nname", ""))
	else:
		App.quest_named_type = ""
		App.quest_named_name = ""


func _withdraw_bank_consumables() -> void:
	var keep: Array = []
	for it in bank_items:
		var k := str(it.get("kind", ""))
		if k == "potion" or k == "food":
			var slot := "potion" if k == "potion" else "food"
			var cur: Dictionary = slots.get(slot, {})
			if cur.is_empty():
				slots[slot] = it
			elif k == "potion" or str(cur.get("food", "")) == str(it.get("food", "")):
				cur.stack = int(cur.get("stack", 0)) + int(it.get("stack", 1))
				slots[slot] = cur
			else:
				keep.append(it)
		else:
			keep.append(it)
	bank_items = keep


func restock() -> String:
	_withdraw_bank_consumables()
	var msg := ""
	if App.bank_gold < int(App.bal.restock_gold):
		App.bank_gold = int(App.bal.restock_gold)
		msg += "A few coins. "
	var need_p := int(App.bal.restock_potion)
	var pot: Dictionary = slots.get("potion", {})
	if need_p > 0 and (pot.is_empty() or int(pot.get("stack", 0)) < need_p):
		slots["potion"] = make_potion(need_p)
		msg += "Potions. "
	var need_f := int(App.bal.restock_food)
	var fd: Dictionary = slots.get("food", {})
	if need_f > 0 and (fd.is_empty() or int(fd.get("stack", 0)) < need_f):
		slots["food"] = make_food("ration", need_f)
		msg += "Rations. "
	if msg == "":
		return ""
	return "The guild slips you a restock: " + msg
