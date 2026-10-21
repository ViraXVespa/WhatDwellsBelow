extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const ShopFrame: GDScript = preload("res://scripts/ui/progress_ui/shop_frame.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const Inv := preload("res://scripts/ui/progress_ui/inv.gd")
const Kit := preload("res://scripts/data/gear_rules/rules_kit.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")

const Vendor := preload("res://scripts/ui/progress_ui/shop_vendor.gd")
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
	Vendor.rebuild_vendor(ui)

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

static func vend_sell(ui) -> void:
	Vendor.vend_sell(ui)
