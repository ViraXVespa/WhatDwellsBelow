extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/board_text.gd")
const Fmt := preload("res://scripts/ui/gear_board/text_fmt.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

static func build_title(_ui: CanvasLayer, mode: String, _title_col: Color) -> String:
	var title := App.tr("board_build.inventory")
	if mode == "loadout":
		title = App.tr("board_build.floor_crystal_loadout")
		_title_col = Color(0.6, 0.9, 1.0)
	elif mode == "anvil":
		title = App.tr("common.anvil")
		_title_col = Color(0.95, 0.78, 0.42)
	elif mode == "extract":
		title = App.tr("common.extraction_gate")
	return title

static func build_subtitle(_ui: CanvasLayer, mode: String) -> String:
	if mode == "loadout":
		return App.tr("board_build.choose_holds_or_stash_gear")
	elif mode == "anvil":
		return App.tr("board_build.analyze_destroys_a_piece_forge")
	elif mode == "extract":
		return App.tr("inv.mail_goods_to_the_surface")
	return ""

static func build_status_text(mode: String) -> String:
	if mode == "loadout" or mode == "anvil":
		return ""
	return App.tr("board_build.carried_g_ore_wood_bag") % [App.gold, App.ore, App.wood, App.prog.bag_count(), int(App.bal.bag_cap)]

static func plain_lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.add_theme_font_override("font", ThemeS.ink_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", ThemeS.OUTLINE)
	l.add_theme_constant_override("outline_size", 0)
	return l

static func sync_chrome(ui: CanvasLayer) -> void:
	if ui.get("gear_page_left") is Control:
		PromptView.fill(ui.gear_page_left, [{"action": Prompts.page_prev()}], 16, ThemeS.INK_SOFT)
	if ui.get("gear_page_right") is Control:
		PromptView.fill(ui.gear_page_right, [{"action": Prompts.page_next()}], 16, ThemeS.INK_SOFT)

static func build_stats_card(ui: CanvasLayer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 250)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.focus_mode = Control.FOCUS_NONE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui.has_meta("journal_sheet"):
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.custom_minimum_size = Vector2(0, 0)
		panel.add_theme_stylebox_override("panel", ThemeS._ink_box(Color(0, 0, 0, 0), ThemeS.INK, 1, 1))
	else:
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
	var mid := plain_lab("", 20, ThemeS.INK)
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
	var body := plain_lab("", 16, ThemeS.INK_SOFT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	if ui.has_meta("journal_sheet"):
		body.visible = false
		var rows: VBoxContainer = VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 0)
		vb.add_child(rows)
		ui.set_meta("journal_stat_rows", rows)
	ui.gear_stats_title = mid
	ui.gear_stats = body
	ui.gear_page_left = left
	ui.gear_page_right = right
	sync_chrome(ui)
	return panel

static func build_slot_btn(_ui: CanvasLayer, slot: String) -> Button:
	var it: Dictionary = Text.slot_item(slot)
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = false
	b.text = ""
	Icons.fit_btn(b, Icons.tex_for_slot(slot, it))
	_paint_item_btn(b, it)
	if Text.has_unseen(slot):
		b.text = "▸"
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", ThemeS.INK)
	return b

static func build_bag_cell(_ui: CanvasLayer, it: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("disabled", ThemeS.sb(Color(0.11, 0.09, 0.08), Color(0.22, 0.18, 0.14)))
	if it.is_empty():
		b.text = ""
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		_paint_item_btn(b, {})
		return b
	b.text = ""
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = false
	if Icons.has_item_icon(it):
		Icons.fit_btn(b, Icons.tex_for_item(it))
	else:
		b.text = Text.item_cell(it)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Fmt.item_color(it))
	_paint_item_btn(b, it)
	return b

static func _paint_item_btn(b: Button, it: Dictionary) -> void:
	ThemeS.paint_plate(b, Icons.rarity_fill(it), Icons.rarity_border(it), false)
