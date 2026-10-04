extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Affix := preload("res://scripts/data/affixes.gd")
const Floor := preload("res://scripts/ui/gear_board/floor.gd")
const Build := preload("res://scripts/ui/gear_board/board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Sync := preload("res://scripts/ui/gear_board/host_sync.gd")

static func build(ui: CanvasLayer, mode: String) -> void:
	var _fac = load("res://scripts/ui/gear_board/board_host.gd")
	ensure_host(ui)
	ui.gear_mode = mode
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	ui.gear_x_hold = 0.0
	ui.gear_x_fired = false
	load("res://scripts/ui/gear_board.gd")._flag(ui, "gear_hover", false)
	load("res://scripts/ui/gear_board.gd")._flag(ui, "gear_tip_ready", false)
	load("res://scripts/ui/gear_board.gd")._flag(ui, "gear_booting", true)
	load("res://scripts/ui/gear_board.gd").clear_sub(ui)
	var title_col := ThemeS.INK
	var title := Build.build_title(ui, mode, title_col)
	var journal: bool = ui.has_meta("journal_sheet") and mode == "inv"
	var title_px: int = 32 if journal else 28
	var title_lab: Label = ThemeS.lab(title, title_px, title_col)
	var subtitle := Build.build_subtitle(ui, mode)
	var status_text := Build.build_status_text(mode)
	if status_text != "":
		ui.status = ThemeS.lab(status_text, 18, ThemeS.INK)
	else:
		ui.status = ThemeS.lab("", 16, ThemeS.INK_SOFT)
	if journal:
		_journal_pages(ui, _fac as GDScript, title_lab)
	else:
		ui.box.add_child(title_lab)
		if subtitle != "":
			ui.box.add_child(ThemeS.lab(subtitle, 16, ThemeS.INK_SOFT))
		ui.box.add_child(ui.status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not journal:
		ui.box.add_child(row)
		row.add_child(load("res://scripts/ui/gear_board.gd")._slot_col(ui, ["weapon", "potion"], true))
		row.add_child(load("res://scripts/ui/gear_board.gd")._slot_col(ui, Array(Affix.ARMOR_SLOTS), false))
		row.add_child(load("res://scripts/ui/gear_board.gd")._slot_col(ui, ["tool", "food"], true))
		row.add_child(Build.build_stats_card(ui))
	if ui.focus_btn == null:
		var hit: Control = _fac.find_sel(ui)
		if hit:
			ui.focus_btn = hit
	load("res://scripts/ui/gear_board.gd").hide_tip(ui)
	if mode == "loadout":
		Floor.footer(ui)
	elif mode == "anvil":
		load("res://scripts/ui/gear_board/anvil.gd").footer(ui)
	else:
		_fac.bag_grid(ui)
	load("res://scripts/ui/gear_board.gd")._paint_hint(ui)
	Sync.refresh(ui)
	var tree := ui.get_tree()
	if tree:
		tree.process_frame.connect(func():
			if is_instance_valid(ui):
				load("res://scripts/ui/gear_board.gd")._flag(ui, "gear_booting", false)
		, CONNECT_ONE_SHOT)

static func _journal_pages(ui: CanvasLayer, fac: GDScript, title_lab: Label) -> void:
	var page: GDScript = load("res://scripts/ui/pause_menu/journal_page.gd")
	var gear: GDScript = load("res://scripts/ui/gear_board.gd")
	var spread: HBoxContainer = HBoxContainer.new()
	spread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", int(page.GUTTER))
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var left_pad: MarginContainer = MarginContainer.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.add_theme_constant_override("margin_left", 18)
	left_pad.add_theme_constant_override("margin_right", 36)
	left_pad.add_theme_constant_override("margin_top", 18)
	left_pad.add_child(left)
	var right_pad: MarginContainer = MarginContainer.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.add_theme_constant_override("margin_left", 36)
	right_pad.add_theme_constant_override("margin_right", 22)
	right_pad.add_theme_constant_override("margin_top", 18)
	right_pad.add_child(right)
	spread.add_child(left_pad)
	spread.add_child(right_pad)
	ui.box.add_child(spread)
	left.add_child(title_lab)
	left.add_child(ui.status)
	var slots: HBoxContainer = HBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 14)
	slots.add_child(gear._slot_col(ui, ["weapon", "potion"], true))
	slots.add_child(gear._slot_col(ui, Array(Affix.ARMOR_SLOTS), false))
	slots.add_child(gear._slot_col(ui, ["tool", "food"], true))
	left.add_child(slots)
	right.add_child(Build.build_stats_card(ui))
	ui.set_meta("journal_column", left)
	if ui.focus_btn == null:
		var hit: Control = fac.find_sel(ui)
		if hit:
			ui.focus_btn = hit

static func ensure_host(ui: CanvasLayer) -> void:
	if ui.get("gear_stat_page") == null:
		ui.set("gear_stat_page", 0)
	if ui.get("gear_tip_mode") == null:
		ui.set("gear_tip_mode", 1)
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
	if ui.get("forge_type") == null:
		ui.set("forge_type", "")
	if ui.get("forge_rarity") == null:
		ui.set("forge_rarity", "green")
	if ui.get("forge_ilvl") == null:
		ui.set("forge_ilvl", 1)
	if ui.get("forge_locks") == null:
		ui.set("forge_locks", PackedStringArray())
	if ui.get("forge_new") == null:
		ui.set("forge_new", {})
	if not ui.has_meta("gear_hover"):
		ui.set_meta("gear_hover", false)
	if not ui.has_meta("gear_tip_ready"):
		ui.set_meta("gear_tip_ready", false)
	if not ui.has_meta("gear_booting"):
		ui.set_meta("gear_booting", false)
	PromptView.ensure_bar(ui)
