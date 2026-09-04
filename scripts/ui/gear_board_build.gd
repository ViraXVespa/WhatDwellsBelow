extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board_text.gd")
const Fmt := preload("res://scripts/ui/gear_board_text_fmt.gd")
const Floor := preload("res://scripts/ui/gear_board_floor.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func build_title(ui: CanvasLayer, mode: String, title_col: Color) -> String:
	var title := "Inventory"
	if mode == "loadout":
		title = "Floor Crystal — Loadout"
		title_col = Color(0.6, 0.9, 1.0)
	elif mode == "anvil":
		title = "Anvil"
		title_col = Color(0.95, 0.78, 0.42)
	return title


static func build_subtitle(ui: CanvasLayer, mode: String) -> String:
	if mode == "loadout":
		return "Choose holds or stash gear. Only floors you have reached."
	elif mode == "anvil":
		return "Analyze DESTROYS a piece. Forge those remains on the Forge tab. Starters stay off the list."
	return ""


static func build_status_text(mode: String) -> String:
	if mode == "loadout" or mode == "anvil":
		return ""
	return "Carried  %dg   %d ore   %d wood   bag %d/%d" % [App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)]


static func plain_lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func sync_chrome(ui: CanvasLayer) -> void:
	if ui.get("gear_page_left") is Control:
		PromptView.fill(ui.gear_page_left, [{"action": Prompts.page_prev()}], 16, Color(0.72, 0.66, 0.52))
	if ui.get("gear_page_right") is Control:
		PromptView.fill(ui.gear_page_right, [{"action": Prompts.page_next()}], 16, Color(0.72, 0.66, 0.52))


static func build_stats_card(ui: CanvasLayer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.focus_mode = Control.FOCUS_NONE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.12, 0.1, 0.08), Color(0.45, 0.34, 0.18)))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 12)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(84, 28)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var mid := plain_lab("", 20, Color(1, 0.92, 0.55))
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(84, 28)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(left)
	head.add_child(mid)
	head.add_child(right)
	vb.add_child(head)
	var body := plain_lab("", 16, Color(0.9, 0.84, 0.7))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	ui.gear_stats_title = mid
	ui.gear_stats = body
	ui.gear_page_left = left
	ui.gear_page_right = right
	sync_chrome(ui)
	return panel


static func build_slot_btn(ui: CanvasLayer, slot: String) -> Button:
	var it: Dictionary = App.prog.slots.get(slot, {})
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = false
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Fmt.item_color(it))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.18, 0.14, 0.1), Color(0.4, 0.3, 0.18)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.26, 0.2, 0.13), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.14, 0.11, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.text = Text.slot_face(ui, slot, it)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


static func build_bag_cell(ui: CanvasLayer, it: Dictionary) -> Button:
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
	b.text = Text.item_cell(it)
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = false
	b.add_theme_color_override("font_color", Fmt.item_color(it))
	return b
