extends Object

const Board := preload("res://scripts/ui/gear_board.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Fmt := preload("res://scripts/ui/gear_board_text_fmt.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Rules := preload("res://scripts/data/gear_rules.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const ForgeUI := preload("res://scripts/ui/gear_board_anvil_forge.gd")

static func open_sub(ui: CanvasLayer, slot: String) -> void:
	Board.clear_sub(ui)
	ui.gear_sub = true
	ui.gear_sub_slot = slot
	Text.mark_seen(slot)
	load("res://scripts/ui/gear_board_sub.gd").lock_bg(ui)
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
	var blurb := "AT RISK gear is lost on death or Dispel."
	var blurb_col := Color(0.8, 0.74, 0.64)
	if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui):
		if str(ui.get("anvil_tab")) == "forge":
			head = "Forge  " + str(Fmt.NAMES.get(slot, slot))
			blurb = "Set type, rarity, level, and locks."
		else:
			head = "Analyze  " + str(Fmt.NAMES.get(slot, slot))
			blurb = "WARNING: Analyzing DESTROYS the selected item. This cannot be undone."
			blurb_col = Color(0.95, 0.42, 0.28)
	box.add_child(ThemeS.lab(head, 22, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab(blurb, 16, blurb_col))
	if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui) and str(ui.get("anvil_tab")) == "forge":
		load("res://scripts/ui/gear_board_sub.gd")._open_forge(ui, box, slot)
		return
	var first: Button = null
	var rows: Array
	if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui):
		rows = load("res://scripts/ui/gear_board_sub.gd")._anvil().options_for(slot, ui)
	else:
		rows = Text.options_for(slot)
	if rows.is_empty():
		if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui):
			box.add_child(ThemeS.lab("No AT RISK pieces for this slot.", 18, Color(0.78, 0.74, 0.66)))
		else:
			box.add_child(ThemeS.lab("Nothing else for this slot.", 18, Color(0.78, 0.74, 0.66)))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	box.add_child(grid)
	var opts: Array[Button] = []
	for row: Dictionary in rows:
		var it: Dictionary = row.it
		var key := "opt:%s:%s:%d" % [str(row.src), slot, int(row.uid)]
		var pick_row: Dictionary = row.duplicate(true)
		pick_row.it = it.duplicate(true)
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_ALL
		b.icon = Icons.tex_for_item(it)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		load("res://scripts/ui/gear_board_sub.gd")._paint_opt(b, it)
		b.set_meta("inv_key", key)
		b.set_meta("inv_it", it.duplicate(true))
		Board._watch_hover(ui, b, key)
		b.pressed.connect(func(): pick(ui, slot, pick_row))
		grid.add_child(b)
		opts.append(b)
		if first == null:
			first = b
	if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui):
		load("res://scripts/ui/gear_board_sub.gd")._add_strip(box, [
			{"action": "ui_accept", "verb": "analyze", "gap": true},
			{"action": "ui_cancel", "verb": "close", "gap": true},
		])
		if first == null:
			ui.focus_btn = null
			return
		ui.inv_sel = str(first.get_meta("inv_key", "slot:" + slot))
		ui.focus_btn = first
		first.grab_focus()
		Board.refresh(ui)
		return
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 40)
	back.focus_mode = Control.FOCUS_ALL
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): load("res://scripts/ui/gear_board_sub.gd").close_sub(ui))
	back.focus_entered.connect(func():
		ui.inv_sel = "back"
		Board._flag(ui, "gear_tip_ready", false)
		Board._flag(ui, "gear_hover", false)
		Board.hide_tip(ui)
	)
	for b: Button in opts:
		b.focus_entered.connect(func():
			ui.inv_sel = str(b.get_meta("inv_key", ""))
			Board._arm_tip(ui)
			Board.refresh(ui)
		)
	box.add_child(back)
	_wire_opt_focus(opts, back)
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



static func _wire_opt_focus(opts: Array[Button], back: Button) -> void:
	var n: int = opts.size()
	for i: int in n:
		var b: Button = opts[i]
		if i + 1 < n:
			b.focus_neighbor_right = opts[i + 1].get_path()
			opts[i + 1].focus_neighbor_left = b.get_path()
			b.focus_next = opts[i + 1].get_path()
		else:
			b.focus_neighbor_right = back.get_path()
			b.focus_next = back.get_path()
		if i > 0:
			b.focus_previous = opts[i - 1].get_path()
		b.focus_neighbor_bottom = back.get_path()
	if n > 0:
		back.focus_neighbor_top = opts[0].get_path()
		back.focus_neighbor_left = opts[n - 1].get_path()
		back.focus_previous = opts[n - 1].get_path()



static func pick(ui: CanvasLayer, slot: String, row: Dictionary) -> void:
	var Act = load("res://scripts/ui/gear_board_sub.gd")._act()
	if not bool(ui.get("gear_sub")):
		return
	if load("res://scripts/ui/gear_board_sub.gd")._is_anvil(ui):
		load("res://scripts/ui/gear_board_sub.gd")._anvil().analyze(ui, slot, row)
		load("res://scripts/ui/gear_board_sub.gd").close_sub(ui)
		return
	var it: Dictionary = {}
	if row.get("it") is Dictionary:
		it = (row.it as Dictionary).duplicate(true)
	var src := str(row.get("src", ""))
	if src == "equipped":
		load("res://scripts/ui/gear_board_sub.gd")._unequip_or_keep(ui, slot, it)
	elif Act.town_kit(ui):
		_apply_loadout(ui, slot, it, src)
	else:
		load("res://scripts/ui/gear_board_sub.gd")._apply_inv(ui, slot, it, src)
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	load("res://scripts/ui/gear_board_sub.gd").unlock_bg(ui)
	Board.clear_sub(ui)
	Act.swallow_cancel()
	load("res://scripts/ui/gear_board_sub.gd")._after_sub(ui, "slot:" + slot, true)



static func _apply_loadout(ui: CanvasLayer, slot: String, it: Dictionary, src: String) -> void:
	var Act = load("res://scripts/ui/gear_board_sub.gd")._act()
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



