extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")

static func sets_blurb() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var c: Dictionary = App.prog.set_counts()
	for s in CatalogS.SETS:
		var n: int = int(c.get(s, 0))
		if n > 0:
			bits.append(App.tr("inv.text") % [s, n, CatalogS.set_size(s), " *" if n >= 2 else ""])
	return "Sets: " + (", ".join(bits) if bits.size() > 0 else "none")

static func rebuild_inv(ui) -> void:
	ui._clear()
	ui.gear_mode = "inv"
	Board.build(ui, "inv")

static func rebuild_extract(ui) -> void:
	ui._clear()
	var title := App.tr("common.extraction_gate")
	if ui.extract_role == "misc":
		title = App.tr("common.extraction_gate")
	elif ui.extract_role == "gather":
		title = App.tr("common.extraction_gate")
	ui.box.add_child(ThemeS.lab(title, 32, ThemeS.INK))
	ui.box.add_child(ThemeS.lab(App.tr("inv.mail_goods_to_the_surface"), 18, ThemeS.INK_SOFT))
	ui.status = ThemeS.lab("", 20, ThemeS.INK)
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn(App.tr("common.send_all"), func(): Confirm.open(ui, App.tr("common.send_all"), App.tr("inv.mail_all_extractable_goods_to"), func(): ui._do_send_all()), true, "primary")
	ui.box.add_child(ui.focus_btn)
	for it in App.prog.extractable(ui.extract_role):
		var cap := str(it.get("name", "?"))
		if it.has("n"):
			cap += "  x%d" % int(it.n)
		var copy: Dictionary = it.duplicate(true)
		ui.box.add_child(ThemeS.btn("Send  " + cap, func(): Confirm.open(ui, App.tr("inv.send_item"), App.tr("inv.mail_to_the_surface") % cap, func(): ui._do_send_one(copy))))
	ui.box.add_child(ThemeS.btn(App.tr("common.leave"), func(): ui.close_ui()))
