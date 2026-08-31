extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")

const HOLD_DESTROY := 0.55

static var swallow_until := 0


static func locked_slot(slot: String) -> bool:
	return slot == "weapon" or slot == "tool"


static func swallow_cancel() -> void:
	swallow_until = Time.get_ticks_msec() + 350


static func swallowing() -> bool:
	return Time.get_ticks_msec() < swallow_until


static func town_kit(ui: CanvasLayer) -> bool:
	return Board.is_loadout(ui) or not App.in_dungeon


static func rebuild(ui: CanvasLayer) -> void:
	_unlock_bg(ui)
	if str(ui.get("gear_mode")) == "loadout" and ui.has_method("_rebuild_loadout"):
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


static func _lock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null:
			continue
		c.set_meta("gear_old_focus", c.focus_mode)
		c.focus_mode = Control.FOCUS_NONE


static func _unlock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.has_meta("gear_old_focus"):
			continue
		c.focus_mode = int(c.get_meta("gear_old_focus"))
		c.remove_meta("gear_old_focus")


static func open_sub(ui: CanvasLayer, slot: String) -> void:
	if bool(ui.get("gear_sub")):
		Board.clear_sub(ui)
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	Text.mark_seen(slot)
	_lock_bg(ui)
	var panel := PanelContainer.new()
	panel.name = "gear_sub_panel"
	panel.z_index = 40
	panel.position = Vector2(80, 160)
	panel.custom_minimum_size = Vector2(720, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_NONE
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
		var mark := Text.risk_mark(it, town_kit(ui) or str(row.src) == "bank")
		if mark != "":
			lab += "  [" + mark + "]"
		var key := "opt:%s:%s:%d" % [str(row.src), slot, int(row.uid)]
		var pick_row: Dictionary = row.duplicate(true)
		pick_row.it = it.duplicate(true)
		var b := Button.new()
		b.text = lab
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = false
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Text.item_color(it))
		b.set_meta("inv_key", key)
		Board._watch_hover(ui, b, key)
		b.pressed.connect(func(): pick(ui, slot, pick_row))
		b.focus_entered.connect(func():
			ui.inv_sel = key
			Board.refresh(ui)
		)
		box.add_child(b)
		if first == null:
			first = b
	var back := Button.new()
	back.text = "Back  (B)"
	back.custom_minimum_size = Vector2(0, 40)
	back.focus_mode = Control.FOCUS_ALL
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): close_sub(ui))
	box.add_child(back)
	if first == null:
		first = back
	ui.inv_sel = str(first.get_meta("inv_key", "slot:" + slot))
	ui.focus_btn = first
	first.grab_focus()
	Board.refresh(ui)
	var tree := ui.get_tree()
	if tree:
		tree.process_frame.connect(func():
			if is_instance_valid(ui):
				Board.place_tip(ui)
		, CONNECT_ONE_SHOT)


static func close_sub(ui: CanvasLayer) -> void:
	var keep := str(ui.gear_sub_slot)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	_unlock_bg(ui)
	swallow_cancel()
	App.sfx("ui_cancel")
	_after_sub(ui, "slot:" + (keep if keep != "" else "weapon"), false)


static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	if not bool(ui.get("gear_sub")):
		return
	var it: Dictionary = {}
	if row.get("it") is Dictionary:
		it = (row.it as Dictionary).duplicate(true)
	var src := str(row.get("src", ""))
	if src == "equipped":
		_unequip_or_keep(ui, slot, it)
	elif town_kit(ui):
		_apply_loadout(ui, slot, it, src)
	else:
		_apply_inv(ui, slot, it, src)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	_unlock_bg(ui)
	swallow_cancel()
	_after_sub(ui, "slot:" + slot, true)


static func _after_sub(ui: CanvasLayer, sel: String, do_rebuild: bool) -> void:
	ui.inv_sel = sel
	var tree := ui.get_tree()
	if tree == null:
		Board.clear_sub(ui)
		if do_rebuild:
			rebuild(ui)
		else:
			Board.refresh(ui)
		return
	tree.process_frame.connect(func():
		if not is_instance_valid(ui):
			return
		Board.clear_sub(ui)
		if do_rebuild:
			rebuild(ui)
		else:
			ui.call_deferred("_focus")
			Board.refresh(ui)
	, CONNECT_ONE_SHOT)


static func _unequip_or_keep(ui: CanvasLayer, slot: String, it: Dictionary) -> void:
	if locked_slot(slot):
		st(ui, "Weapon and tool stay equipped.")
		return
	if Rules.is_starter(App.prog, it) or str(it.get("kit_src", "")) == "starter":
		st(ui, "Starters stay on the slot.")
		return
	if town_kit(ui):
		App.prog.slots[slot] = {}
		App.prog.hold_pick[slot] = -1
		st(ui, "Unequipped.")
		App.save_now()
		return
	st(ui, App.prog.unequip_slot(slot))


static func _apply_loadout(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	if it.is_empty():
		st(ui, "Nothing to equip.")
		return
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
		if ui.get("loadout_wpn") != null:
			ui.loadout_wpn = str(it.get("weapon", ui.loadout_wpn))
		App.prog.pick_weapon = str(it.get("weapon", App.prog.pick_weapon))
		App.weapon = App.prog.pick_weapon
	if slot == "tool":
		if ui.get("loadout_tool") != null:
			ui.loadout_tool = str(it.get("tool", ui.loadout_tool))
		App.prog.tool_type = str(it.get("tool", App.prog.tool_type))
	st(ui, "Ready: " + str(it.get("name", slot)))
	App.save_now()


static func _apply_inv(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	if src == "bag":
		st(ui, App.prog.equip_uid(int(it.get("uid", 0))))
		ui.inv_sel = "slot:" + slot
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
	ui.inv_sel = "slot:" + (slot if slot != "" else "weapon")
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
