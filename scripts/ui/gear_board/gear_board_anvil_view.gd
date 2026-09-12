extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")


static func tab(ui: CanvasLayer) -> String:
	var t := str(ui.get("anvil_tab"))
	return t if t == "forge" else "analyze"


static func footer(ui: CanvasLayer) -> void:
	_tabs(ui)
	ui.box.add_child(ThemeS.lab(
		"Bank %dg  %d ore  %d wood	Carried %dg  %d ore  %d wood" % [
			App.bank_gold, App.bank_ore, App.bank_wood,
			App.gold, App.ore, App.wood,
		],
		16,
		Color(0.8, 0.85, 0.7),
	))
	var smith: int = App.prog.skill_lv("smith")
	if tab(ui) == "forge":
		_forge_body(ui, smith)
	else:
		_analyze_body(ui, smith)


static func _tabs(ui: CanvasLayer) -> void:
	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(36, 28)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(36, 28)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(200, 52)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.follow_focus = true
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var a: Button = ThemeS.btn("Analyze", func(): set_tab(ui, "analyze"))
	var f: Button = ThemeS.btn("Forge", func(): set_tab(ui, "forge"))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.custom_minimum_size = Vector2(160, 44)
	f.custom_minimum_size = Vector2(160, 44)
	if tab(ui) == "analyze":
		_paint_on(a)
	else:
		_paint_on(f)
	row.add_child(a)
	row.add_child(f)
	sc.add_child(row)
	shell.add_child(left)
	shell.add_child(sc)
	shell.add_child(right)
	PromptView.fill(left, [{"action": "tab_left"}], 16, Color(0.72, 0.66, 0.52))
	PromptView.fill(right, [{"action": "tab_right"}], 16, Color(0.72, 0.66, 0.52))
	ui.box.add_child(shell)


static func drop_sub(ui: CanvasLayer) -> void:
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	var Sub = load("res://scripts/ui/gear_board/gear_board_sub.gd")
	Sub.unlock_bg(ui)
	var old: Node = ui.get_node_or_null("gear_sub_panel")
	while old:
		old.name = "gear_sub_dead"
		old.queue_free()
		old = ui.get_node_or_null("gear_sub_panel")
	var Board = load("res://scripts/ui/gear_board/gear_board.gd")
	Board.hide_tip(ui)


static func set_tab(ui: CanvasLayer, t: String) -> void:
	ui.anvil_tab = t
	ui.anvil_item = {}
	ui.anvil_src = ""
	ui.pending = false
	ui.forge_type = ""
	ui.forge_rarity = "green"
	ui.forge_ilvl = 1
	ui.forge_locks = PackedStringArray()
	ui.forge_new = {}
	ui.forge_it = {}
	ui.forge_t = 0.0
	drop_sub(ui)
	ui.call_deferred("_rebuild_anvil")
	ui.call_deferred("_show")


static func _analyze_body(ui: CanvasLayer, smith: int) -> void:
	ui.status.text = "Smithing %d. Open a slot to analyze an AT RISK piece." % smith


static func _forge_body(ui: CanvasLayer, smith: int) -> void:
	if float(ui.get("forge_t")) > 0.0:
		ui.status.text = "Smithing %d. Forging… %.1fs." % [smith, float(ui.forge_t)]
		return
	var book: Dictionary = {}
	if App.prog.get("forge_book") is Dictionary:
		book = App.prog.forge_book
	if book.is_empty():
		ui.status.text = "Smithing %d. Analyze a piece before you can forge." % smith
		return
	ui.status.text = "Smithing %d. Open a slot to set type, rarity, level, and locks." % smith


static func _paint_on(b: Button) -> void:
	var ink := Color(0.92, 0.84, 0.62)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_stylebox_override("normal", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("focus", ThemeS.sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("hover", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("pressed", ThemeS.sb(Color(0.38, 0.28, 0.16), Color(0.95, 0.78, 0.35)))
