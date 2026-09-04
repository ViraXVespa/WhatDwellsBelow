extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Board := preload("res://scripts/ui/gear_board.gd")


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
	ui.gear_mode = "inv"
	Board.build(ui, "inv")


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
	var title := "Extraction Gate"
	if ui.extract_role == "misc":
		title = "Extraction Gate"
	elif ui.extract_role == "gather":
		title = "Extraction Gate"
	ui.box.add_child(ThemeS.lab(title, 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab("Mail goods to the surface. Artifacts stay with you (run-only).", 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	ui.focus_btn = ThemeS.btn("Send All  (confirm)", func(): ui._confirm(func(): ui._do_send_all(), "send_all"))
	ui.box.add_child(ui.focus_btn)
	for it in App.prog.extractable(ui.extract_role):
		var cap := str(it.get("name", "?"))
		if it.has("n"):
			cap += "  x%d" % int(it.n)
		var copy: Dictionary = it.duplicate(true)
		ui.box.add_child(ThemeS.btn("Send  " + cap, func(): ui._confirm(func(): ui._do_send_one(copy), "send_" + cap)))
	ui.box.add_child(ThemeS.btn("Leave", func(): ui.close_ui()))
