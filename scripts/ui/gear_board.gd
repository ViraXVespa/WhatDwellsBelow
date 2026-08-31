extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Act := preload("res://scripts/ui/gear_board_act.gd")

static var pending_kit: Dictionary = {}


static func ensure_host(ui: CanvasLayer) -> void:
	if ui.get("gear_stat_page") == null:
		ui.set("gear_stat_page", 0)
	if ui.get("gear_tip_mode") == null:
		ui.set("gear_tip_mode", 0)
	if ui.get("gear_sub") == null:
		ui.set("gear_sub", false)
	if ui.get("gear_sub_slot") == null:
		ui.set("gear_sub_slot", "")
	if ui.get("gear_x_hold") == null:
		ui.set("gear_x_hold", 0.0)
	if ui.get("gear_x_fired") == null:
		ui.set("gear_x_fired", false)
	if ui.get("inv_sel") == null:
		ui.set("inv_sel", "slot:weapon")
	if str(ui.inv_sel) == "":
		ui.inv_sel = "slot:weapon"


static func is_loadout(ui: CanvasLayer) -> bool:
	return str(ui.get("gear_mode")) == "loadout"


static func build(ui: CanvasLayer, mode: String) -> void:
	ensure_host(ui)
	ui.gear_mode = mode
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	ui.gear_x_hold = 0.0
	ui.gear_x_fired = false
	clear_sub(ui)
	var title := "Inventory"
	var title_col := Color(0.95, 0.82, 0.5)
	if mode == "loadout":
		title = "Floor Crystal — Loadout"
		title_col = Color(0.6, 0.9, 1.0)
	ui.box.add_child(ThemeS.lab(title, 28, title_col))
	if mode == "loadout":
		ui.box.add_child(ThemeS.lab("Choose holds or stash gear. Confirm enter twice. Only floors you have reached.", 16, Color(0.82, 0.76, 0.66)))
		ui.status = ThemeS.lab("Weapon %s   Tool %s   Floor %d / deepest %d" % [str(ui.loadout_wpn), str(ui.loadout_tool), int(ui.loadout_floor), App.prog.deepest], 20, Color(0.95, 0.8, 0.45))
		ui.box.add_child(ui.status)
	else:
		ui.box.add_child(ThemeS.lab("Carried  %dg   %d ore   %d wood   bag %d/%d" % [App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)], 18, Color(0.95, 0.8, 0.45)))
		ui.status = ThemeS.lab("", 16, Color(0.78, 0.74, 0.66))
		ui.box.add_child(ui.status)
	ui.gear_hint = ThemeS.lab(Text.hint_line(ui), 16, Color(0.72, 0.68, 0.6))
	ui.box.add_child(ui.gear_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.box.add_child(row)
	row.add_child(_slot_col(ui, ["weapon", "potion"], true))
	row.add_child(_slot_col(ui, ["head", "body", "legs"], false))
	row.add_child(_slot_col(ui, ["tool", "food"], true))
	row.add_child(stats_card(ui))
	if ui.focus_btn == null:
		var hit := find_sel(ui)
		if hit:
			ui.focus_btn = hit
	ui.gear_tip = ThemeS.lab("", 18, Color(0.93, 0.86, 0.72))
	ui.gear_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.gear_tip.custom_minimum_size = Vector2(900, 96)
	ui.box.add_child(ui.gear_tip)
	if mode == "loadout":
		loadout_footer(ui)
	else:
		bag_grid(ui)
	ui.box.add_child(ThemeS.btn("Close  (B)", ui.close_ui))
	refresh(ui)


static func _slot_col(ui: CanvasLayer, slots: Array, mid: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER if mid else BoxContainer.ALIGNMENT_BEGIN
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for key: Variant in slots:
		var b: Button = slot_btn(ui, str(key))
		col.add_child(b)
		if ui.focus_btn == null and str(key) == "weapon":
			ui.focus_btn = b
	return col


static func slot_btn(ui: CanvasLayer, slot: String) -> Button:
	var it: Dictionary = App.prog.slots.get(slot, {})
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Text.item_color(it))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.4, 0.3, 0.18)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.26, 0.2, 0.13), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.14, 0.11, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.text = Text.slot_face(ui, slot, it)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("inv_key", "slot:" + slot)
	b.pressed.connect(func():
		ui.inv_sel = "slot:" + slot
		refresh(ui)
		Act.open_sub(ui, slot)
	)
	b.focus_entered.connect(func():
		ui.inv_sel = "slot:" + slot
		refresh(ui)
	)
	return b


static func stats_card(ui: CanvasLayer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.12, 0.1, 0.08), Color(0.45, 0.34, 0.18)))
	panel.set_meta("inv_key", "stats")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var left := ThemeS.lab("Q  ·  LT", 16, Color(0.72, 0.66, 0.52))
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mid := ThemeS.lab("", 20, Color(1, 0.92, 0.55))
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := ThemeS.lab("RT  ·  E", 16, Color(0.72, 0.66, 0.52))
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(left)
	head.add_child(mid)
	head.add_child(right)
	vb.add_child(head)
	var body := ThemeS.lab("", 16, Color(0.9, 0.84, 0.7))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	ui.gear_stats_title = mid
	ui.gear_stats = body
	panel.focus_entered.connect(func():
		ui.inv_sel = "stats"
		panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.16, 0.13, 0.09), Color(0.95, 0.78, 0.35)))
		refresh(ui)
	)
	panel.focus_exited.connect(func():
		panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.12, 0.1, 0.08), Color(0.45, 0.34, 0.18)))
	)
	panel.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			ui.inv_sel = "stats"
			Act.cycle_stats(ui, 1)
			panel.accept_event()
	)
	return panel


static func loadout_footer(ui: CanvasLayer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(ThemeS.btn("Character: %s" % App.character_type, func(): ui._confirm(func(): Act.toggle_char(ui), "char")))
	row.add_child(ThemeS.btn("Floor −", func(): Act.floor_step(ui, -1)))
	row.add_child(ThemeS.btn("Floor +", func(): Act.floor_step(ui, 1)))
	ui.box.add_child(row)
	ui.box.add_child(ThemeS.btn("Enter dungeon  (confirm)", func(): ui._confirm(func(): Act.enter(ui), "enter")))


static func bag_grid(ui: CanvasLayer) -> void:
	ui.box.add_child(ThemeS.lab("Bag", 20, Color(0.88, 0.82, 0.7)))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var cap: int = maxi(int(App.bal.bag_cap), App.prog.bag.size())
	for i: int in cap:
		var it: Dictionary = {}
		if i < App.prog.bag.size() and App.prog.bag[i] is Dictionary:
			it = App.prog.bag[i]
		grid.add_child(bag_cell(ui, it))
	ui.box.add_child(grid)


static func bag_cell(ui: CanvasLayer, it: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(188, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.4, 0.3, 0.18)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.26, 0.2, 0.13), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", ThemeS.sb(Color(0.11, 0.09, 0.08), Color(0.22, 0.18, 0.14)))
	if it.is_empty():
		b.text = "—"
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		return b
	var key := "bag:" + str(int(it.uid))
	b.text = Text.item_cell(it)
	b.add_theme_color_override("font_color", Text.item_color(it))
	b.set_meta("inv_key", key)
	b.pressed.connect(func():
		ui.inv_sel = key
		refresh(ui)
		Act.bag_primary(ui)
	)
	b.focus_entered.connect(func():
		ui.inv_sel = key
		refresh(ui)
	)
	return b


static func refresh(ui: CanvasLayer) -> void:
	if ui.get("gear_stats_title") != null and ui.gear_stats_title:
		ui.gear_stats_title.text = Text.stats_title(ui)
	if ui.get("gear_stats") != null and ui.gear_stats:
		ui.gear_stats.text = Text.stats_body(ui)
	if ui.get("gear_tip") != null and ui.gear_tip:
		ui.gear_tip.text = Text.tooltip(ui)
	if ui.get("gear_hint") != null and ui.gear_hint:
		ui.gear_hint.text = Text.hint_line(ui)
	if is_loadout(ui) and ui.status:
		ui.status.text = "Weapon %s   Tool %s   Floor %d / deepest %d" % [str(ui.loadout_wpn), str(ui.loadout_tool), int(ui.loadout_floor), App.prog.deepest]


static func find_sel(ui: CanvasLayer) -> Control:
	if str(ui.inv_sel) == "":
		return null
	for n: Node in ui.box.find_children("*", "Control", true, false):
		if str(n.get_meta("inv_key", "")) == ui.inv_sel:
			return n as Control
	var sub: Node = ui.get_node_or_null("gear_sub_panel")
	if sub:
		for n2: Node in sub.find_children("*", "Button", true, false):
			if str(n2.get_meta("inv_key", "")) == ui.inv_sel:
				return n2 as Control
	return null


static func selected(ui: CanvasLayer) -> Dictionary:
	return Text.selected(ui)


static func selected_slot(ui: CanvasLayer) -> String:
	return Text.selected_slot(ui)


static func clear_sub(ui: CanvasLayer) -> void:
	var old: Node = ui.get_node_or_null("gear_sub_panel")
	if old:
		old.queue_free()


static func apply_pending() -> void:
	if pending_kit.is_empty():
		return
	for slot: Variant in pending_kit.keys():
		var s := str(slot)
		var it: Dictionary = pending_kit[slot]
		if it.is_empty():
			continue
		if str(it.get("kit_src", "")) == "bank":
			var uid := int(it.get("uid", 0))
			var keep: Array = []
			for raw: Variant in App.prog.bank_items:
				if raw is Dictionary and int(raw.uid) != uid:
					keep.append(raw)
			App.prog.bank_items = keep
		App.prog.slots[s] = it.duplicate(true)
		if s == "weapon":
			App.prog.pick_weapon = str(it.get("weapon", App.prog.pick_weapon))
			App.weapon = App.prog.pick_weapon
		if s == "tool":
			App.prog.tool_type = str(it.get("tool", App.prog.tool_type))
	pending_kit.clear()
	if App.prog.has_method("_clamp_food_slot"):
		App.prog._clamp_food_slot()
	if App.prog.has_method("_refresh_player_hp"):
		App.prog._refresh_player_hp()
