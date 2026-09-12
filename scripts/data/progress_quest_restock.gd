extends Object

## Guild restock helper for progress.


static func restock(p: Object) -> String:
	var Extract := load("res://scripts/data/progress_extract.gd")
	Extract.withdraw_bank_consumables(p)
	var msg: String = ""
	if App.bank_gold < int(App.bal.restock_gold):
		App.bank_gold = int(App.bal.restock_gold)
		msg += "A few coins. "
	var need_p: int = int(App.bal.restock_potion)
	var pot: Dictionary = p.slots.get("potion", {})
	var charges: int = int(pot.get("charges", pot.get("stack", 0)))
	if need_p > 0 and (pot.is_empty() or charges < need_p):
		p.slots["potion"] = p.make_potion(maxi(2, need_p))
		msg += "Potions. "
	var need_f: int = int(App.bal.restock_food)
	var fd: Dictionary = p.slots.get("food", {})
	if need_f > 0 and (fd.is_empty() or int(fd.get("stack", 0)) < need_f):
		p.slots["food"] = p.make_food("ration", need_f)
		msg += "Rations. "
	if msg == "":
		return ""
	return "The guild slips you a restock: " + msg
