extends Object

const Bag := preload("res://scripts/data/progress_gear_bag.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")

static func use_from_bag(p: Object, uid: int) -> String:
	var it: Dictionary = {}
	for b: Variant in p.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		return "Gone."
	if str(it.kind) == "food":
		return eat(p, it, false)
	return Bag.equip_uid(p, uid)


static func use_potion(p: Object) -> String:
	var it: Dictionary = p.slots.get("potion", {})
	if it.is_empty():
		App.toast("No potion equipped.")
		return "No potion equipped."
	var ch: int = int(it.get("charges", it.get("stack", 0)))
	if ch <= 0:
		App.toast("No charges left this run.")
		return "Empty."
	return drink(p, it, true)


static func use_food(p: Object) -> String:
	var it: Dictionary = p.slots.get("food", {})
	if it.is_empty() or int(it.get("stack", 0)) <= 0:
		App.toast("No food equipped.")
		return "No food equipped."
	return eat(p, it, true)


static func drink(p: Object, it: Dictionary, from_slot: bool) -> String:
	return Rules.drink(p, it, from_slot)


static func eat(p: Object, it: Dictionary, from_slot: bool) -> String:
	var fid: String = str(it.get("food", "ration"))
	if p.food_t > 0.0 and fid == p.food_id:
		App.toast("That food is already working.")
		return "Already eating that."
	if p.food_t > 0.0 and fid != p.food_id:
		p.clear_food()
	p.food_id = fid
	p.food_t = App.bal.food_hot_y
	p.food_left = App.bal.food_hot_x
	App.sfx("food")
	App.toast("Food — healing over time.")
	consume(p, it, from_slot)
	return "Food."


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
	if p.food_t <= 0.0:
		return
	var pl: CharacterBody3D = p._player()
	var step: float = App.bal.food_hot_x * delta / maxf(0.1, App.bal.food_hot_y)
	step = minf(step, p.food_left)
	p.food_left -= step
	p.food_t = maxf(0.0, p.food_t - delta)
	if pl and pl.has_method("heal"):
		pl.heal(step)
	if p.food_t <= 0.0 or p.food_left <= 0.0:
		p.clear_food()


static func dmg(p: Object) -> int:
	return int(stat(p, "dmg"))


static func def(p: Object) -> int:
	return int(stat(p, "def"))


static func hp(p: Object) -> int:
	return int(stat(p, "hp"))


static func stat(p: Object, key: String) -> float:
	var n := 0.0
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		var it: Dictionary = p.slots.get(s, {})
		if it.is_empty():
			continue
		n += float(it.get(key, 0.0))
		if key == "crit_chance":
			n += float(it.get("crit", 0.0))
		var raw: Variant = it.get("affixes", [])
		if raw is Array:
			for row: Variant in raw:
				if row is Dictionary and str(row.get("id", "")) == key:
					n += float(row.get("value", 0.0))
	var sets: Dictionary = set_stats(p)
	if key == "crit_chance":
		n += float(sets.get("crit", 0.0))
	elif key == "move_spd":
		n += float(sets.get("spd", 0.0))
	elif key == "gather_spd" or key == "yield_chance":
		n += float(sets.get("gather", 0.0))
	elif sets.has(key):
		n += float(sets.get(key, 0.0))
	return n


static func tool_quality(p: Object) -> float:
	return load("res://scripts/data/progress_combat.gd").tool_quality(p)


static func set_counts(p: Object) -> Dictionary:
	return load("res://scripts/data/progress_combat.gd").set_counts(p)


static func set_stats(p: Object) -> Dictionary:
	return load("res://scripts/data/progress_combat.gd").set_stats(p)


static func set_bonus_text(p: Object, sid: String) -> String:
	return load("res://scripts/data/progress_combat.gd").set_bonus_text(p, sid)


static func sync_artifacts(p: Object) -> void:
	load("res://scripts/data/progress_combat.gd").sync_artifacts(p)

