extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")
const Text := preload("res://scripts/ui/pause_inv_text.gd")


static func _primary(ui: CanvasLayer) -> void:
	load("res://scripts/ui/pause_inv_act.gd").primary(ui)


static func build(ui: CanvasLayer) -> void:
	var gold_n: int = App.gold
	var ore_n: int = App.ore
	var wood_n: int = App.wood
	var bag_n: int = App.prog.bag_count()
	var bag_cap: int = int(App.bal.bag_cap)
	ui.box.add_child(ui._cap("Carried  %dg   %d ore   %d wood   bag %d/%d" % [gold_n, ore_n, wood_n, bag_n, bag_cap], 22, Color(0.95, 0.8, 0.45)))
	ui.box.add_child(ui._cap(status_line(), 16, Color(0.78, 0.74, 0.66)))
	var hint: String = "A on an item uses or equips it. Buttons below act on the highlighted item."
	if App.in_dungeon:
		hint += " Drop puts it on the floor."
	else:
		hint += " Drop is dungeon-only."
	ui.box.add_child(ui._cap(hint, 16, Color(0.7, 0.66, 0.6)))
	ui.inv_detail = ui._cap("Select an item.", 18, Color(0.9, 0.84, 0.7))
	ui.inv_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.inv_detail.custom_minimum_size = Vector2(1360, 72)
	ui.box.add_child(ui.inv_detail)
	var acts: HBoxContainer = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	ui.inv_btn_use = ThemeS.btn("Use", ui._inv_use)
	ui.inv_btn_equip = ThemeS.btn("Equip", ui._inv_equip)
	ui.inv_btn_unequip = ThemeS.btn("Unequip", ui._inv_unequip)
	ui.inv_btn_drop = ThemeS.btn("Drop", ui._inv_drop)
	acts.add_child(ui.inv_btn_use)
	acts.add_child(ui.inv_btn_equip)
	acts.add_child(ui.inv_btn_unequip)
	acts.add_child(ui.inv_btn_drop)
	ui.box.add_child(acts)
	ui.box.add_child(ui._cap("Equipped", 20, Color(0.88, 0.82, 0.7)))
	var first_row: Control = null
	for s: String in App.prog.SLOTS:
		var row: Button = slot_btn(ui, s)
		ui.box.add_child(row)
		if first_row == null:
			first_row = row
	var sets_line: String = sets_line_text()
	if sets_line != "":
		ui.box.add_child(ui._cap("Artifact sets", 20, Color(0.88, 0.82, 0.7)))
		var sl: Label = ui._cap(sets_line, 18, Color(0.82, 0.76, 0.62))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(1360, 0)
		ui.box.add_child(sl)
	ui.box.add_child(ui._cap("Bag", 20, Color(0.88, 0.82, 0.7)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = ui.BAG_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cap: int = maxi(int(App.bal.bag_cap), App.prog.bag.size())
	for i: int in cap:
		var it: Dictionary = {}
		if i < App.prog.bag.size() and App.prog.bag[i] is Dictionary:
			it = App.prog.bag[i]
		grid.add_child(bag_cell(ui, it, i))
	ui.box.add_child(grid)
	if first_row:
		ui.focus_btn = first_row
	ui.status = ui._cap("", 16, Color(0.78, 0.74, 0.66))
	ui.box.add_child(ui.status)
	ui.box.add_child(ThemeS.btn("Close  (B)", ui.close_ui))
	refresh_detail(ui)


static func status_line() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var pot: Dictionary = App.prog.slots.get("potion", {})
	if pot.is_empty() or int(pot.get("stack", 0)) <= 0:
		bits.append("Potion slot empty")
	elif App.prog.potion_cd > 0.05:
		bits.append("Potion CD %.1fs" % App.prog.potion_cd)
	else:
		bits.append("Potion x%d ready" % int(pot.stack))
	if App.prog.food_t > 0.05:
		bits.append("Food ticking %.1fs" % App.prog.food_t)
	else:
		var fd: Dictionary = App.prog.slots.get("food", {})
		if fd.is_empty() or int(fd.get("stack", 0)) <= 0:
			bits.append("Food slot empty")
		else:
			bits.append("%s x%d ready" % [str(fd.get("name", "Food")), int(fd.stack)])
	return "  ·  ".join(bits)


static func sets_line_text() -> String:
	var counts: Dictionary = App.prog.set_counts()
	var parts: PackedStringArray = PackedStringArray()
	for sid: String in CatalogS.set_ids():
		var n: int = int(counts.get(sid, 0))
		if n <= 0:
			continue
		var need: int = CatalogS.set_size(sid)
		var bit: String = "%s %d/%d" % [str(sid).capitalize(), n, need]
		if n >= 2:
			var bonus: String = CatalogS.set_bonus_line(sid, n)
			if bonus != "":
				bit += " — " + bonus
		parts.append(bit)
	return "   ".join(parts)


static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	var it: Dictionary = App.prog.slots.get(slot, {})
	var title: String = str(ui.SLOT_NAMES.get(slot, slot))
	var body: String = "empty"
	if not it.is_empty():
		body = item_short(it)
	var b: Button = ThemeS.btn("%s	%s" % [title, body], func():
		ui.inv_sel = "slot:" + slot
		refresh_detail(ui)
		_primary(ui)
	)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", item_color(it))
	b.set_meta("inv_key", "slot:" + slot)
	b.focus_entered.connect(func():
		ui.inv_sel = "slot:" + slot
		refresh_detail(ui)
	)
	return b


static func bag_cell(ui: CanvasLayer, it: Dictionary, _index: int) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(188, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.35, 0.32))
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.4, 0.3, 0.18)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.26, 0.2, 0.13), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.14, 0.11, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", ThemeS.sb(Color(0.11, 0.09, 0.08), Color(0.22, 0.18, 0.14)))
	if it.is_empty():
		b.text = "—"
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", Color(0.4, 0.36, 0.32))
		return b
	var key: String = "bag:" + str(int(it.uid))
	b.text = item_cell(it)
	b.add_theme_color_override("font_color", item_color(it))
	b.set_meta("inv_key", key)
	b.pressed.connect(func():
		ui.inv_sel = key
		refresh_detail(ui)
		_primary(ui)
	)
	b.focus_entered.connect(func():
		ui.inv_sel = key
		refresh_detail(ui)
	)
	return b


static func item_short(it: Dictionary) -> String:
	return Text.item_short(it)


static func item_cell(it: Dictionary) -> String:
	return Text.item_cell(it)


static func item_color(it: Dictionary) -> Color:
	return Text.item_color(it)


static func selected(ui: CanvasLayer) -> Dictionary:
	return Text.selected(ui)


static func selected_slot(ui: CanvasLayer) -> String:
	return Text.selected_slot(ui)


static func selected_uid(ui: CanvasLayer) -> int:
	return Text.selected_uid(ui)


static func from_bag(ui: CanvasLayer) -> bool:
	return Text.from_bag(ui)


static func find_sel(ui: CanvasLayer) -> Control:
	return Text.find_sel(ui)


static func refresh_detail(ui: CanvasLayer) -> void:
	Text.refresh_detail(ui)


static func detail_text(ui: CanvasLayer, it: Dictionary) -> String:
	return Text.detail_text(ui, it)


static func stat_line(ui: CanvasLayer, it: Dictionary) -> String:
	return Text.stat_line(ui, it)


static func extract_note(it: Dictionary) -> String:
	return Text.extract_note(it)


static func can_use_item(it: Dictionary) -> bool:
	return Text.can_use_item(it)


static func can_equip_item(ui: CanvasLayer, it: Dictionary) -> bool:
	return Text.can_equip_item(ui, it)
