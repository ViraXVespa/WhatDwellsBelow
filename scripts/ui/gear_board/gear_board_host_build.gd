extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Text := preload("res://scripts/ui/gear_board/gear_board_text.gd")
const Act := preload("res://scripts/ui/gear_board/gear_board_act.gd")
const Floor := preload("res://scripts/ui/gear_board/gear_board_floor.gd")
const Tip := preload("res://scripts/ui/gear_board/gear_board_tip.gd")
const Build := preload("res://scripts/ui/gear_board/gear_board_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Sync := preload("res://scripts/ui/gear_board/gear_board_host_sync.gd")

static func build(ui: CanvasLayer, mode: String) -> void:
	var _fac = load("res://scripts/ui/gear_board/gear_board_host.gd")
	ensure_host(ui)
	ui.gear_mode = mode
	ui.gear_sub = false
	ui.gear_sub_slot = ""
	ui.gear_x_hold = 0.0
	ui.gear_x_fired = false
	load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_hover", false)
	load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_tip_ready", false)
	load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_booting", true)
	load("res://scripts/ui/gear_board/gear_board.gd").clear_sub(ui)
	var title_col := Color(0.95, 0.82, 0.5)
	if mode == "loadout":
		title_col = Color(0.6, 0.9, 1.0)
	elif mode == "anvil":
		title_col = Color(0.95, 0.78, 0.42)
	var title := Build.build_title(ui, mode, title_col)
	ui.box.add_child(ThemeS.lab(title, 28, title_col))
	var subtitle := Build.build_subtitle(ui, mode)
	if subtitle != "":
		ui.box.add_child(ThemeS.lab(subtitle, 16, Color(0.82, 0.76, 0.66)))
	var status_text := Build.build_status_text(mode)
	if status_text != "":
		ui.status = ThemeS.lab(status_text, 18, Color(0.95, 0.8, 0.45))
	else:
		ui.status = ThemeS.lab("", 16, Color(0.78, 0.74, 0.66))
	ui.box.add_child(ui.status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.box.add_child(row)
	row.add_child(load("res://scripts/ui/gear_board/gear_board.gd")._slot_col(ui, ["weapon", "potion"], true))
	row.add_child(load("res://scripts/ui/gear_board/gear_board.gd")._slot_col(ui, ["head", "body", "legs"], false))
	row.add_child(load("res://scripts/ui/gear_board/gear_board.gd")._slot_col(ui, ["tool", "food"], true))
	row.add_child(Build.build_stats_card(ui))
	if ui.focus_btn == null:
		var hit: Control = _fac.find_sel(ui)
		if hit:
			ui.focus_btn = hit
	load("res://scripts/ui/gear_board/gear_board.gd").hide_tip(ui)
	if mode == "loadout":
		Floor.footer(ui)
	elif mode == "anvil":
		load("res://scripts/ui/gear_board/gear_board_anvil.gd").footer(ui)
	else:
		_fac.bag_grid(ui)
	load("res://scripts/ui/gear_board/gear_board.gd")._paint_hint(ui)
	Sync.refresh(ui)
	var tree := ui.get_tree()
	if tree:
		tree.process_frame.connect(func():
			if is_instance_valid(ui):
				load("res://scripts/ui/gear_board/gear_board.gd")._flag(ui, "gear_booting", false)
		, CONNECT_ONE_SHOT)

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
