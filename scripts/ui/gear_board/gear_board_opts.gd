extends Object

const Fmt := preload("res://scripts/ui/gear_board/gear_board_text_fmt.gd")

static var seen_uids: Dictionary = {}


static func slot_item(slot: String) -> Dictionary:
	var raw: Variant = App.prog.slots.get(slot, {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return raw
	if slot == "weapon":
		var w: String = str(App.prog.pick_weapon)
		if w == "":
			w = str(App.weapon)
		if w == "":
			w = "great_axe"
		return {
			"slot": "weapon",
			"kind": "weapon",
			"weapon": w,
			"name": _weapon_label(w),
			"rarity": "white",
			"kit_src": "starter",
		}
	if slot == "tool":
		var t: String = str(App.prog.tool_type)
		if t == "":
			t = "pickaxe"
		return {
			"slot": "tool",
			"kind": "tool",
			"tool": t,
			"name": t.capitalize(),
			"rarity": "white",
			"kit_src": "starter",
		}
	return {}


static func _weapon_label(w: String) -> String:
	match w:
		"staff":
			return "Lightning Staff"
		"longbow":
			return "Longbow"
		_:
			return "Great Axe"


static func options_for(slot: String) -> Array:
	var out: Array = []
	var seen_uid := {}
	var seen_tmpl := {}
	var cur: Dictionary = slot_item(slot)
	if not cur.is_empty():
		var c: Dictionary = cur.duplicate(true)
		if str(c.get("kit_src", "")) == "":
			c["kit_src"] = "equipped"
		out.append({"it": c, "src": "equipped", "uid": int(c.get("uid", 0))})
		seen_uid[int(c.get("uid", 0))] = true
		seen_tmpl[Fmt._tmpl(c)] = true
	if App.in_dungeon:
		for raw: Variant in App.prog.bag:
			if raw is Dictionary and str(raw.get("slot", "")) == slot:
				if slot == "tool" and str(raw.get("tool", "")) != "" and str(raw.tool) != App.prog.tool_type:
					continue
				var uid := int(raw.uid)
				if uid != 0 and seen_uid.has(uid):
					continue
				if seen_tmpl.has(Fmt._tmpl(raw)):
					continue
				seen_uid[uid] = true
				seen_tmpl[Fmt._tmpl(raw)] = true
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
			if seen_tmpl.has(Fmt._tmpl(h)):
				continue
			var hd: Dictionary = (h as Dictionary).duplicate(true)
			hd["kit_src"] = "hold"
			seen_uid[uid] = true
			seen_tmpl[Fmt._tmpl(hd)] = true
			out.append({"it": hd, "src": "hold", "uid": uid})
	var unlocked: Array = []
	if App.prog.get("starters") is Dictionary:
		unlocked = App.prog.starters.get(slot, [])
	for raw_s: Variant in unlocked:
		if raw_s is Dictionary:
			if seen_tmpl.has(Fmt._tmpl(raw_s)):
				continue
			var us: Dictionary = (raw_s as Dictionary).duplicate(true)
			us["kit_src"] = "starter"
			seen_tmpl[Fmt._tmpl(us)] = true
			out.append({"it": us, "src": "starter", "uid": int(us.get("uid", 0))})
	for raw2: Variant in App.prog.bank_items:
		if raw2 is Dictionary and str(raw2.get("slot", "")) == slot:
			if str(raw2.get("rarity", "white")) == "white":
				continue
			var uid2 := int(raw2.uid)
			if uid2 != 0 and seen_uid.has(uid2):
				continue
			if seen_tmpl.has(Fmt._tmpl(raw2)):
				continue
			var bk: Dictionary = (raw2 as Dictionary).duplicate(true)
			bk["kit_src"] = "bank"
			seen_uid[uid2] = true
			seen_tmpl[Fmt._tmpl(bk)] = true
			out.append({"it": bk, "src": "bank", "uid": uid2})
	return out


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
