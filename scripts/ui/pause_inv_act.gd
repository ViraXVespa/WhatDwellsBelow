extends Object

const View := preload("res://scripts/ui/pause_inv_view.gd")


static func act(ui: CanvasLayer, msg: String) -> void:
	ui._st(msg)
	App.save_now()
	ui._rebuild()


static func primary(ui: CanvasLayer) -> void:
	var it: Dictionary = View.selected(ui)
	if it.is_empty():
		return
	if View.can_use_item(it):
		use_item(ui)
		return
	if View.can_equip_item(ui, it):
		equip_item(ui)
		return
	View.refresh_detail(ui)


static func use_item(ui: CanvasLayer) -> void:
	var it: Dictionary = View.selected(ui)
	if not View.can_use_item(it):
		ui._st("Can't use that.")
		return
	var msg: String = ""
	if View.from_bag(ui):
		msg = App.prog.use_from_bag(int(it.uid))
	elif str(it.kind) == "potion":
		msg = App.prog.use_potion()
	else:
		msg = App.prog.use_food()
	act(ui, msg)


static func equip_item(ui: CanvasLayer) -> void:
	var it: Dictionary = View.selected(ui)
	if not View.can_equip_item(ui, it):
		ui._st("Can't equip that.")
		return
	var slot: String = str(it.get("slot", ""))
	var msg: String = App.prog.equip_uid(int(it.uid))
	ui.inv_sel = "slot:" + slot
	act(ui, msg)


static func unequip_item(ui: CanvasLayer) -> void:
	if View.from_bag(ui):
		ui._st("Already in the bag.")
		return
	var slot: String = View.selected_slot(ui)
	if slot == "":
		ui._st("Nothing to unequip.")
		return
	var msg: String = App.prog.unequip_slot(slot)
	if msg.begins_with("Unequipped"):
		var it: Dictionary = {}
		if App.prog.bag.size() > 0:
			var last: Variant = App.prog.bag[App.prog.bag.size() - 1]
			if last is Dictionary:
				it = last
		if not it.is_empty():
			ui.inv_sel = "bag:" + str(int(it.uid))
	act(ui, msg)


static func drop_item(ui: CanvasLayer) -> void:
	if not App.in_dungeon:
		ui._st("Drop on the dungeon floor only.")
		return
	var it: Dictionary = View.selected(ui)
	if it.is_empty():
		ui._st("Nothing to drop.")
		return
	var msg: String = ""
	if View.from_bag(ui):
		msg = App.prog.drop_uid(int(it.uid))
	else:
		msg = App.prog.drop_slot(View.selected_slot(ui))
	ui.inv_sel = "slot:weapon"
	act(ui, msg)
