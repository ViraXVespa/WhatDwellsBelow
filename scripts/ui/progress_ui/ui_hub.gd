extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const GearAct := preload("res://scripts/ui/gear_board/board_act.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")

static func rebuild_loadout(ui: CanvasLayer) -> void:
	ui._clear()
	ui.gear_mode = "loadout"
	Board.build(ui, "loadout")

static func rebuild_anvil(ui: CanvasLayer) -> void:
	ui._clear()
	ui.gear_mode = "anvil"
	Board.build(ui, "anvil")

static func enter(ui) -> void:
	GearAct.enter(ui)

static func rebuild_quest(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab(App.tr("ui_hub.guild_tasks"), 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab(App.tr("ui_hub.three_choices_one_active_named"), 18, Color(0.82, 0.76, 0.66)))
	ui.status = ThemeS.lab("", 20, Color(0.95, 0.8, 0.45))
	ui.box.add_child(ui.status)
	if not App.prog.quest_active.is_empty():
		var q: Dictionary = App.prog.quest_active
		ui.box.add_child(ThemeS.lab(App.tr("ui_hub.active") % [q.title, int(q.get("have", 0)), int(q.get("need", 1))], 22, Color(0.75, 0.95, 0.7)))
		ui.box.add_child(ThemeS.btn(App.tr("ui_hub.abandon_active_task"), func(): Confirm.open(ui, App.tr("ui_hub.abandon_task"), App.tr("ui_hub.abandon_the_active_guild_task"), func(): ui._st(App.prog.abandon_quest()); ui._rebuild_quest(); ui._show())))
	var i := 0
	for q in App.prog.quests_offered:
		var idx := i
		if ui.focus_btn == null:
			ui.focus_btn = ThemeS.btn(App.tr("common.reward") % [q.title, q.reward], func(): ui._st(App.prog.accept_quest(idx)); ui._rebuild_quest(); ui._show())
			ui.box.add_child(ui.focus_btn)
		else:
			ui.box.add_child(ThemeS.btn(App.tr("common.reward") % [q.title, q.reward], func(): ui._st(App.prog.accept_quest(idx)); ui._rebuild_quest(); ui._show()))
		i += 1
	var close := ThemeS.btn(App.tr("common.close"), func(): ui.close_ui())
	if ui.focus_btn == null:
		ui.focus_btn = close
	ui.box.add_child(close)

static func rebuild_controls(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab(App.tr("common.controls_billboard"), 32, Color(0.95, 0.82, 0.5)))
	ui.box.add_child(ThemeS.lab(App.tr("ui_hub.what_the_guild_painted_up"), 18, Color(0.82, 0.76, 0.66)))
	var acts := [
		["move_left", "Move left"],
		["move_right", "Move right"],
		["move_up", "Move up"],
		["move_down", "Move down"],
		["attack", "Attack"],
		["special", "Special"],
		["dash", "Dash"],
		["interact", "Interact"],
		["pause", "Pause"],
		["potion", "Potion"],
		["food", "Food"],
		["map_view", "Map"],
		["target_lock", "Target-lock"],
	]
	for pair in acts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		PromptView.fill(row, [{"action": str(pair[0]), "verb": str(pair[1])}], 18, Color(0.9, 0.86, 0.74))
		ui.box.add_child(row)
	ui.focus_btn = ThemeS.btn(App.tr("common.leave"), func(): ui.close_ui())
	ui.box.add_child(ui.focus_btn)
