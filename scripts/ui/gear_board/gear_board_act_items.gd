extends Object

## Gear board bag primary / drop / destroy.

const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")


static func locked_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "tool"


static func st(ui: CanvasLayer, msg: String) -> void:
	if ui.has_method("_st"):
		ui._st(msg)
	elif ui.status:
		ui.status.text = msg
	App.sfx("ui")


static func rebuild(ui: CanvasLayer) -> void:
	var Sub := load("res://scripts/ui/gear_board/gear_board_sub.gd")
	Sub.unlock_bg(ui)
	if str(ui.get("gear_mode")) == "anvil" and ui.has_method("_rebuild_anvil"):
		ui._rebuild_anvil()
		ui._show()
	elif str(ui.get("gear_mode")) == "loadout" and ui.has_method("_rebuild_loadout"):
		ui._rebuild_loadout()
		ui._show()
	elif ui.has_method("_rebuild"):
		ui._rebuild()
	elif ui.has_method("_rebuild_inv"):
		ui._rebuild_inv()
		ui._show()
	ui.call_deferred("_focus")


static func bag_primary(ui: CanvasLayer) -> void:
	var it := Text.selected(ui)
	if it.is_empty():
		return
	var slot := str(it.get("slot", ""))
	var k := str(it.get("kind", ""))
	if k == "food":
		st(ui, App.prog.use_from_bag(int(it.uid)))
		ui.inv_sel = "slot:food"
		rebuild(ui)
		return
	if App.prog.SLOTS.find(slot) >= 0:
		st(ui, App.prog.equip_uid(int(it.uid)))
		ui.inv_sel = "slot:" + slot
		rebuild(ui)

static func drop(ui: CanvasLayer) -> void:
	if str(ui.get("gear_mode")) == "anvil":
		st(ui, "Use Analyze to destroy a piece.")
		return
	if not App.in_dungeon:
		st(ui, "Drop on the dungeon floor only.")
		return
	var it := Text.selected(ui)
	if it.is_empty():
		st(ui, "Nothing to drop.")
		return
	var sel := str(ui.inv_sel)
	var slot := Text.selected_slot(ui)
	if sel.begins_with("slot:") and locked_slot(slot):
		st(ui, "Weapon and tool stay equipped.")
		return
	var msg := ""
	if sel.begins_with("bag:"):
		msg = App.prog.drop_uid(int(it.uid))
	elif sel.begins_with("slot:"):
		msg = App.prog.drop_slot(slot)
	else:
		st(ui, "Pick a slot or bag item first.")
		return
	ui.inv_sel = "slot:" + (slot if slot != "" else "weapon")
	st(ui, msg)
	rebuild(ui)

static func destroy(ui: CanvasLayer) -> void:
	if str(ui.get("gear_mode")) == "anvil":
		st(ui, "Use Analyze to destroy a piece.")
		return
	var sel := str(ui.inv_sel)
	var it := Text.selected(ui)
	var slot := Text.selected_slot(ui)
	if sel.begins_with("slot:") and locked_slot(slot):
		st(ui, "Weapon and tool stay equipped.")
		return
	if sel.begins_with("opt:") and locked_slot(slot) and str(sel.split(":")[1] if sel.split(":").size() > 1 else "") == "equipped":
		st(ui, "Weapon and tool stay equipped.")
		return
	if it.is_empty() and not sel.begins_with("slot:"):
		st(ui, "Nothing to destroy.")
		return
	if sel.begins_with("bag:"):
		App.prog.remove_uid(int(it.uid))
	elif sel.begins_with("slot:"):
		App.prog.take_slot(slot)
	elif sel.begins_with("opt:"):
		var src := sel.split(":")[1] if sel.split(":").size() > 1 else ""
		if src == "bank":
			App.prog.drop_stash(int(it.uid))
		elif src == "hold" and slot != "":
			var h: Array = App.prog.holds[slot]
			for i: int in range(h.size() - 1, -1, -1):
				if int(h[i].uid) == int(it.uid):
					h.remove_at(i)
			App.prog.holds[slot] = h
		elif src == "bag":
			App.prog.remove_uid(int(it.uid))
		elif src == "starter":
			st(ui, "Starters aren't stored.")
			return
		else:
			st(ui, "Can't destroy that.")
			return
	else:
		st(ui, "Can't destroy that.")
		return
	st(ui, "Destroyed.")
	App.save_now()
	ui.inv_sel = "slot:" + (slot if slot != "" else "weapon")
	rebuild(ui)
