extends Object

const Stats := preload("res://scripts/ui/gear_board_stats.gd")

const NAMES := {
	"weapon": "Weapon",
	"tool": "Tool",
	"potion": "Potion",
	"food": "Food",
	"head": "Head",
	"body": "Body",
	"legs": "Legs",
}

static var seen_uids: Dictionary = {}


static func slot_face(ui: CanvasLayer, slot: String, it: Dictionary) -> String:
	var head := str(NAMES.get(slot, slot))
	if has_unseen(slot):
		head = "▸ " + head
	if it.is_empty():
		return "%s\nempty" % head
	var body := item_short(it)
	var mark := risk_mark(it, str(ui.get("gear_mode")) == "loadout")
	if mark != "":
		body += "\n" + mark
	return "%s\n%s" % [head, body]


static func item_short(it: Dictionary) -> String:
	if it.is_empty():
		return "empty"
	var nm := str(it.get("name", "item"))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		return "%s  %d/%d" % [nm, _charges(it), _charge_max(it)]
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "  x%d" % stack
	return nm


static func item_cell(it: Dictionary) -> String:
	var nm := str(it.get("name", "item"))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		return "%s\n%d/%d" % [nm, _charges(it), _charge_max(it)]
	var stack := int(it.get("stack", 1))
	if stack > 1:
		nm += "\nx%d" % stack
	elif bool(it.get("hold", false)):
		nm += "\nhold"
	elif str(it.get("kind", "")) == "artifact":
		nm += "\n" + str(it.get("set", "relic"))
	return nm


static func _charges(it: Dictionary) -> int:
	if it.has("charges"):
		return int(it.charges)
	return int(it.get("stack", 0))


static func _charge_max(it: Dictionary) -> int:
	if it.has("charge_max"):
		return maxi(1, int(it.charge_max))
	if it.has("charges"):
		return maxi(1, int(it.charges))
	return maxi(1, int(it.get("stack", 1)))


static func item_color(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0.62, 0.58, 0.52)
	if is_risk(it):
		return Color(0.95, 0.55, 0.38)
	match str(it.get("rarity", "white")):
		"green":
			return Color(0.55, 0.86, 0.52)
		"blue":
			return Color(0.52, 0.7, 1.0)
		_:
			if str(it.get("kind", "")) == "artifact":
				return Color(0.92, 0.78, 0.48)
			return Color(0.92, 0.84, 0.62)


static func is_risk(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	if bool(it.get("hold", false)):
		return false
	if str(it.get("kit_src", "")) == "starter":
		return false
	if str(it.get("kit_src", "")) == "hold":
		return false
	if str(it.get("kind", "")) == "artifact":
		return true
	if str(it.get("kit_src", "")) == "bank":
		return true
	return not bool(it.get("hold", false)) and str(it.get("kit_src", "")) != ""


static func risk_mark(it: Dictionary, loadout: bool) -> String:
	if it.is_empty():
		return ""
	if bool(it.get("hold", false)) or str(it.get("kit_src", "")) == "hold":
		return "HOLD"
	if loadout and is_risk(it):
		return "AT RISK"
	return ""


static func hint_line(ui: CanvasLayer) -> String:
	if bool(ui.get("gear_sub")):
		return "A equip / unequip   B close list   X drop   hold X destroy   Y tip off/on/forge"
	return "A re-equip   X drop   hold X destroy   Y tip off/on/forge"


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


static func selected(ui: CanvasLayer) -> Dictionary:
	var sel := str(ui.inv_sel)
	if sel.begins_with("slot:"):
		var it: Dictionary = App.prog.slots.get(sel.substr(5), {})
		return it if it is Dictionary else {}
	if sel.begins_with("bag:"):
		var uid := int(sel.substr(4))
		for raw: Variant in App.prog.bag:
			if raw is Dictionary and int(raw.uid) == uid:
				return raw
	if sel.begins_with("opt:"):
		var parts := sel.split(":")
		if parts.size() >= 4:
			for row: Dictionary in options_for(parts[2]):
				if str(row.src) == parts[1] and int(row.uid) == int(parts[3]):
					return row.it
	return {}


static func options_for(slot: String) -> Array:
	var out: Array = []
	var seen_uid := {}
	var seen_tmpl := {}
	var cur: Dictionary = App.prog.slots.get(slot, {})
	if not cur.is_empty():
		var c: Dictionary = cur.duplicate(true)
		if str(c.get("kit_src", "")) == "":
			c["kit_src"] = "equipped"
		out.append({"it": c, "src": "equipped", "uid": int(c.get("uid", 0))})
		seen_uid[int(c.get("uid", 0))] = true
		seen_tmpl[_tmpl(c)] = true
	if App.in_dungeon:
		for raw: Variant in App.prog.bag:
			if raw is Dictionary and str(raw.get("slot", "")) == slot:
				if slot == "tool" and str(raw.get("tool", "")) != "" and str(raw.tool) != App.prog.tool_type:
					continue
				var uid := int(raw.uid)
				if uid != 0 and seen_uid.has(uid):
					continue
				if seen_tmpl.has(_tmpl(raw)):
					continue
				seen_uid[uid] = true
				seen_tmpl[_tmpl(raw)] = true
				out.append({"it": raw, "src": "bag", "uid": uid})
		return out
	if slot == "weapon":
		for w: String in ["great_axe", "staff", "longbow"]:
			var tmpl := "weapon:" + w
			if seen_tmpl.has(tmpl):
				continue
			var st: Dictionary = App.prog.make_weapon(w, "white")
			st["kit_src"] = "starter"
			seen_tmpl[tmpl] = true
			out.append({"it": st, "src": "starter", "uid": int(st.uid)})
	elif slot == "tool":
		for t: String in ["pickaxe", "hatchet"]:
			var tmpl := "tool:" + t
			if seen_tmpl.has(tmpl):
				continue
			var tl: Dictionary = App.prog.make_tool(t)
			tl["kit_src"] = "starter"
			seen_tmpl[tmpl] = true
			out.append({"it": tl, "src": "starter", "uid": int(tl.uid)})
	elif slot == "potion":
		if not seen_tmpl.has("potion:Potion"):
			var pot: Dictionary = App.prog.make_potion(2)
			pot["kit_src"] = "starter"
			pot["charges"] = 2
			pot["charge_max"] = 2
			seen_tmpl["potion:Potion"] = true
			out.append({"it": pot, "src": "starter", "uid": int(pot.uid)})
	var holds: Array = App.prog.holds.get(slot, [])
	for h: Variant in holds:
		if h is Dictionary:
			var uid := int(h.uid)
			if uid != 0 and seen_uid.has(uid):
				continue
			if seen_tmpl.has(_tmpl(h)):
				continue
			var hd: Dictionary = (h as Dictionary).duplicate(true)
			hd["kit_src"] = "hold"
			seen_uid[uid] = true
			seen_tmpl[_tmpl(hd)] = true
			out.append({"it": hd, "src": "hold", "uid": uid})
	var unlocked: Array = []
	if App.prog.get("starters") is Dictionary:
		unlocked = App.prog.starters.get(slot, [])
	for raw_s: Variant in unlocked:
		if raw_s is Dictionary:
			if seen_tmpl.has(_tmpl(raw_s)):
				continue
			var us: Dictionary = (raw_s as Dictionary).duplicate(true)
			us["kit_src"] = "starter"
			seen_tmpl[_tmpl(us)] = true
			out.append({"it": us, "src": "starter", "uid": int(us.get("uid", 0))})
	for raw2: Variant in App.prog.bank_items:
		if raw2 is Dictionary and str(raw2.get("slot", "")) == slot:
			if str(raw2.get("rarity", "white")) == "white":
				continue
			var uid2 := int(raw2.uid)
			if uid2 != 0 and seen_uid.has(uid2):
				continue
			if seen_tmpl.has(_tmpl(raw2)):
				continue
			var bk: Dictionary = (raw2 as Dictionary).duplicate(true)
			bk["kit_src"] = "bank"
			seen_uid[uid2] = true
			seen_tmpl[_tmpl(bk)] = true
			out.append({"it": bk, "src": "bank", "uid": uid2})
	return out


static func _tmpl(it: Dictionary) -> String:
	var slot := str(it.get("slot", ""))
	if slot == "weapon":
		return "weapon:" + str(it.get("weapon", it.get("name", "")))
	if slot == "tool":
		return "tool:" + str(it.get("tool", ""))
	if slot == "potion":
		return "potion:" + str(it.get("name", "Potion"))
	return "%s:%s:%s" % [slot, str(it.get("name", "")), str(it.get("rarity", "white"))]


static func has_unseen(slot: String) -> bool:
	var seen: Array = seen_uids.get(slot, [])
	for row: Dictionary in options_for(slot):
		if str(row.src) == "equipped" or str(row.src) == "starter":
			continue
		var uid := int(row.uid)
		if uid == 0:
			continue
		if seen.find(uid) < 0:
			return true
	return false


static func mark_seen(slot: String) -> void:
	var ids: Array = []
	for row: Dictionary in options_for(slot):
		ids.append(int(row.uid))
	seen_uids[slot] = ids


static func tooltip(ui: CanvasLayer) -> String:
	if str(ui.inv_sel) == "stats":
		return ""
	var mode := int(ui.get("gear_tip_mode"))
	if mode <= 0:
		return ""
	var it := selected(ui)
	var slot := selected_slot(ui)
	if it.is_empty():
		if slot != "":
			return "%s — empty\nA opens anything that can go here." % str(NAMES.get(slot, slot))
		return "Empty bag slot."
	if mode >= 2:
		return forged_block(it)
	return current_block(it)


static func current_block(it: Dictionary) -> String:
	var lines := PackedStringArray()
	var head := str(it.get("name", "Item"))
	var rare := str(it.get("rarity", "white"))
	if rare != "":
		head += "  ·  " + rare.capitalize()
	if bool(it.get("hold", false)):
		head += "  ·  forged hold"
	if is_risk(it):
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
		return current_block(it) + "\nY: no forge preview for this."
	if str(it.get("rarity", "white")) == "white" and (slot == "weapon" or slot == "tool"):
		return current_block(it) + "\nY: starters cannot be forged."
	var up := forge_preview(it)
	var lines := PackedStringArray()
	lines.append("Forge preview — %s" % str(up.get("name", "Forged")))
	lines.append("Now:  +%d dmg   +%d def   +%d HP   %s" % [int(it.get("dmg", 0)), int(it.get("def", 0)), int(it.get("hp", 0)), str(it.get("rarity", "white"))])
	lines.append("After anvil:  +%d dmg   +%d def   +%d HP   %s  (hold)" % [int(up.get("dmg", 0)), int(up.get("def", 0)), int(up.get("hp", 0)), str(up.get("rarity", "green"))])
	lines.append("Holds return to Placeholdia. Unforged gear taken below does not.")
	return "\n".join(lines)


static func forge_preview(it: Dictionary) -> Dictionary:
	var up: Dictionary = it.duplicate(true)
	up.dmg = int(up.get("dmg", 0)) + 1 + int(App.prog.skill_lv("smith") / 4)
	up.def = int(up.get("def", 0)) + 1
	if str(up.get("rarity", "white")) == "white":
		up.rarity = "green"
	if not str(up.get("name", "")).begins_with("Forged "):
		up.name = "Forged " + str(up.get("name", "item"))
	up.hold = true
	return up


static func stat_bits(it: Dictionary) -> String:
	var bits := PackedStringArray()
	if int(it.get("dmg", 0)) != 0:
		bits.append("%+d damage" % int(it.dmg))
	if int(it.get("def", 0)) != 0:
		bits.append("%+d defense" % int(it.def))
	if int(it.get("hp", 0)) != 0:
		bits.append("%+d HP" % int(it.hp))
	if str(it.get("kind", "")) == "potion" or str(it.get("slot", "")) == "potion":
		bits.append("Charges %d/%d" % [_charges(it), _charge_max(it)])
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
