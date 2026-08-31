extends Object

const Extract := preload("res://scripts/data/progress_extract.gd")
const Quest := preload("res://scripts/data/progress_quest.gd")


static func extractable(p: Object, role: String = "") -> Array:
	return Extract.extractable(p, role)


static func extract_all(p: Object, role: String) -> String:
	return Extract.extract_all(p, role)


static func extract_one(p: Object, it: Dictionary, role: String) -> String:
	return Extract.extract_one(p, it, role)


static func withdraw_bank_consumables(p: Object) -> void:
	Extract.withdraw_bank_consumables(p)


static func forge_cost(p: Object, first: bool) -> Dictionary:
	var sm: int = p.skill_lv("smith")
	var g: int = int(App.bal.forge_gold) - sm * 2
	var o: int = int(App.bal.forge_ore) - sm
	var r: int = int(App.bal.forge_root)
	if not first:
		g = maxi(4, int(g * 0.55))
		o = maxi(1, int(o * 0.55))
		r = maxi(0, int(r * 0.4))
	return {"gold": maxi(4, g), "ore": maxi(1, o), "root": maxi(0, r)}


static func forge_duration(p: Object) -> float:
	var sm: int = p.skill_lv("smith")
	return maxf(0.2, App.bal.forge_time / (1.0 + float(maxi(0, sm - 1)) * 0.12))


static func can_pay(p: Object, c: Dictionary) -> bool:
	return App.bank_gold + App.gold >= int(c.gold) and App.bank_ore + App.ore >= int(c.ore) and App.bank_root + p.root >= int(c.root)


static func pay(p: Object, c: Dictionary) -> void:
	var g: int = int(c.gold)
	var use: int = mini(App.gold, g)
	App.gold -= use
	g -= use
	App.bank_gold = maxi(0, App.bank_gold - g)
	var o: int = int(c.ore)
	use = mini(App.ore, o)
	App.ore -= use
	o -= use
	App.bank_ore = maxi(0, App.bank_ore - o)
	var rpay: int = int(c.root)
	use = mini(p.root, rpay)
	p.root -= use
	rpay -= use
	App.bank_root = maxi(0, App.bank_root - rpay)


static func forge_item(p: Object, it: Dictionary) -> String:
	var slot: String = str(it.get("slot", ""))
	if p.SLOTS.find(slot) < 0 or slot == "potion" or slot == "food":
		return "The anvil won't take that."
	var h: Array = p.holds[slot]
	var first: bool = h.size() < 3
	var cost: Dictionary = forge_cost(p, first and not bool(it.get("hold", false)))
	if not can_pay(p, cost):
		App.toast("Not enough gold / ore / root.")
		return "Need %dg, %d ore, %d root." % [cost.gold, cost.ore, cost.root]
	pay(p, cost)
	if bool(it.get("hold", false)):
		for i: int in h.size():
			if int(h[i].uid) == int(it.uid):
				var up: Dictionary = (h[i] as Dictionary).duplicate(true)
				up.dmg = int(up.dmg) + 1 + int(p.skill_lv("smith") / 4)
				up.def = int(up.def) + 1
				if str(up.rarity) == "white":
					up.rarity = "green"
				h[i] = up
				p.holds[slot] = h
				p.forge_count += 1
				p.add_perm_xp("smith", App.bal.xp_smith)
				App.sfx("slam")
				App.toast("Hold re-forged.")
				App.save_now()
				return "Re-forged hold (%d/3)." % h.size()
	var copy: Dictionary = it.duplicate(true)
	copy.hold = true
	copy.extract = false
	copy.rarity = "green" if copy.rarity == "white" else copy.rarity
	copy.dmg = int(copy.dmg) + 1 + int(p.skill_lv("smith") / 4)
	copy.def = int(copy.def) + 1
	if not str(copy.name).begins_with("Forged "):
		copy.name = "Forged " + str(copy.name)
	if h.size() >= 3:
		h.remove_at(0)
	h.append(copy)
	p.holds[slot] = h
	p.forge_count += 1
	consume_forge_source(p, it)
	p.add_perm_xp("smith", App.bal.xp_smith)
	App.sfx("slam")
	App.toast("Hold forged.")
	App.save_now()
	return "Forged into a hold (%d/3)." % h.size()


static func consume_forge_source(p: Object, it: Dictionary) -> void:
	if it.has("uid"):
		p.remove_uid(int(it.uid))
		for i: int in p.bank_items.size():
			if int(p.bank_items[i].uid) == int(it.uid):
				p.bank_items.remove_at(i)
				break


static func roll_quests(p: Object, keep_active: bool) -> void:
	Quest.roll_quests(p, keep_active)


static func accept_quest(p: Object, i: int) -> String:
	return Quest.accept_quest(p, i)


static func abandon_quest(p: Object) -> String:
	return Quest.abandon_quest(p)


static func note_kill(p: Object, type_id: String, named: String) -> void:
	Quest.note_kill(p, type_id, named)


static func note_fetch(p: Object) -> void:
	Quest.note_fetch(p)


static func quest_extract_ore(p: Object, n: int) -> void:
	Quest.quest_extract_ore(p, n)


static func try_complete(p: Object) -> void:
	Quest.try_complete(p)


static func unowned_gear(p: Object) -> Dictionary:
	return Quest.unowned_gear(p)


static func to_meta(p: Object) -> Dictionary:
	return Quest.to_meta(p)


static func from_meta(p: Object, d: Dictionary) -> void:
	Quest.from_meta(p, d)


static func restock(p: Object) -> String:
	return Quest.restock(p)
