extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Fmt := preload("res://scripts/ui/gear_board_text_fmt.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")


static func _act():
	return load("res://scripts/ui/gear_board_act.gd")


static func _anvil():
	return load("res://scripts/ui/gear_board_anvil.gd")


static func _is_anvil(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "anvil"


static func lock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null:
			continue
		c.set_meta("gear_old_focus", c.focus_mode)
		c.focus_mode = Control.FOCUS_NONE


static func unlock_bg(ui: CanvasLayer) -> void:
	if ui.box == null:
		return
	for n: Node in ui.box.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.has_meta("gear_old_focus"):
			continue
		c.focus_mode = int(c.get_meta("gear_old_focus"))
		c.remove_meta("gear_old_focus")


static func open_sub(ui: CanvasLayer, slot: String) -> void:
	var Act = _act()
	if bool(ui.get("gear_sub")):
		Board.clear_sub(ui)
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	Text.mark_seen(slot)
	lock_bg(ui)
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
	var head := "Re-equip  " + str(Fmt.NAMES.get(slot, slot))
	var blurb := "A picks it. B closes. AT RISK gear is lost on death or Dispel."
	if _is_anvil(ui):
		if str(ui.get("anvil_tab")) == "forge":
			head = "Forge  " + str(Fmt.NAMES.get(slot, slot))
			blurb = "A selects analyzed remains or a hold. B closes."
		else:
			head = "Analyze  " + str(Fmt.NAMES.get(slot, slot))
			blurb = "A DESTROYS the piece. Remains wait on the Forge tab. B closes."
	box.add_child(ThemeS.lab(head, 22, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab(blurb, 16, Color(0.8, 0.74, 0.64)))
	var first: Button = null
	var rows: Array
	if _is_anvil(ui):
		rows = _anvil().options_for(slot, ui)
	else:
		rows = Text.options_for(slot)
	if rows.is_empty():
		if _is_anvil(ui) and str(ui.get("anvil_tab")) == "forge":
			box.add_child(ThemeS.lab("No remains or holds for this slot.", 18, Color(0.78, 0.74, 0.66)))
		elif _is_anvil(ui):
			box.add_child(ThemeS.lab("Nothing forgeable here. Starters stay off this list.", 18, Color(0.78, 0.74, 0.66)))
		else:
			box.add_child(ThemeS.lab("Nothing else for this slot.", 18, Color(0.78, 0.74, 0.66)))
	for row: Dictionary in rows:
		var it: Dictionary = row.it
		var lab := "%s  ·  %s" % [str(row.src), Text.item_short(it)]
		var mark := Fmt.risk_mark(it, Act.town_kit(ui) or str(row.src) == "bank")
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
		b.add_theme_color_override("font_color", Fmt.item_color(it))
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
	var Act = _act()
	var keep := str(ui.gear_sub_slot)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	unlock_bg(ui)
	Act.swallow_cancel()
	App.sfx("ui_cancel")
	_after_sub(ui, "slot:" + (keep if keep != "" else "weapon"), false)


static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	var Act = _act()
	if not bool(ui.get("gear_sub")):
		return
	if _is_anvil(ui):
		_anvil().analyze(ui, slot, row)
		ui.gear_sub = false
		ui.gear_sub_slot = ""
		unlock_bg(ui)
		Act.swallow_cancel()
		_after_sub(ui, "slot:" + slot, true)
		return
	var it: Dictionary = {}
	if row.get("it") is Dictionary:
		it = (row.it as Dictionary).duplicate(true)
	var src := str(row.get("src", ""))
	if src == "equipped":
		_unequip_or_keep(ui, slot, it)
	elif Act.town_kit(ui):
		_apply_loadout(ui, slot, it, src)
	else:
		_apply_inv(ui, slot, it, src)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	unlock_bg(ui)
	Act.swallow_cancel()
	_after_sub(ui, "slot:" + slot, true)


static func _after_sub(ui: CanvasLayer, sel: String, do_rebuild: bool) -> void:
	var Act = _act()
	ui.inv_sel = sel
	var tree := ui.get_tree()
	if tree == null:
		Board.clear_sub(ui)
		if do_rebuild:
			Act.rebuild(ui)
		else:
			Board.refresh(ui)
		return
	tree.process_frame.connect(func():
		if not is_instance_valid(ui):
			return
		Board.clear_sub(ui)
		if do_rebuild:
			Act.rebuild(ui)
		else:
			ui.call_deferred("_focus")
			Board.refresh(ui)
	, CONNECT_ONE_SHOT)


static func _unequip_or_keep(ui: CanvasLayer, slot: String, it: Dictionary) -> void:
	var Act = _act()
	if Act.locked_slot(slot):
		Act.st(ui, "Weapon and tool stay equipped.")
		return
	if Rules.is_starter(App.prog, it) or str(it.get("kit_src", "")) == "starter":
		Act.st(ui, "Starters stay on the slot.")
		return
	if Act.town_kit(ui):
		App.prog.slots[slot] = {}
		App.prog.hold_pick[slot] = -1
		Act.st(ui, "Unequipped.")
		App.save_now()
		return
	Act.st(ui, App.prog.unequip_slot(slot))


static func _apply_loadout(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	var Act = _act()
	if it.is_empty():
		Act.st(ui, "Nothing to equip.")
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
	Act.st(ui, "Ready: " + str(it.get("name", slot)))
	App.save_now()


static func _apply_inv(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	var Act = _act()
	if src == "bag":
		Act.st(ui, App.prog.equip_uid(int(it.get("uid", 0))))
		ui.inv_sel = "slot:" + slot
		return
	Act.st(ui, "Can't use that here.")
