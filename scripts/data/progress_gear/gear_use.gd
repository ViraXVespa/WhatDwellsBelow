extends Object

const Bag := preload("res://scripts/data/progress_gear/gear_bag.gd")
const Norm := preload("res://scripts/data/gear_rules/rules_norm.gd")
const Affix := preload("res://scripts/data/affixes.gd")

static func use_from_bag(p: Object, uid: int) -> String:
	var it: Dictionary = {}
	for b: Variant in p.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		return App.tr("common.gone")
	if str(it.kind) == "food":
		return eat(p, it, false)
	return Bag.equip_uid(p, uid)

static func use_potion(p: Object) -> String:
	var it: Dictionary = p.slots.get("potion", {})
	if it.is_empty():
		App.toast(App.tr("common.no_potion_equipped"))
		return App.tr("common.no_potion_equipped")
	var ch: int = int(it.get("charges", it.get("stack", 0)))
	if ch <= 0:
		App.toast(App.tr("common.no_charges_left_this_run"))
		return App.tr("common.empty")
	return drink(p, it, true)

static func use_food(p: Object) -> String:
	var it: Dictionary = p.slots.get("food", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast(App.tr("common.no_food_equipped"))
		return App.tr("common.no_food_equipped")
	return eat(p, it, true)

static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Norm.drink(p, it, from_slot)

static func eat(p: Object, it: Dictionary, from_slot: bool) -> String:
	var fid: String = str(it.get("food", "ration"))
	if p.food_t > 0.0 and fid == p.food_id:
		App.toast(App.tr("gear_use.that_food_is_already_working"))
		return App.tr("gear_use.already_eating_that")
	if p.food_t > 0.0 and fid != p.food_id:
		p.clear_food()
	p.food_id = fid
	var total: float = float(it.get("heal", 0.0))
	var secs: float = float(it.get("heal_secs", 0.0))
	if total <= 0.0:
		total = App.bal.food_hot_x
	if secs <= 0.0:
		secs = App.bal.food_hot_y
	p.food_t = secs
	p.food_left = total
	p.food_bonus_id = str(it.get("bonus_id", ""))
	p.food_bonus_amt = float(it.get("bonus_amt", 0.0))
	if p.food_bonus_id == Affix.ID_HP:
		p._refresh_player_hp()
	p.add_mana(p.food_mana(fid))
	App.sfx("food")
	App.toast(App.tr("gear_use.food_healing_over_time"))
	consume(p, it, from_slot)
	if from_slot:
		load("res://scripts/data/progress_gear/consumable.gd").sync_slots(p)
	return App.tr("gear_use.food")

static func consume(p: Object, it: Dictionary, from_slot: bool) -> void:
	it.stack = int(it.stack) - 1
	if from_slot:
		if int(it.stack) <= 0:
			p.slots[str(it.slot)] = {}
		else:
			p.slots[str(it.slot)] = it
	else:
		if int(it.stack) <= 0:
			Bag.remove_uid(p, int(it.uid))
		else:
			for i: int in p.bag.size():
				if int(p.bag[i].uid) == int(it.uid):
					p.bag[i] = it
					break

static func tick_food(p: Object, delta: float) -> void:
	p.potion_cd = maxf(0.0, p.potion_cd - delta)
	p.potion_bonus_t = maxf(0.0, p.potion_bonus_t - delta)
	if p.potion_bonus_t <= 0.0 and p.potion_bonus_id != "":
		var was_hp: bool = p.potion_bonus_id == Affix.ID_HP
		p.potion_bonus_id = ""
		p.potion_bonus_amt = 0.0
		if was_hp:
			p._refresh_player_hp()
	if p.potion_hot_t > 0.0:
		var pot_pl: CharacterBody3D = p._player()
		var pot_step: float = p.potion_hot_left * delta / maxf(0.1, p.potion_hot_t)
		pot_step = minf(pot_step, p.potion_hot_left)
		p.potion_hot_left -= pot_step
		p.potion_hot_t = maxf(0.0, p.potion_hot_t - delta)
		if pot_pl and pot_pl.has_method("heal"):
			pot_pl.heal(pot_step)
		if p.potion_hot_t <= 0.0 or p.potion_hot_left <= 0.0:
			p.potion_hot_t = 0.0
			p.potion_hot_left = 0.0
	if p.food_t <= 0.0:
		return
	var pl: CharacterBody3D = p._player()
	var step: float = p.food_left * delta / maxf(0.1, p.food_t)
	step = minf(step, p.food_left)
	p.food_left -= step
	p.food_t = maxf(0.0, p.food_t - delta)
	if pl and pl.has_method("heal"):
		pl.heal(step)
	if p.food_t <= 0.0 or p.food_left <= 0.0:
		p.clear_food()
