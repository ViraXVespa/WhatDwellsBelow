extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

const HOLD_DESTROY := 0.55


static func locked_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "tool"


static func rebuild(ui: CanvasLayer) -> void:
	if str(ui.get("gear_mode")) == "loadout" and ui.has_method("_rebuild_loadout"):
		ui._rebuild_loadout()
		ui._show()
	elif ui.has_method("_rebuild"):
		ui._rebuild()
	ui.call_deferred("_focus")


static func st(ui: CanvasLayer, msg: String) -> void:
	if ui.has_method("_st"):
		ui._st(msg)
	elif ui.status:
		ui.status.text = msg
	App.sfx("ui")


static func open_sub(ui: CanvasLayer, slot: String) -> void:
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	Text.mark_seen(slot)
	Board.clear_sub(ui)
	var panel := PanelContainer.new()
	panel.name = "gear_sub_panel"
	panel.z_index = 30
	panel.position = Vector2(80, 160)
	panel.custom_minimum_size = Vector2(720, 520)
	panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.08, 0.06, 0.05, 0.98), Color(0.9, 0.72, 0.32)))
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(ThemeS.lab("Re-equip  " + str(Text.NAMES.get(slot, slot)), 22, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab("A picks it. B closes. AT RISK gear is lost on death or Dispel.", 16, Color(0.8, 0.74, 0.64)))
	var first: Button = null
	var rows: Array = Text.options_for(slot)
	if rows.is_empty():
		box.add_child(ThemeS.lab("Nothing else for this slot.", 18, Color(0.78, 0.74, 0.66)))
	for row: Dictionary in rows:
		var it: Dictionary = row.it
		var lab := "%s  ·  %s" % [str(row.src), Text.item_short(it)]
		var mark := Text.risk_mark(it, Board.is_loadout(ui) or str(row.src) == "bank")
		if mark != "":
			lab += "  [" + mark + "]"
		var key := "opt:%s:%s:%d" % [str(row.src), slot, int(row.uid)]
		var pick_row: Dictionary = row
		var b: Button = ThemeS.btn(lab, func(): pick(ui, slot, pick_row))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("inv_key", key)
		b.add_theme_color_override("font_color", Text.item_color(it))
		b.focus_entered.connect(func():
			ui.inv_sel = key
			Board.refresh(ui)
		)
		box.add_child(b)
		if first == null:
			first = b
	var back: Button = ThemeS.btn("Back  (B)", func(): close_sub(ui))
	box.add_child(back)
	if first == null:
		first = back
	ui.inv_sel = str(first.get_meta("inv_key", "slot:" + slot))
	ui.focus_btn = first
	ui.call_deferred("_focus")
	Board.refresh(ui)


static func close_sub(ui: CanvasLayer) -> void:
	var keep := str(ui.gear_sub_slot)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	Board.clear_sub(ui)
	ui.inv_sel = "slot:" + (keep if keep != "" else "weapon")
	App.sfx("ui_cancel")
	ui.call_deferred("_focus")
	Board.refresh(ui)


static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	var it: Dictionary = (row.it as Dictionary).duplicate(true)
	var src := str(row.src)
	if Board.is_loadout(ui):
		_apply_loadout(ui, slot, it, src)
	else:
		_apply_inv(ui, slot, it, src)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	Board.clear_sub(ui)
	ui.inv_sel = "slot:" + slot
	rebuild(ui)


static func _apply_loadout(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	it["kit_src"] = src
	App.prog.slots[slot] = it
	if src == "hold":
		var h: Array = App.prog.holds[slot]
		var found := -1
		for i: int in h.size():
			if int(h[i].uid) == int(it.uid):
				found = i
				break
		App.prog.hold_pick[slot] = found
	else:
		App.prog.hold_pick[slot] = -1
	if slot == "weapon":
		ui.loadout_wpn = str(it.get("weapon", ui.loadout_wpn))
		App.prog.pick_weapon = ui.loadout_wpn
		App.weapon = ui.loadout_wpn
	if slot == "tool":
		ui.loadout_tool = str(it.get("tool", ui.loadout_tool))
		App.prog.tool_type = ui.loadout_tool
	st(ui, "Ready: " + str(it.get("name", slot)))
	App.save_now()


static func _apply_inv(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	if src == "bag":
		st(ui, App.prog.equip_uid(int(it.uid)))
		ui.inv_sel = "slot:" + slot
		return
	if src == "equipped":
		st(ui, "Already on.")
		return
	st(ui, "Can't use that here.")


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
	ui.inv_sel = "slot:weapon" if locked_slot(slot) else "slot:" + (slot if slot != "" else "weapon")
	st(ui, msg)
	rebuild(ui)


static func destroy(ui: CanvasLayer) -> void:
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
	ui.gear_tip_mode = 1 - int(ui.gear_tip_mode)
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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		if bool(ui.gear_sub):
			close_sub(ui)
			return true
	return false


static func _page_prev(event: InputEvent) -> bool:
	if event.is_action_pressed("special"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_Q or k.keycode == KEY_Q
	return false


static func _page_next(event: InputEvent) -> bool:
	if event.is_action_pressed("attack"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_E or k.keycode == KEY_E
	return false


static func _is_y(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		return k.physical_keycode == KEY_Y or k.keycode == KEY_Y
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false
