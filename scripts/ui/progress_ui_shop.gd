extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Inv := preload("res://scripts/ui/progress_ui_inv.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")


static func rebuild_shop(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Ghost Shop", 32, Color(0.75, 0.9, 1.0)))
	ui.box.add_child(ThemeS.lab("Two artifacts a visit. Snacks %dg. Artifacts are run-only." % int(App.bal.snack_cost), 18, Color(0.82, 0.76, 0.66)))
	ui.box.add_child(ThemeS.lab("Gold %d   Bought %d/%d" % [App.gold, int(ui.shop_spot.get("bought") if ui.shop_spot else 0), int(App.bal.shop_buy_max)], 20, Color(0.9, 0.88, 0.78)))
	ui.box.add_child(ThemeS.lab(Inv.sets_blurb(), 18, Color(0.85, 0.72, 0.45)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn("Snack  (%dg, +HP)" % int(App.bal.snack_cost), func(): ui._confirm(func(): buy_snack(ui), "snack"))
	ui.box.add_child(ui.focus_btn)
	if ui.shop_spot:
		for a in ui.shop_spot.stock:
			var id := str(a.id)
			var nm := str(a.name)
			var desc := str(a.get("desc", ""))
			var set_id := str(a.get("set", ""))
			var extra := ""
			if set_id != "":
				extra = "\n" + App.prog.set_bonus_text(set_id)
			ui.box.add_child(ThemeS.btn("Buy %s  (%dg)\n%s%s" % [nm, int(App.bal.art_cost), desc, extra], func(): ui._confirm(func(): buy_art(ui, id, nm), "buy_" + id)))
		for it in App.prog.bag:
			if str(it.kind) == "artifact" or str(it.kind) == "weapon" or str(it.kind) == "head" or str(it.kind) == "body" or str(it.kind) == "legs":
				var uid := int(it.uid)
				ui.box.add_child(ThemeS.btn("Pawn %s  (%dg)" % [it.name, int(App.bal.pawn_gold)], func(): ui._confirm(func(): pawn(ui, uid), "pawn_%d" % uid)))
		for s in ["weapon", "tool", "head", "body", "legs"]:
			var eq: Dictionary = App.prog.slots.get(s, {})
			if eq.is_empty():
				continue
			if Rules.locked_equip_slot(str(s)):
				continue
			var slot := str(s)
			ui.box.add_child(ThemeS.btn("Pawn equipped %s  (%dg)" % [eq.name, int(App.bal.pawn_gold)], func(): ui._confirm(func(): pawn_slot(ui, slot), "pawn_slot_" + slot)))
	ui.box.add_child(ThemeS.btn("Leave", func(): ui.close_ui()))


static func buy_snack(ui) -> void:
	if App.gold < int(App.bal.snack_cost):
		ui._st("Not enough gold.")
		return
	App.gold -= int(App.bal.snack_cost)
	shop_spend(int(App.bal.snack_cost))
	var p: Node = ui.get_tree().get_first_node_in_group("player")
	if p and p.has_method("heal"):
		p.heal(App.bal.snack_heal)
	ui._st("The snack is strangely warm.")
	App.toast("Snack.")


static func buy_art(ui, id: String, nm: String) -> void:
	if ui.shop_spot == null:
		return
	if int(ui.shop_spot.bought) >= int(App.bal.shop_buy_max):
		ui._st("Two artifacts a visit.")
		return
	if App.gold < int(App.bal.art_cost):
		ui._st("Not enough gold.")
		return
	if App.prog.bag_full():
		ui._st("Bag full.")
		return
	App.gold -= int(App.bal.art_cost)
	ui.shop_spot.bought = int(ui.shop_spot.bought) + 1
	App.prog.add_item(App.prog.make_artifact(id))
	shop_spend(int(App.bal.art_cost))
	var keep: Array = []
	var stripped := false
	for a in ui.shop_spot.stock:
		if not stripped and str(a.get("id", "")) == id:
			stripped = true
			continue
		keep.append(a)
	ui.shop_spot.stock = keep
	ui._st("Purchased " + nm)
	App.toast("Artifact: " + nm)
	ui._rebuild_shop()
	ui._show()


static func shop_spend(n: int) -> void:
	App.shop_buys += 1
	App.shop_spent += n
	if App.tel:
		App.tel.shop_buys += 1
		App.tel.shop_spent += n


static func pawn(ui, uid: int) -> void:
	var it := App.prog.remove_uid(uid)
	if it.is_empty():
		ui._st("Gone.")
		return
	App.gain_gold(int(App.bal.pawn_gold))
	ui._st("The ghost takes it for a pittance.")
	ui._rebuild_shop()
	ui._show()


static func pawn_slot(ui, slot: String) -> void:
	if Rules.locked_equip_slot(slot):
		ui._st("Weapon and tool stay equipped.")
		return
	var it := App.prog.take_slot(slot)
	if it.is_empty():
		ui._st("Gone.")
		return
	App.gain_gold(int(App.bal.pawn_gold))
	ui._st("The ghost takes it for a pittance.")
	ui._rebuild_shop()
	ui._show()


static func rebuild_vendor(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Vendor Stall", 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("Bank %dg  %d ore   ·   potions and rations for the next drop." % [App.bank_gold, App.bank_ore], 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn("Buy potion  (%dg)" % int(App.bal.vendor_potion_cost), func(): vend_potion(ui))
	ui.box.add_child(ui.focus_btn)
	ui.box.add_child(ThemeS.btn("Buy ration  (%dg, food slot)" % int(App.bal.vendor_food_cost), func(): vend_food(ui)))
	ui.box.add_child(ThemeS.btn("Sell 1 ore  (%dg)" % int(App.bal.vendor_ore_gold), func(): vend_sell(ui)))
	ui.box.add_child(ThemeS.btn("Leave", func(): ui.close_ui()))


static func vend_potion(ui) -> void:
	var cost := int(App.bal.vendor_potion_cost)
	if App.bank_gold < cost:
		ui._st("Not enough banked gold.")
		return
	var pot: Dictionary = App.prog.make_potion(2)
	var cur: Dictionary = App.prog.slots.get("potion", {})
	App.bank_gold -= cost
	if cur.is_empty():
		App.prog.slots["potion"] = pot
	elif not App.prog.add_to_bag(pot):
		App.bank_gold += cost
		ui._st("Bag full.")
		return
	ui._st("Potion ready.")
	App.save_now()


static func vend_food(ui) -> void:
	var cost := int(App.bal.vendor_food_cost)
	if App.bank_gold < cost:
		ui._st("Not enough banked gold.")
		return
	var fd: Dictionary = App.prog.slots.get("food", {})
	var cap := int(App.bal.food_bring_max)
	if not fd.is_empty() and int(fd.get("stack", 0)) >= cap:
		ui._st("Food slot is full (%d)." % cap)
		return
	App.bank_gold -= cost
	if fd.is_empty():
		App.prog.slots["food"] = App.prog.make_food("ration", 1)
	else:
		fd.stack = mini(int(fd.get("stack", 0)) + 1, cap)
		App.prog.slots["food"] = fd
	ui._st("Ration packed in the food slot.")
	App.save_now()


static func vend_sell(ui) -> void:
	if App.bank_ore < 1:
		ui._st("No ore in the bank.")
		return
	App.bank_ore -= 1
	App.bank_gold += int(App.bal.vendor_ore_gold)
	ui._st("Sold 1 ore.")
	App.save_now()
