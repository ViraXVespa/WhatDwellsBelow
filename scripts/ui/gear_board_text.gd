extends Object

const Stats := preload("res://scripts/ui/gear_board_stats.gd")
const Fmt := preload("res://scripts/ui/gear_board_text_fmt.gd")
const Opts := preload("res://scripts/ui/gear_board_opts.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const Affix := preload("res://scripts/data/affixes.gd")


static func slot_face(_ui: CanvasLayer, slot: String, _it: Dictionary) -> String:
	var head := str(Fmt.NAMES.get(slot, slot))
	if has_unseen(slot):
		head = "▸ " + head
	return head


static func item_short(it: Dictionary) -> String:
	if it.is_empty():
		return "empty"
	var nm := str(it.get("name", "item"))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		return "%s  %d/%d" % [nm, Fmt._charges(it), Fmt._charge_max(it)]
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "  x%d" % stack
	return nm


static func item_cell(it: Dictionary) -> String:
	var nm := str(it.get("name", "item"))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		return "%s\n%d/%d" % [nm, Fmt._charges(it), Fmt._charge_max(it)]
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "\nx%d" % stack
	elif bool(it.get("hold", false)):
		nm += "\nhold"
	elif str(it.get("kind", "")) == "artifact":
		nm += "\n" + str(it.get("set", "relic"))
	return nm


static func hint_parts(ui: CanvasLayer) -> Array:
	var parts: Array = []
	if bool(ui.get("gear_sub")):
		parts.append({"action": "ui_accept", "verb": "equip / unequip", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "close list", "gap": true})
	else:
		parts.append({"action": "ui_accept", "verb": "select", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "back", "gap": true})
	parts.append({"action": "gear_drop", "verb": "drop", "gap": true})
	parts.append({"action": "gear_tip", "verb": "tip off/on/forge"})
	return parts


static func hint_line(ui: CanvasLayer) -> String:
	var bits: PackedStringArray = PackedStringArray()
	for row: Variant in hint_parts(ui):
		if not (row is Dictionary):
			continue
		var action := str(row.get("action", ""))
		if action == "":
			continue
		bits.append(Prompts.verb_line(action, str(row.get("verb", ""))))
	return "   ".join(bits)


static func selected_slot(ui: CanvasLayer) -> String:
	var sel := str(ui.inv_sel)
	if sel.begins_with("slot:"):
		return sel.substr(5)
	if sel.begins_with("opt:"):
		var parts := sel.split(":")
		if parts.size() >= 3:
			return parts[2]
		return str(ui.get("gear_sub_slot"))
	return ""


static func slot_item(slot: String) -> Dictionary:
	return Opts.slot_item(slot)


static func selected(ui: CanvasLayer) -> Dictionary:
	var sel := str(ui.inv_sel)
	if sel.begins_with("slot:"):
		return slot_item(sel.substr(5))
	if sel.begins_with("bag:"):
		var uid := int(sel.substr(4))
		for raw: Variant in App.prog.bag:
			if raw is Dictionary and int(raw.uid) == uid:
				return raw
	if sel.begins_with("opt:"):
		var parts := sel.split(":")
		if parts.size() >= 4:
			var src := parts[1]
			var slot := parts[2]
			var uid := int(parts[3])
			for row: Dictionary in options_for(slot):
				if str(row.src) == src and int(row.uid) == uid:
					return row.it if row.it is Dictionary else {}
		var Board = load("res://scripts/ui/gear_board.gd")
		var n: Node = Board.find_sel(ui)
		if n != null and n.has_meta("inv_it"):
			var stored: Variant = n.get_meta("inv_it")
			if stored is Dictionary:
				return stored
	return {}


static func options_for(slot: String) -> Array:
	return Opts.options_for(slot)


static func has_unseen(slot: String) -> bool:
	return Opts.has_unseen(slot)


static func mark_seen(slot: String) -> void:
	Opts.mark_seen(slot)


static func tooltip(ui: CanvasLayer) -> String:
	if str(ui.inv_sel) == "stats":
		return ""
	var mode := int(ui.get("gear_tip_mode"))
	if mode <= 0:
		return ""
	var it := selected(ui)
	var slot := selected_slot(ui)
	var sel := str(ui.inv_sel)
	if it.is_empty():
		if slot != "":
			return "%s — empty\nOpens anything that can go here." % str(Fmt.NAMES.get(slot, slot))
		return "Empty bag slot."
	var src := ""
	if sel.begins_with("opt:") and sel.split(":").size() >= 2:
		src = sel.split(":")[1]
	var block := current_block(it)
	if mode >= 2:
		block = forged_block(it)
	if slot != "":
		var head := str(Fmt.NAMES.get(slot, slot))
		if src != "":
			head += "  ·  " + src
		return "%s\n%s" % [head, block]
	return block


static func current_block(it: Dictionary) -> String:
	var lines := PackedStringArray()
	var head := str(it.get("name", "Item"))
	var rare := str(it.get("rarity", "white"))
	if rare != "":
		head += "  ·  " + rare.capitalize()
	if int(it.get("ilvl", 0)) > 0:
		head += "  ·  Lv%d" % int(it.get("ilvl", 1))
	if bool(it.get("hold", false)):
		head += "  ·  forged hold"
	if Fmt.is_risk(it):
		head += "  ·  lost on death unless mailed"
	lines.append(head)
	var desc := str(it.get("desc", ""))
	if desc != "":
		lines.append(desc)
	var stats := stat_bits(it)
	if stats != "":
		lines.append(stats)
	var sid := str(it.get("set", ""))
	if sid != "":
		lines.append(App.prog.set_bonus_text(sid))
	return "\n".join(lines)


static func forged_block(it: Dictionary) -> String:
	if it.is_empty():
		return "Nothing to preview."
	var slot := str(it.get("slot", ""))
	if slot == "potion" or slot == "food" or str(it.get("kind", "")) == "artifact":
		return current_block(it) + "\nNo forge preview for this."
	if str(it.get("rarity", "white")) == "white":
		return current_block(it) + "\nWhite gear is starter-only. Analyze greens and blues."
	return current_block(it) + "\nForge tab rolls a new hold from unlocked traits."


static func forge_preview(it: Dictionary) -> Dictionary:
	return it.duplicate(true)


static func stat_bits(it: Dictionary) -> String:
	var bits := PackedStringArray()
	var listed: Dictionary = {}
	var raw_aff: Variant = it.get("affixes", [])
	if raw_aff is Array:
		for row: Variant in raw_aff:
			if not (row is Dictionary):
				continue
			var id := str(row.get("id", ""))
			if id == "":
				continue
			listed[id] = true
			bits.append("%s %s" % [Affix.label_of(id), Affix.format_value(id, float(row.get("value", 0.0)))])
	for id: String in [Affix.ID_DMG, Affix.ID_DEF, Affix.ID_HP]:
		if listed.has(id):
			continue
		var n: float = float(it.get(id, 0))
		if n != 0.0:
			bits.append("%s %s" % [Affix.label_of(id), Affix.format_value(id, n)])
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		bits.append("Charges %d/%d" % [Fmt._charges(it), Fmt._charge_max(it)])
		var cd := float(it.get("cooldown", 0.0))
		if cd <= 0.0 and App.bal:
			cd = float(App.bal.get("potion_cooldown"))
		if cd > 0.0:
			bits.append("Cooldown %.1fs" % cd)
	if str(it.get("tool", "")) != "":
		bits.append("Tool: " + str(it.tool))
	if str(it.get("weapon", "")) != "":
		bits.append("Style: " + str(it.weapon))
	return "   ·   ".join(bits)


static func stats_title(ui: CanvasLayer) -> String:
	return Stats.title(ui)


static func stats_body(ui: CanvasLayer) -> String:
	return Stats.body(ui)


static func stats_page(ui: CanvasLayer) -> String:
	return Stats.page(ui)


static func page_ids(ui: CanvasLayer) -> PackedStringArray:
	return Stats.page_ids(ui)
