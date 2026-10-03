extends Object
const Fmt := preload("res://scripts/ui/gear_board/text_fmt.gd")

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

static func from_bag(ui: CanvasLayer) -> bool:
	return ui.inv_sel.begins_with("bag:")

static func find_sel(ui: CanvasLayer) -> Control:
	if ui.inv_sel == "":
		return null
	for n: Node in ui.box.find_children("*", "Button", true, false):
		if str(n.get_meta("inv_key", "")) == ui.inv_sel:
			return n as Control
	return null

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
