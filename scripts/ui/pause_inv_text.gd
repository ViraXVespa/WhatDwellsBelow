extends Object


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
