extends Object

const Text := preload("res://scripts/ui/gear_board_text.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const Town := preload("res://scripts/data/progress_town.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const View := preload("res://scripts/ui/gear_board_anvil_view.gd")


static func is_anvil(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "anvil"


static func tab(ui: CanvasLayer) -> String:
	var t := str(ui.get("anvil_tab"))
	return t if t == "forge" else "analyze"


static func hint_parts(ui: CanvasLayer) -> Array:
	var parts: Array = []
	if bool(ui.get("gear_sub")):
		if tab(ui) == "forge":
			parts.append({"action": "ui_accept", "verb": "select remains / hold", "gap": true})
		else:
			parts.append({"action": "ui_accept", "verb": "analyze — destroys the piece", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "close list", "gap": true})
		parts.append({"action": "gear_tip", "verb": "tip / forge preview"})
	elif tab(ui) == "forge":
		parts.append({"action": "ui_accept", "verb": "pick remains or a hold", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "back"})
	else:
		parts.append({"action": "ui_accept", "verb": "select a slot", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "back"})
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
	View.footer(ui)


static func cycle_tab(ui: CanvasLayer, dir: int) -> void:
	if dir == 0:
		return
	View.set_tab(ui, "forge" if tab(ui) == "analyze" else "analyze")


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
	ui._st("Forging… %.1fs." % ui.forge_t)
