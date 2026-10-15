extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const VendorFrame: GDScript = preload("res://scripts/ui/progress_ui/vendor_frame.gd")
const ShopFrame: GDScript = preload("res://scripts/ui/progress_ui/shop_frame.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const Talk := preload("res://scripts/data/talk_lines.gd")
const Cons := preload("res://scripts/data/progress_gear/consumable.gd")
const Inv := preload("res://scripts/ui/progress_ui/inv.gd")
const Kit := preload("res://scripts/data/gear_rules/rules_kit.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")

static func rebuild_shop(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab(App.tr("common.ghost_shop"), 32, ThemeS.INK))
	ui.box.add_child(ThemeS.lab(App.tr("shop.two_artifacts_a_visit_snacks") % int(App.bal.snack_cost), 18, ThemeS.INK_SOFT))
	ui.box.add_child(ThemeS.lab(App.tr("shop.gold_bought") % [App.gold, int(ui.shop_spot.get("bought") if ui.shop_spot else 0), int(App.bal.shop_buy_max)], 20, ThemeS.INK))
	ui.box.add_child(ThemeS.lab(Inv.sets_blurb(), 18, Color(0.42, 0.26, 0.10)))
	ui.status = ThemeS.lab("", 20, ThemeS.INK)
	ui.box.add_child(ui.status)
	ui.focus_btn = _shelf_row(App.tr("shop.snack_g_hp") % int(App.bal.snack_cost), Icons.tex_snack(), func(): Confirm.open(ui, App.tr("shop.buy_snack"), App.tr("shop.spend_g_for_a_snack") % int(App.bal.snack_cost), func(): buy_snack(ui)))
	ui.box.add_child(ui.focus_btn)
	if ui.shop_spot:
		for st in ui.shop_spot.stock:
			var id := str(st.id)
			var a: Dictionary = CatalogS.by_id(id)
			var nm := str(a.get("name", id))
			var desc := str(a.get("desc", ""))
			var set_id := str(a.get("set", ""))
			var extra := ""
			if set_id != "":
				extra = "\n" + App.prog.set_bonus_text(set_id)
			var art: Dictionary = {"kind": "artifact", "id": id}
			ui.box.add_child(_shelf_row(App.tr("shop.buy_g") % [nm, int(App.bal.art_cost), desc, extra], Icons.tex_for_item(art), func(): Confirm.open(ui, App.tr("shop.buy_artifact"), App.tr("shop.spend_g_for") % [int(App.bal.art_cost), nm], func(): buy_art(ui, id, nm))))
		for it in App.prog.bag:
			if str(it.kind) == "artifact" or str(it.kind) == "weapon" or str(it.kind) == "head" or str(it.kind) == "body" or str(it.kind) == "legs":
				var uid := int(it.uid)
				ui.box.add_child(_shelf_row(App.tr("shop.pawn_g") % [it.name, int(App.bal.pawn_gold)], Icons.tex_for_item(it), func(): Confirm.open(ui, App.tr("shop.pawn_item"), App.tr("shop.pawn_for_g") % [it.name, int(App.bal.pawn_gold)], func(): pawn(ui, uid), Callable(), "danger")))
		for s in Affix.FORGE_SLOTS:
			var eq: Dictionary = App.prog.slots.get(s, {})
			if eq.is_empty():
				continue
			if Kit.locked_equip_slot(str(s)):
				continue
			var slot := str(s)
			ui.box.add_child(_shelf_row(App.tr("shop.pawn_equipped_g") % [eq.name, int(App.bal.pawn_gold)], Icons.tex_for_item(eq), func(): Confirm.open(ui, App.tr("shop.pawn_equipped"), App.tr("shop.pawn_equipped_for_g") % [eq.name, int(App.bal.pawn_gold)], func(): pawn_slot(ui, slot), Callable(), "danger")))
	var leave: Button = ThemeS.btn(App.tr("common.leave"), func(): ui.close_ui())
	ShopFrame.dress(leave)
	ui.box.add_child(leave)

static func buy_snack(ui) -> void:
	if App.gold < int(App.bal.snack_cost):
		ui._st(App.tr("common.not_enough_gold"))
		return
	App.gold -= int(App.bal.snack_cost)
	shop_spend(int(App.bal.snack_cost))
	var p: Node = ui.get_tree().get_first_node_in_group("player")
	if p and p.has_method("heal"):
		p.heal(App.bal.snack_heal)
	ui._st(App.tr("shop.the_snack_is_strangely_warm"))
	App.toast(App.tr("shop.snack"))

static func buy_art(ui, id: String, nm: String) -> void:
	if ui.shop_spot == null:
		return
	if int(ui.shop_spot.bought) >= int(App.bal.shop_buy_max):
		ui._st(App.tr("shop.two_artifacts_a_visit"))
		return
	if App.gold < int(App.bal.art_cost):
		ui._st(App.tr("common.not_enough_gold"))
		return
	if App.prog.bag_full():
		ui._st(App.tr("common.bag_full"))
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
	ui._st(App.tr("shop.purchased_name").format({"name": nm}))
	App.toast(App.tr("shop.artifact_name").format({"name": nm}))
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
		ui._st(App.tr("common.gone"))
		return
	App.gain_gold(int(App.bal.pawn_gold))
	ui._st(App.tr("common.the_ghost_takes_it_for"))
	ui._rebuild_shop()
	ui._show()

static func pawn_slot(ui, slot: String) -> void:
	if Kit.locked_equip_slot(slot):
		ui._st(App.tr("common.weapon_and_tool_stay_equipped"))
		return
	var it := App.prog.take_slot(slot)
	if it.is_empty():
		ui._st(App.tr("common.gone"))
		return
	App.gain_gold(int(App.bal.pawn_gold))
	ui._st(App.tr("common.the_ghost_takes_it_for"))
	ui._rebuild_shop()
	ui._show()

static func rebuild_vendor(ui) -> void:
	ui._clear()
	VendorFrame.prepare(ui)
	if ui.status:
		ui.status.text = Talk.text("vendor")
	if ui.has_meta("vendor_toss"):
		_toss_board(ui)
		return
	var visit: Dictionary = _visit(ui)
	ui.box.add_child(ThemeS.lab(App.tr("shop.potions"), 20, ThemeS.INK))
	var pots: Array = visit.get("potions", [])
	var first: Button = null
	for i: int in pots.size():
		var it: Dictionary = pots[i]
		var idx: int = i
		var btn: Button = _shelf(it, _potion_line(it), func() -> void: _buy_potion(ui, idx))
		if first == null:
			first = btn
		ui.box.add_child(btn)
	ui.box.add_child(ThemeS.lab(App.tr("shop.food"), 20, ThemeS.INK))
	var foods: Array = Cons.food_rows(App.prog)
	for raw: Variant in foods:
		var row: Dictionary = raw as Dictionary
		var fid: String = str(row.get("food", ""))
		var mode: String = str(row.get("mode", "new"))
		var sample: Dictionary = Cons.preview_food(fid)
		var food_id: String = fid
		var food_mode: String = mode
		var food_btn: Button = _shelf(sample, _food_line(sample, food_mode), func() -> void: _buy_food(ui, food_id, food_mode))
		if first == null:
			first = food_btn
		ui.box.add_child(food_btn)
	var sell: Button = ThemeS.btn(App.tr("shop.sell_1_ore_g") % int(App.bal.vendor_ore_gold), func(): vend_sell(ui), true, "primary")
	VendorFrame.dress(sell, true)
	ui.box.add_child(sell)
	var leave: Button = ThemeS.btn(App.tr("common.leave"), func(): _leave(ui))
	VendorFrame.dress(leave, false)
	ui.box.add_child(leave)
	ui.focus_btn = first if first != null else leave

static func _visit(ui) -> Dictionary:
	if ui.has_meta("vendor_visit"):
		return ui.get_meta("vendor_visit")
	var visit: Dictionary = {"potions": Cons.roll_three(App.prog)}
	ui.set_meta("vendor_visit", visit)
	return visit

static func _leave(ui) -> void:
	if ui.has_meta("vendor_visit"):
		ui.remove_meta("vendor_visit")
	if ui.has_meta("vendor_toss"):
		ui.remove_meta("vendor_toss")
	ui.close_ui()

static func open_stocked(ui: Node) -> void:
	var spot: Node = (load("res://scripts/world/interact.gd") as GDScript).new() as Node
	var rows: Array = [
		{"id": "cinder_coil", "set": "cinder"},
		{"id": "tide_pearl", "set": "tide"},
		{"id": "root_knot", "set": "root"},
	]
	spot.set("stock", rows)
	spot.set("bought", 0)
	ui.call("open_shop", spot)

static func _shelf_row(line: String, tex: Texture2D, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = line
	b.custom_minimum_size = Vector2(460, 72)
	b.focus_mode = Control.FOCUS_ALL
	if tex == null:
		push_error("shop row has no icon: " + line)
	else:
		Icons.fit_btn(b, tex)
		b.expand_icon = false
	ShopFrame.dress_shelf(b)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.pressed.connect(on_press)
	return b

static func _shelf(it: Dictionary, line: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = line
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(460, 72)
	b.focus_mode = Control.FOCUS_ALL
	var tex: Texture2D = Icons.tex_for_item(it)
	if tex == null:
		push_error("vendor row has no icon: " + str(it.get("food", it.get("name", ""))))
	else:
		Icons.fit_btn(b, tex)
	b.expand_icon = false
	VendorFrame.dress_shelf(b)
	b.pressed.connect(on_press)
	return b

static func _potion_line(it: Dictionary) -> String:
	var cost: int = int(App.bal.vendor_potion_cost)
	var secs: float = float(it.get("heal_secs", 0.0))
	var speed: String = App.tr("shop.potion_over_s") % int(ceil(secs)) if secs > 0.0 else App.tr("shop.potion_instant")
	return App.tr("shop.potion_row") % [str(it.get("name", "")), int(it.get("charge_max", 0)), int(it.get("heal", 0)), speed, int(it.get("cooldown", 0)), cost]

static func _food_line(it: Dictionary, mode: String) -> String:
	var cost: int = int(App.bal.vendor_food_cost)
	var kind: String = App.tr("shop.food_new") if mode == "new" else App.tr("shop.food_stack")
	return App.tr("shop.food_row") % [str(it.get("name", "")), kind, int(it.get("heal", 0)), int(it.get("heal_secs", 0)), cost]

static func _buy_potion(ui, idx: int) -> void:
	var cost: int = int(App.bal.vendor_potion_cost)
	if App.bank_gold < cost:
		ui._st(App.tr("common.not_enough_banked_gold"))
		return
	var visit: Dictionary = _visit(ui)
	var pots: Array = visit.get("potions", [])
	if idx < 0 or idx >= pots.size():
		return
	var it: Dictionary = pots[idx]
	if not Cons.hold_potion(App.prog, it):
		ui._st(App.tr("shop.potion_hold_full") % Cons.potion_cap())
		return
	App.bank_gold -= cost
	pots.remove_at(idx)
	visit["potions"] = pots
	ui.set_meta("vendor_visit", visit)
	ui._st(App.tr("shop.potion_ready"))
	VendorFrame.refresh_bank(ui)
	App.save_now()
	rebuild_vendor(ui)

static func _buy_food(ui, fid: String, mode: String) -> void:
	var cost: int = int(App.bal.vendor_food_cost)
	if App.bank_gold < cost:
		ui._st(App.tr("common.not_enough_banked_gold"))
		return
	if mode == "new" and Cons.needs_toss(App.prog, fid):
		ui.set_meta("vendor_toss", fid)
		rebuild_vendor(ui)
		return
	if not Cons.give_food(App.prog, fid, 1):
		ui._st(App.tr("shop.food_slot_is_full") % Cons.stack_cap())
		return
	App.bank_gold -= cost
	ui._st(App.tr("shop.ration_packed_in_the_food"))
	VendorFrame.refresh_bank(ui)
	App.save_now()
	rebuild_vendor(ui)

static func _toss_board(ui) -> void:
	var fid_new: String = str(ui.get_meta("vendor_toss"))
	ui.box.add_child(ThemeS.lab(App.tr("shop.toss_which"), 20, ThemeS.INK))
	var first: Button = null
	for raw: Variant in App.prog.holds.get("food", []):
		var row: Dictionary = raw as Dictionary
		var fid: String = str(row.get("food", ""))
		var toss_id: String = fid
		var toss: Button = _shelf(row, App.tr("shop.toss_stack") % [str(row.get("name", fid)), int(row.get("stack", 0))], func() -> void: _confirm_toss(ui, toss_id, fid_new))
		if first == null:
			first = toss
		ui.box.add_child(toss)
	var back: Button = ThemeS.btn(App.tr("common.back"), func() -> void:
		ui.remove_meta("vendor_toss")
		rebuild_vendor(ui)
	)
	VendorFrame.dress(back, false)
	ui.box.add_child(back)
	ui.focus_btn = first if first != null else back

static func _confirm_toss(ui, fid: String, fid_new: String) -> void:
	var cost: int = int(App.bal.vendor_food_cost)
	if App.bank_gold < cost:
		ui._st(App.tr("common.not_enough_banked_gold"))
		return
	Cons.toss_food(App.prog, fid)
	if not Cons.give_food(App.prog, fid_new, 1):
		ui._st(App.tr("shop.food_slot_is_full") % Cons.stack_cap())
		return
	App.bank_gold -= cost
	ui.remove_meta("vendor_toss")
	ui._st(App.tr("shop.ration_packed_in_the_food"))
	VendorFrame.refresh_bank(ui)
	App.save_now()
	rebuild_vendor(ui)

static func vend_sell(ui) -> void:
	if App.bank_ore < 1:
		ui._st(App.tr("shop.no_ore_in_the_bank"))
		return
	App.bank_ore -= 1
	App.bank_gold += int(App.bal.vendor_ore_gold)
	ui._st(App.tr("shop.sold_1_ore"))
	VendorFrame.refresh_bank(ui)
	App.save_now()
