extends Object

## Split from shop.gd: rebuild_vendor, _visit, _leave....

const Cons := preload("res://scripts/data/progress_gear/consumable.gd")
const Talk := preload("res://scripts/data/talk_lines.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const VendorFrame: GDScript = preload("res://scripts/ui/progress_ui/vendor_frame.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")

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
