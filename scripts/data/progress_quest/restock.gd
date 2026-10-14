extends Object

## Guild restock helper for progress.

static func restock(p: Object) -> String:
	var Extract := load("res://scripts/data/progress/extract.gd")
	Extract.withdraw_bank_consumables(p)
	var msg: String = ""
	if App.bank_gold < int(App.bal.restock_gold):
		App.bank_gold = int(App.bal.restock_gold)
		msg += App.tr("restock.a_few_coins") + " "
	var Cons: GDScript = load("res://scripts/data/progress_gear/consumable.gd")
	var need_p: int = int(App.bal.restock_potion)
	var pot: Dictionary = p.slots.get("potion", {})
	var charges: int = int(pot.get("charges", pot.get("stack", 0)))
	if need_p > 0 and not pot.is_empty() and charges < need_p:
		pot["charges"] = mini(need_p, maxi(need_p, int(pot.get("charge_max", need_p))))
		if int(pot.get("charge_max", 0)) < int(pot["charges"]):
			pot["charge_max"] = int(pot["charges"])
		p.slots["potion"] = pot
		Cons.sync_slots(p)
		msg += App.tr("restock.potions") + " "
	var need_f: int = int(App.bal.restock_food)
	var fd: Dictionary = p.slots.get("food", {})
	if need_f > 0 and fd.is_empty():
		if Cons.give_food(p, "ration", need_f):
			msg += App.tr("restock.rations") + " "
	elif need_f > 0 and int(fd.get("stack", 0)) < need_f:
		fd["stack"] = need_f
		p.slots["food"] = fd
		Cons.sync_slots(p)
		msg += App.tr("restock.rations") + " "
	if msg == "":
		return ""
	return App.tr("restock.guild_restock").format({"msg": msg})
