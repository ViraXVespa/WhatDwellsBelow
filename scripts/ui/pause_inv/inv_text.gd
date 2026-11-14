extends Object

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

static func find_sel(ui: CanvasLayer) -> Control:
	if ui.inv_sel == "":
		return null
	for n: Node in ui.box.find_children("*", "Button", true, false):
		if str(n.get_meta("inv_key", "")) == ui.inv_sel:
			return n as Control
	return null
