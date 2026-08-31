extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const Town := preload("res://scripts/data/progress_town.gd")


static func is_anvil(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "anvil"


static func tab(ui: CanvasLayer) -> String:
	var t := str(ui.get("anvil_tab"))
	return t if t == "forge" else "analyze"


static func hint_line(ui: CanvasLayer) -> String:
	if bool(ui.get("gear_sub")):
		if tab(ui) == "forge":
			return "A select remains / hold   B close list   Y tip / forge preview"
		return "A analyze — this DESTROYS the piece   B close list   Y tip"
	if tab(ui) == "forge":
		return "Forge tab — A a slot to pick analyzed remains or a hold   Q E stats"
	return "Analyze tab — A a slot, confirm to destroy the piece into remains"


static func options_for(slot: String, ui: CanvasLayer) -> Array:
	if slot == "potion" or slot == "food":
		return []
	if tab(ui) == "forge":
		return _forge_options(slot)
	return _analyze_options(slot)


static func _analyze_options(slot: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	_add_src(out, seen, slot, App.prog.bag, "bag")
	_add_src(out, seen, slot, App.prog.bank_items, "bank")
	var eq: Dictionary = App.prog.slots.get(slot, {})
	if not eq.is_empty():
		_try_add(out, seen, eq, "equipped")
	return out


static func _forge_options(slot: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for raw: Variant in App.prog.analyzed:
		if raw is Dictionary and str(raw.get("slot", "")) == slot:
			_try_add(out, seen, raw, "analyzed")
	for raw2: Variant in App.prog.holds.get(slot, []):
		if raw2 is Dictionary:
			var hd: Dictionary = raw2.duplicate(true)
			hd["kit_src"] = "hold"
			_try_add(out, seen, hd, "hold")
	return out


static func _add_src(out: Array, seen: Dictionary, slot: String, arr: Array, src: String) -> void:
	for raw: Variant in arr:
		if raw is Dictionary and str(raw.get("slot", "")) == slot:
			_try_add(out, seen, raw, src)


static func _try_add(out: Array, seen: Dictionary, it: Dictionary, src: String) -> void:
	var uid := int(it.get("uid", 0))
	if uid != 0 and seen.has(uid):
		return
	if src != "hold" and src != "analyzed":
		if Rules.is_starter(App.prog, it) or not Rules.can_forge(App.prog, it):
			return
	if src == "analyzed" and Rules.is_starter(App.prog, it):
		return
	if uid != 0:
		seen[uid] = true
	var row_it: Dictionary = it.duplicate(true)
	if src == "bank":
		row_it["kit_src"] = "bank"
	out.append({"it": row_it, "src": src, "uid": uid})


static func footer(ui: CanvasLayer) -> void:
	_tabs(ui)
	ui.box.add_child(ThemeS.lab("Bank %dg  %d ore  %d root    Carried %dg  %d ore  %d root" % [App.bank_gold, App.bank_ore, App.bank_root, App.gold, App.ore, App.prog.root], 16, Color(0.8, 0.85, 0.7)))
	var smith := App.prog.skill_lv("smith")
	if tab(ui) == "forge":
		_forge_body(ui, smith)
	else:
		_analyze_body(ui, smith)


static func _tabs(ui: CanvasLayer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var on_a := tab(ui) == "analyze"
	var a := ThemeS.btn("Analyze", func(): _set_tab(ui, "analyze"), true)
	var f := ThemeS.btn("Forge", func(): _set_tab(ui, "forge"), true)
	if on_a:
		a.disabled = true
		a.focus_mode = Control.FOCUS_NONE
	else:
		f.disabled = true
		f.focus_mode = Control.FOCUS_NONE
	row.add_child(a)
	row.add_child(f)
	ui.box.add_child(row)


static func _set_tab(ui: CanvasLayer, t: String) -> void:
	ui.anvil_tab = t
	ui.anvil_item = {}
	ui.pending = false
	ui.call_deferred("_rebuild_anvil")
	ui.call_deferred("_show")


static func _analyze_body(ui: CanvasLayer, smith: int) -> void:
	ui.status.text = "Smithing %d. Analyze DESTROYS the piece. Remains wait on Forge. Starters stay off this list." % smith
	var n := App.prog.analyzed.size()
	ui.box.add_child(ThemeS.lab("Remains waiting to forge: %d" % n, 18, Color(0.88, 0.82, 0.7)))
	if n > 0:
		var names: PackedStringArray = PackedStringArray()
		for raw: Variant in App.prog.analyzed:
			if raw is Dictionary:
				names.append(str(raw.get("name", "?")))
		ui.box.add_child(ThemeS.lab(", ".join(names), 16, Color(0.75, 0.85, 0.7)))


static func _forge_body(ui: CanvasLayer, smith: int) -> void:
	if App.prog.analyzed.is_empty() and _no_holds():
		ui.status.text = "Smithing %d. Nothing to forge. Analyze a piece first." % smith
		return
	if ui.anvil_item.is_empty():
		ui.status.text = "Smithing %d. A a slot — pick analyzed remains or a hold to re-forge." % smith
		_hold_lines(ui)
		return
	var it: Dictionary = ui.anvil_item
	var slot := str(it.get("slot", ""))
	var h: Array = App.prog.holds.get(slot, [])
	var first := str(ui.get("anvil_src")) != "hold" and not bool(it.get("hold", false))
	var cost: Dictionary = App.prog.forge_cost(first)
	var wait := App.prog.forge_duration()
	ui.box.add_child(ThemeS.lab("Ready to forge — %s" % str(it.get("name", "?")), 22, Color(0.95, 0.86, 0.55)))
	ui.box.add_child(ThemeS.lab("Slot %s   %s   +%d dmg   +%d def   +%d HP" % [slot, str(it.get("rarity", "white")), int(it.get("dmg", 0)), int(it.get("def", 0)), int(it.get("hp", 0))], 16, Color(0.88, 0.82, 0.7)))
	ui.box.add_child(ThemeS.lab("Smithing %d. Holds %d/3. Wait %.1fs." % [smith, h.size(), wait], 16, Color(0.8, 0.85, 0.7)))
	if first:
		ui.status.text = "First forge from remains: %dg  %d ore  %d root. A again to confirm." % [cost.gold, cost.ore, cost.root]
		ui.focus_btn = ThemeS.btn("Forge remains  (confirm)", func(): ui._confirm(func(): start_forge(ui), "forge"))
	else:
		ui.status.text = "Re-forge hold: %dg  %d ore  %d root. A again to confirm." % [cost.gold, cost.ore, cost.root]
		ui.focus_btn = ThemeS.btn("Re-forge  (confirm)", func(): ui._confirm(func(): start_forge(ui), "forge"))
	ui.box.add_child(ui.focus_btn)
	_hold_lines(ui)


static func _no_holds() -> bool:
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		if not App.prog.holds.get(s, []).is_empty():
			return false
	return true


static func _hold_lines(ui: CanvasLayer) -> void:
	for s: String in ["weapon", "tool", "head", "body", "legs"]:
		var h: Array = App.prog.holds.get(s, [])
		if h.is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		for x: Variant in h:
			if x is Dictionary:
				names.append(str(x.get("name", "?")))
		ui.box.add_child(ThemeS.lab("Holds %s: %s" % [s, ", ".join(names)], 16, Color(0.75, 0.85, 0.7)))


static func analyze(ui: CanvasLayer, _slot: String, row: Dictionary) -> void:
	if tab(ui) == "forge":
		_pick_forge(ui, row)
		return
	var it: Dictionary = row.it.duplicate(true) if row.get("it") is Dictionary else {}
	if it.is_empty() or Rules.is_starter(App.prog, it) or not Rules.can_forge(App.prog, it):
		var Act = load("res://scripts/ui/gear_board_act.gd")
		Act.st(ui, "Can't analyze that.")
		return
	ui.anvil_item = it
	ui.anvil_src = str(row.get("src", ""))
	ui._confirm(func(): _commit_analyze(ui, row), "analyze_%d" % int(row.get("uid", 0)))


static func _commit_analyze(ui: CanvasLayer, row: Dictionary) -> void:
	var taken: Dictionary = Town.analyze_destroy(App.prog, row)
	if taken.is_empty():
		var Act = load("res://scripts/ui/gear_board_act.gd")
		Act.st(ui, "Can't analyze that.")
		ui.anvil_item = {}
		ui.anvil_src = ""
		return
	App.prog.analyzed.append(taken)
	App.save_now()
	ui.anvil_item = {}
	ui.anvil_src = ""
	var Act2 = load("res://scripts/ui/gear_board_act.gd")
	Act2.st(ui, "Destroyed. Remains wait on the Forge tab.")
	App.toast("Analyzed — " + str(taken.get("name", "item")))


static func _pick_forge(ui: CanvasLayer, row: Dictionary) -> void:
	var it: Dictionary = row.it.duplicate(true) if row.get("it") is Dictionary else {}
	if it.is_empty():
		return
	ui.anvil_item = it
	ui.anvil_src = str(row.get("src", ""))
	ui.pending = false
	var Act = load("res://scripts/ui/gear_board_act.gd")
	Act.st(ui, "Selected " + str(it.get("name", "item")) + ".")


static func restore(_ui: CanvasLayer) -> void:
	pass


static func start_forge(ui: CanvasLayer) -> void:
	if ui.forge_t > 0.0:
		return
	var it: Dictionary = ui.anvil_item
	if it.is_empty():
		ui._st("Pick remains on the Forge tab first.")
		return
	var src := str(ui.get("anvil_src"))
	if src != "hold" and src != "analyzed" and not bool(it.get("hold", false)):
		ui._st("Analyze the piece first.")
		return
	if src != "hold" and not bool(it.get("hold", false)) and not Town.has_analyzed(App.prog, int(it.get("uid", 0))):
		ui._st("Those remains are gone.")
		return
	var slot := str(it.get("slot", ""))
	var h: Array = App.prog.holds.get(slot, [])
	var first := src != "hold" and not bool(it.get("hold", false))
	var cost: Dictionary = App.prog.forge_cost(first)
	if not App.prog.can_pay(cost):
		ui._st("Need %dg, %d ore, %d root." % [cost.gold, cost.ore, cost.root])
		App.toast("Not enough gold / ore / root.")
		return
	ui.forge_it = it.duplicate(true)
	ui.forge_it["anvil_src"] = src
	ui.forge_t = App.prog.forge_duration()
	ui._st("Forging… %.1fs. B cancels the wait." % ui.forge_t)
