extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Sub := preload("res://scripts/ui/gear_board_sub.gd")

const HOLD_DESTROY := 0.55

static var swallow_until := 0


static func locked_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "tool"


static func swallow_cancel() -> void:
	swallow_until = Time.get_ticks_msec() + 350


static func swallowing() -> bool:
	return Time.get_ticks_msec() < swallow_until


static func town_kit(ui: CanvasLayer) -> bool:
	if str(ui.get("gear_mode")) == "anvil":
		return false
	return Board.is_loadout(ui) or not App.in_dungeon


static func rebuild(ui: CanvasLayer) -> void:
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


static func st(ui: CanvasLayer, msg: String) -> void:
	if ui.has_method("_st"):
		ui._st(msg)
	elif ui.status:
		ui.status.text = msg
	App.sfx("ui")


static func open_sub(ui: CanvasLayer, slot: String) -> void:
	Sub.open_sub(ui, slot)


static func close_sub(ui: CanvasLayer) -> void:
	Sub.close_sub(ui)


static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	Sub.pick(ui, slot, row)


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


static func cycle_tip(ui: CanvasLayer) -> void:
	ui.gear_tip_mode = (int(ui.gear_tip_mode) + 1) % 3
	Board.refresh(ui)
	App.sfx("ui")


static func cycle_stats(ui: CanvasLayer, d: int) -> void:
	if bool(ui.get("gear_sub")):
		return
	var pages := Text.page_ids(ui)
	ui.gear_stat_page = posmod(int(ui.gear_stat_page) + d, pages.size())
	Board.refresh(ui)
	App.sfx("ui")


static func toggle_char(ui: CanvasLayer) -> void:
	App.set_character("female" if App.character_type == "male" else "male")
	App.save_now()
	rebuild(ui)


static func floor_step(ui: CanvasLayer, d: int) -> void:
	ui.loadout_floor = clampi(int(ui.loadout_floor) + d, 1, App.prog.deepest)
	Board.refresh(ui)


static func enter(ui: CanvasLayer) -> void:
	App.prog.tool_type = str(ui.loadout_tool)
	App.prog.pick_weapon = str(ui.loadout_wpn)
	App.prog.start_floor = int(ui.loadout_floor)
	App.weapon = str(ui.loadout_wpn)
	Board.pending_kit.clear()
	for s: String in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		if it is Dictionary and not it.is_empty():
			Board.pending_kit[s] = it.duplicate(true)
	ui.close_ui()
	App.enter_dungeon()


static func tick_x(ui: CanvasLayer, delta: float) -> void:
	if str(ui.get("gear_mode")) == "anvil":
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false
		return
	if not bool(ui.get("open")):
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false
		return
	var down := Input.is_physical_key_pressed(KEY_X) or _joy_down(JOY_BUTTON_X)
	if down:
		ui.gear_x_hold = float(ui.gear_x_hold) + delta
		if float(ui.gear_x_hold) >= HOLD_DESTROY and not bool(ui.gear_x_fired):
			ui.gear_x_fired = true
			destroy(ui)
	else:
		if float(ui.gear_x_hold) > 0.05 and float(ui.gear_x_hold) < HOLD_DESTROY and not bool(ui.gear_x_fired):
			drop(ui)
		ui.gear_x_hold = 0.0
		ui.gear_x_fired = false


static func _joy_down(btn: int) -> bool:
	for id: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(id, btn):
			return true
	return false


static func handle_event(ui: CanvasLayer, event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if swallowing() and _is_cancel(event):
		return true
	if bool(ui.get("gear_sub")):
		if _is_y(event):
			cycle_tip(ui)
			return true
		if _is_cancel(event):
			close_sub(ui)
			return true
		if _page_prev(event) or _page_next(event) or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("tab_left") or event.is_action_pressed("tab_right"):
			return true
		return false
	if _is_y(event):
		cycle_tip(ui)
		return true
	if _page_prev(event):
		cycle_stats(ui, -1)
		return true
	if _page_next(event):
		cycle_stats(ui, 1)
		return true
	if event.is_action_pressed("ui_left") and str(ui.inv_sel) == "stats":
		cycle_stats(ui, -1)
		return true
	if event.is_action_pressed("ui_right") and str(ui.inv_sel) == "stats":
		cycle_stats(ui, 1)
		return true
	return false


static func _is_cancel(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false


static func _page_prev(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventMouseButton:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_Q or k.keycode == KEY_Q
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER
	return false


static func _page_next(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventMouseButton:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_E or k.keycode == KEY_E
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	return false


static func _is_y(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_Y or k.keycode == KEY_Y
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false
