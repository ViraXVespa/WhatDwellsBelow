extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const Extract := preload("res://scripts/data/progress/extract.gd")

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
	ui.inv_sel = "slot:weapon"
	Board.build(ui, "extract")

static func add_resource_row(ui) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var any := false
	for it in App.prog.extractable(ui.extract_role):
		if str(it.get("from_slot", "")) != "":
			continue
		if str(it.get("kind", "")) not in ["ore", "wood", "root", "gold"]:
			continue
		var cap := str(it.get("name", "?"))
		if it.has("n"):
			cap += "  x%d" % int(it.n)
		var copy: Dictionary = it.duplicate(true)
		var b := ThemeS.btn(cap, func(): _ask(ui, cap, copy), true, "secondary")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		any = true
	if any:
		ui.box.add_child(ThemeS.lab(App.tr("extract.resources"), 20, ThemeS.INK))
		ui.box.add_child(row)

static func add_send_all(ui) -> void:
	var b := ThemeS.btn(App.tr("common.send_all"), func(): Confirm.open(ui, App.tr("common.send_all"), App.tr("inv.mail_all_extractable_goods_to"), func(): ui._do_send_all()), true, "primary")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.box.add_child(b)

static func send_slot(ui, slot: String) -> void:
	ui.inv_sel = "slot:" + slot
	var it: Dictionary = App.prog.slots.get(slot, {})
	if it.is_empty():
		ui._st(App.tr("common.empty"))
		return
	if not Extract._equipped_listed(it, slot):
		ui._st(_stay_line(it, slot))
		return
	var copy: Dictionary = it.duplicate(true)
	copy["from_slot"] = slot
	_ask(ui, str(it.get("name", "?")), copy)

static func send_bag(ui, it: Dictionary) -> void:
	if not Extract._bag_mailable(it):
		ui._st(_stay_line(it, ""))
		return
	var copy: Dictionary = it.duplicate(true)
	_ask(ui, str(it.get("name", "?")), copy)

static func _ask(ui, cap: String, it: Dictionary) -> void:
	Confirm.open(ui, App.tr("inv.send_item"), App.tr("inv.mail_to_the_surface") % cap, func(): ui._do_send_one(it))

static func _stay_line(it: Dictionary, slot: String) -> String:
	if str(it.get("kind", "")) == "artifact":
		return App.tr("extract.artifacts_cannot_be_mailed")
	if bool(it.get("hold", false)):
		return App.tr("extract.forged_holds_stay_with_you")
	if (slot == "weapon" or slot == "tool") and str(it.get("rarity", "white")) == "white":
		return App.tr("board_sub.starters_stay_on_the_slot")
	return App.tr("common.nothing")
