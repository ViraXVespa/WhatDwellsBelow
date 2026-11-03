extends Object

## Split from smoke_p7.gd: hub_check, _hub_clear, _hub_forge....

const Store := preload("res://scripts/data/save_store.gd")
const PlaytestHub := preload("res://scripts/debug/playtest_hub/forge_pass.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Campaign := preload("res://scripts/debug/smoke/p7_campaign.gd")

static func hub_check() -> void:
	if OS.has_feature("web"):
		printerr("P7: hub_skip=web")
		return
	var mem: Dictionary = Store.collect()
	var camp: Dictionary = Campaign._campaign_snap()
	var smoke: Dictionary = Campaign._files_snap("smoke")
	var forged: bool = _hub_forge()
	Store.apply(mem)
	var skipped: bool = _hub_skip()
	Store.apply(mem)
	Campaign._campaign_restore(camp)
	Campaign._files_restore(smoke)
	if forged and skipped:
		printerr("P7: hub_ok=true")
	else:
		printerr("ERROR: Failed to prove the playtest hub pass")

static func _hub_clear() -> void:
	App.prog.bag.clear()
	App.prog.bank_items.clear()
	App.prog.set("forge_book", {})
	App.prog.pick_weapon = "great_axe"
	App.prog.tool_type = "pickaxe"
	App.prog.slots["head"] = {}
	App.prog.slots["body"] = {}
	App.prog.slots["legs"] = {}
	var tool: Dictionary = App.prog.make_tool("pickaxe", "white", 1)
	tool["hold"] = true
	tool["kit_src"] = "hold"
	App.prog.slots["tool"] = tool
	App.gold = 0
	App.ore = 0
	App.wood = 0
	App.bank_gold = 50000
	App.bank_ore = 50000
	App.bank_wood = 50000

static func _hub_forge() -> bool:
	_hub_clear()
	var worn: Dictionary = App.prog.make_weapon("great_axe", "green", 1)
	worn["hold"] = true
	worn["kit_src"] = "hold"
	App.prog.holds["weapon"] = [worn]
	App.prog.hold_pick["weapon"] = 0
	App.prog.slots["weapon"] = worn.duplicate(true)
	var donor: Dictionary = App.prog.make_weapon("great_axe", "blue", 4)
	donor["hold"] = false
	donor["kit_src"] = "bank"
	App.prog.bank_items.append(donor)
	var uid: int = PlaytestHub.run_hub()
	if uid <= 0 or int(App.prog.slots["weapon"].get("ilvl", 0)) != 1 or App.bank_gold >= 50000:
		printerr("P7: hub_forge uid=%s ilvl=%s gold=%s" % [str(uid), str(App.prog.slots["weapon"].get("ilvl", 0)), str(App.bank_gold)])
		return false
	Store.save_slot("campaign")
	Store.load_slot("campaign")
	App.tel.reset("campaign", true)
	PlaytestHub.equip_pending(uid)
	var piece: Dictionary = App.prog.slots.get("weapon", {})
	var found: bool = false
	for row: Variant in App.tel.changes:
		if row is Dictionary and str(row.get("phase", "")) == "hub" and str(row.get("kind", "")) == "equip" and str(row.get("slot", "")) == "weapon" and int(row.get("ilvl", 0)) == 4:
			found = true
	var ok: bool = int(piece.get("ilvl", 0)) == 4 and str(piece.get("weapon", "")) == "great_axe" and found
	if not ok:
		printerr("P7: hub_equip ilvl=%s type=%s change=%s" % [str(piece.get("ilvl", 0)), str(piece.get("weapon", "")), str(found)])
	return ok

static func _hub_skip() -> bool:
	_hub_clear()
	var book: Dictionary = {}
	book[Affix.book_key("weapon", "great_axe", "green")] = {
		"ilvl": 2,
		"ids": [Affix.ID_DMG],
		"luck": {Affix.ID_DMG: 0.75},
	}
	App.prog.set("forge_book", book)
	var worn: Dictionary = App.prog.make_weapon("great_axe", "green", 2)
	worn["hold"] = true
	worn["kit_src"] = "hold"
	worn["affixes"] = [{"id": Affix.ID_DMG, "value": 999.0, "luck": 0.75}]
	worn["dmg"] = 999
	App.prog.holds["weapon"] = [worn]
	App.prog.hold_pick["weapon"] = 0
	App.prog.slots["weapon"] = worn.duplicate(true)
	var donor: Dictionary = App.prog.make_weapon("great_axe", "green", 2)
	donor["hold"] = false
	donor["kit_src"] = "bank"
	donor["affixes"] = [{"id": Affix.ID_DMG, "value": 1.0, "luck": 0.5}]
	App.prog.bank_items.append(donor)
	var uid: int = PlaytestHub.run_hub()
	var piece: Dictionary = App.prog.slots.get("weapon", {})
	var ok: bool = uid == 0 and App.bank_gold == 50000 and int(piece.get("ilvl", 0)) == 2
	if not ok:
		printerr("P7: hub_skip uid=%s gold=%s ilvl=%s" % [str(uid), str(App.bank_gold), str(piece.get("ilvl", 0))])
	return ok
