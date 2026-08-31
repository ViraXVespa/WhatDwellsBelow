extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const CatalogS := preload("res://scripts/data/catalog.gd")


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
	if it.is_empty():
		return "empty"
	var nm: String = str(it.get("name", "item"))
	var stack: int = int(it.get("stack", 1))
	if stack > 1:
		nm += "  x%d" % stack
	var rare: String = str(it.get("rarity", "white"))
	if rare != "" and rare != "white" and str(it.get("kind", "")) != "artifact":
		nm += "  [%s]" % rare
	if bool(it.get("hold", false)):
		nm += "  (hold)"
	return nm


static func item_cell(it: Dictionary) -> String:
	var nm: String = str(it.get("name", "item"))
	var stack: int = int(it.get("stack", 1))
	if stack > 1:
		nm += "\nx%d" % stack
	elif bool(it.get("hold", false)):
		nm += "\nhold"
	elif str(it.get("kind", "")) == "artifact":
		nm += "\n" + str(it.get("set", "relic"))
	return nm


static func item_color(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.62, 0.58, 0.52)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.55, 0.86, 0.52)
		"blue":
			return Color(0.52, 0.7, 1.0)
		_:
			if str(it.get("kind", "")) == "artifact":
				return Color(0.92, 0.78, 0.48)
			return Color(0.92, 0.84, 0.62)


static func selected(ui: CanvasLayer) -> Dictionary:
	if ui.inv_sel.begins_with("slot:"):
		var slot: String = ui.inv_sel.substr(5)
		var it: Dictionary = App.prog.slots.get(slot, {})
		return it if it is Dictionary else {}
	if ui.inv_sel.begins_with("bag:"):
		var uid: int = int(ui.inv_sel.substr(4))
		for raw: Variant in App.prog.bag:
			if raw is Dictionary and int(raw.uid) == uid:
				return raw
	return {}


static func selected_slot(ui: CanvasLayer) -> String:
	if ui.inv_sel.begins_with("slot:"):
		return ui.inv_sel.substr(5)
	return ""


static func selected_uid(ui: CanvasLayer) -> int:
	if ui.inv_sel.begins_with("bag:"):
		return int(ui.inv_sel.substr(4))
	var it: Dictionary = selected(ui)
	if it.is_empty():
		return 0
	return int(it.get("uid", 0))


static func from_bag(ui: CanvasLayer) -> bool:
	return ui.inv_sel.begins_with("bag:")


static func find_sel(ui: CanvasLayer) -> Control:
	if ui.inv_sel == "":
		return null
	for n: Node in ui.box.find_children("*", "Button", true, false):
		if str(n.get_meta("inv_key", "")) == ui.inv_sel:
			return n as Control
	return null


static func refresh_detail(ui: CanvasLayer) -> void:
	var it: Dictionary = selected(ui)
	if ui.inv_detail:
		ui.inv_detail.text = detail_text(ui, it)
	var can_use: bool = can_use_item(it)
	var can_eq: bool = can_equip_item(ui, it)
	var can_uneq: bool = (not it.is_empty()) and not from_bag(ui)
	var can_drop: bool = (not it.is_empty()) and App.in_dungeon
	if ui.inv_btn_use:
		ui.inv_btn_use.disabled = not can_use
	if ui.inv_btn_equip:
		ui.inv_btn_equip.disabled = not can_eq
	if ui.inv_btn_unequip:
		ui.inv_btn_unequip.disabled = not can_uneq
	if ui.inv_btn_drop:
		ui.inv_btn_drop.disabled = not can_drop


static func detail_text(ui: CanvasLayer, it: Dictionary) -> String:
	if it.is_empty():
		if ui.inv_sel.begins_with("slot:"):
			return "%s — empty" % str(ui.SLOT_NAMES.get(selected_slot(ui), "Slot"))
		return "Empty bag slot."
	var lines: PackedStringArray = PackedStringArray()
	var head: String = str(it.get("name", "Item"))
	var kind: String = str(it.get("kind", ""))
	var rare: String = str(it.get("rarity", "white"))
	if kind != "artifact" and rare != "":
		head += "   ·   " + rare.capitalize()
	if int(it.get("stack", 1)) > 1:
		head += "   ·   x%d" % int(it.stack)
	if bool(it.get("hold", false)):
		head += "   ·   forged hold"
	if kind == "artifact":
		head += "   ·   run relic"
	lines.append(head)
	var desc: String = str(it.get("desc", ""))
	if desc != "":
		lines.append(desc)
	var stats: String = stat_line(ui, it)
	if stats != "":
		lines.append(stats)
	var sid: String = str(it.get("set", ""))
	if sid != "":
		lines.append(App.prog.set_bonus_text(sid))
	return "\n".join(lines)


static func stat_line(ui: CanvasLayer, it: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if int(it.get("dmg", 0)) > 0:
		bits.append("+%d damage" % int(it.dmg))
	if int(it.get("def", 0)) > 0:
		bits.append("+%d defense" % int(it.def))
	if int(it.get("hp", 0)) > 0:
		bits.append("+%d HP" % int(it.hp))
	var slot: String = str(it.get("slot", ""))
	if slot != "" and str(ui.SLOT_NAMES.get(slot, "")) != "":
		bits.append(str(ui.SLOT_NAMES[slot]) + " slot")
	if str(it.get("tool", "")) != "":
		bits.append("Tool: " + str(it.tool ))
		if App.in_dungeon and str(it.tool ) != App.prog.tool_type:
			bits.append("locked out this run")
	var note: String = extract_note(it)
	if note != "":
		bits.append(note)
	return "   ·   ".join(bits)


static func extract_note(it: Dictionary) -> String:
	if str(it.get("kind", "")) == "artifact":
		return "Cannot mail. Lost on death or Dispel."
	if bool(it.get("hold", false)):
		return "Hold returns to Placeholdia."
	if App.in_dungeon:
		return "Mail through a clerk to keep it."
	return ""


static func can_use_item(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var k: String = str(it.get("kind", ""))
	return k == "potion" or k == "food"


static func can_equip_item(ui: CanvasLayer, it: Dictionary) -> bool:
	if it.is_empty() or not from_bag(ui):
		return false
	var slot: String = str(it.get("slot", ""))
	if App.prog.SLOTS.find(slot) < 0:
		return false
	if slot == "tool":
		var t: String = str(it.get("tool", ""))
		if t != "" and t != App.prog.tool_type:
			return false
	return true
