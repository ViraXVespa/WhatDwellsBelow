extends Object

const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const Town := preload("res://scripts/data/progress_town.gd")
const ForgeP := preload("res://scripts/data/progress_forge.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const View := preload("res://scripts/ui/gear_board/gear_board_anvil_view.gd")
const ForgeUI := preload("res://scripts/ui/gear_board/gear_board_anvil_forge.gd")


static func is_anvil(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "anvil"


static func tab(ui: CanvasLayer) -> String:
	var t := str(ui.get("anvil_tab"))
	return t if t == "forge" else "analyze"


static func hint_parts(ui: CanvasLayer) -> Array:
	var parts: Array = []
	if bool(ui.get("gear_sub")):
		if tab(ui) == "forge":
			return ForgeUI.hint_parts(ui)
		parts.append({"action": "ui_accept", "verb": "analyze — destroys the piece", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "close list"})
		return parts
	if tab(ui) == "forge":
		parts.append({"action": "ui_accept", "verb": "open forge setup", "gap": true})
		parts.append({"action": "ui_cancel", "verb": "back"})
		return parts
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
		return []
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


static func _add_src(out: Array, seen: Dictionary, slot: String, arr: Array, src: String) -> void:
	for raw: Variant in arr:
		if raw is Dictionary and str(raw.get("slot", "")) == slot:
			_try_add(out, seen, raw, src)


static func _try_add(out: Array, seen: Dictionary, it: Dictionary, src: String) -> void:
	var uid := int(it.get("uid", 0))
	if uid != 0 and seen.has(uid):
		return
	if not ForgeP.can_analyze(App.prog, it):
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


static func analyze(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	if tab(ui) == "forge":
		return
	var it: Dictionary = row.it.duplicate(true) if row.get("it") is Dictionary else {}
	if it.is_empty() or not ForgeP.can_analyze(App.prog, it):
		var Act = load("res://scripts/ui/gear_board/gear_board_act.gd")
		Act.st(ui, "Can't analyze that.")
		return
	ui.anvil_item = it
	ui.anvil_src = str(row.get("src", ""))
	_commit_analyze(ui, slot, row)


static func _commit_analyze(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	var taken: Dictionary = Town.analyze_destroy(App.prog, row)
	if taken.is_empty():
		var Act = load("res://scripts/ui/gear_board/gear_board_act.gd")
		Act.st(ui, "Can't analyze that.")
		ui.anvil_item = {}
		ui.anvil_src = ""
		return
	ui.anvil_item = {}
	ui.anvil_src = ""
	var Act2 = load("res://scripts/ui/gear_board/gear_board_act.gd")
	Act2.st(ui, "Analyzed. Unlocks ready on the Forge tab.")
	App.toast("Analyzed — " + str(taken.get("name", "item")))
	var Sub = load("res://scripts/ui/gear_board/gear_board_sub.gd")
	if bool(ui.get("gear_sub")):
		Sub.open_sub(ui, slot)


static func restore(_ui: CanvasLayer) -> void:
	pass


static func start_forge(ui: CanvasLayer) -> void:
	ForgeUI.start(ui)
