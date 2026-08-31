extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")


static func sets_blurb() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var c: Dictionary = App.prog.set_counts()
	for s in CatalogS.SETS:
		var n: int = int(c.get(s, 0))
		if n > 0:
			bits.append("%s %d/%d%s" % [s, n, CatalogS.set_size(s), " *" if n >= 2 else ""])
	return "Sets: " + (", ".join(bits) if bits.size() > 0 else "none")


static func rebuild_inv(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab("Inventory", 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("Bag %d/%d   Gold %d   Ore %d   Wood %d   Root %d" % [App.prog.bag_count(), int(App.bal.bag_cap), App.gold, App.ore, App.wood, App.prog.root], 20, Color(0.88, 0.82, 0.7)))
	ui.box.add_child(ThemeS.lab(sets_blurb(), 18, Color(0.85, 0.72, 0.45)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	for s in App.prog.SLOTS:
		var eq_it: Dictionary = App.prog.slots.get(s, {})
		var slot := str(s)
		var nm := str(eq_it.get("name", "—"))
		var eq_row := HBoxContainer.new()
		eq_row.add_theme_constant_override("separation", 8)
		var eq_lab := ThemeS.btn("%s: %s" % [slot, nm], func(): ui._st(nm))
		eq_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_row.add_child(eq_lab)
		if not eq_it.is_empty():
			eq_row.add_child(ThemeS.btn("Unequip", func(): ui._st(App.prog.unequip_slot(slot)); ui._rebuild_inv(); ui._show()))
			eq_row.add_child(ThemeS.btn("Drop", func(): ui._confirm(func(): ui._st(App.prog.drop_slot(slot)); ui._rebuild_inv(); ui._show(), "drop_slot_" + slot)))
		ui.box.add_child(eq_row)
		if ui.focus_btn == null:
			ui.focus_btn = eq_lab
	if ui.focus_btn == null:
		ui.focus_btn = ThemeS.btn("Use potion  (D-pad Up)", func(): ui._st(App.prog.use_potion()))
		ui.box.add_child(ui.focus_btn)
	else:
		ui.box.add_child(ThemeS.btn("Use potion  (D-pad Up)", func(): ui._st(App.prog.use_potion())))
	ui.box.add_child(ThemeS.btn("Use food  (D-pad Left)", func(): ui._st(App.prog.use_food())))
	for bag_it in App.prog.bag:
		var uid := int(bag_it.uid)
		var line := "%s  ·  %s" % [bag_it.name, bag_it.desc]
		if str(bag_it.kind) == "artifact":
			line += "\n" + App.prog.set_bonus_text(str(bag_it.set))
		var bag_row := HBoxContainer.new()
		bag_row.add_theme_constant_override("separation", 8)
		var use_b := ThemeS.btn(line, func(): ui._inv_act(uid))
		use_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_row.add_child(use_b)
		bag_row.add_child(ThemeS.btn("Drop", func(): ui._confirm(func(): ui._st(App.prog.drop_uid(uid)); ui._rebuild_inv(); ui._show(), "drop_bag_%d" % uid)))
		ui.box.add_child(bag_row)
	if not App.in_dungeon and App.prog.bank_items.size() > 0:
		ui.box.add_child(ThemeS.lab("Mailed stash — safe in Placeholdia. Forge at the anvil.", 18, Color(0.75, 0.85, 0.7)))
		for stash_it in App.prog.bank_items:
			var sid := int(stash_it.uid)
			ui.box.add_child(ThemeS.btn("Stash %s" % stash_it.name, func(): ui._confirm(func(): ui._st(App.prog.drop_stash(sid)); ui._rebuild_inv(); ui._show(), "stash_%d" % sid)))
	ui.box.add_child(ThemeS.btn("Close  (B)", func(): ui.close_ui()))


static func inv_act(ui, uid: int) -> void:
	var it := {}
	for b in App.prog.bag:
		if int(b.uid) == uid:
			it = b
			break
	if it.is_empty():
		ui._st("Gone.")
		return
	if str(it.kind) == "potion" or str(it.kind) == "food":
		ui._st(App.prog.use_from_bag(uid))
	else:
		ui._st(App.prog.equip_uid(uid))
	ui._rebuild_inv()
	ui._show()


static func rebuild_extract(ui) -> void:
	ui._clear()
	var title := "Gather Clerk"
	if ui.extract_role == "misc":
		title = "Misc Clerk"
	elif ui.extract_role == "patty":
		title = "Packmule Patty"
	ui.box.add_child(ThemeS.lab(title, 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("Mail goods to the surface. Artifacts stay with you (run-only).", 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("A to select. Confirm with A again. B leaves.", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn("Send All  (confirm)", func(): ui._confirm(func(): ui._do_send_all(), "send_all"))
	ui.box.add_child(ui.focus_btn)
	for it in App.prog.extractable(ui.extract_role):
		var cap := str(it.get("name", "?"))
		if it.has("n"):
			cap += "  x%d" % int(it.n)
		var copy: Dictionary = it.duplicate(true)
		ui.box.add_child(ThemeS.btn("Send  " + cap, func(): ui._confirm(func(): ui._do_send_one(copy), "send_" + cap)))
	ui.box.add_child(ThemeS.btn("Leave  (B)", func(): ui.close_ui()))
