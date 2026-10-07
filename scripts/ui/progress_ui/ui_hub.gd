extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const GearAct := preload("res://scripts/ui/gear_board/board_act.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const ControlsFrame := preload("res://scripts/ui/progress_ui/controls_frame.gd")

static func rebuild_loadout(ui: CanvasLayer) -> void:
	ui._clear()
	ui.gear_mode = "loadout"
	Board.build(ui, "loadout")

static func rebuild_anvil(ui: CanvasLayer) -> void:
	ui._clear()
	ui.gear_mode = "anvil"
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.custom_minimum_size = Vector2(0, 12)
	ui.box.add_child(pad)
	Board.build(ui, "anvil")

static func enter(ui) -> void:
	GearAct.enter(ui)

static func rebuild_quest(ui) -> void:
	ui._clear()
	ui.box.add_child(ThemeS.lab(App.tr("ui_hub.guild_tasks"), 32, ThemeS.INK))
	ui.box.add_child(ThemeS.lab(App.tr("ui_hub.three_choices_one_active_named"), 18, ThemeS.INK_SOFT))
	ui.status = ThemeS.lab("", 20, ThemeS.INK)
	ui.box.add_child(ui.status)
	if not App.prog.quest_active.is_empty():
		var q: Dictionary = App.prog.quest_active
		ui.box.add_child(ThemeS.lab(App.tr("ui_hub.active") % [q.title, int(q.get("have", 0)), int(q.get("need", 1))], 22, Color(0.16, 0.38, 0.16)))
		var abandon: Button = ThemeS.btn(App.tr("ui_hub.abandon_active_task"), func() -> void:
			Confirm.open(ui, App.tr("ui_hub.abandon_task"), App.tr("ui_hub.abandon_the_active_guild_task"), func() -> void:
				ui._st(App.prog.abandon_quest())
				ui._rebuild_quest()
				ui._show()
			, Callable(), "danger")
		, true, "danger")
		ui.box.add_child(abandon)
	var i := 0
	for q in App.prog.quests_offered:
		var idx := i
		var take: Button = ThemeS.btn(App.tr("common.reward") % [q.title, q.reward], func() -> void:
			ui._st(App.prog.accept_quest(idx))
			ui._rebuild_quest()
			ui._show()
		, true, "primary")
		if ui.focus_btn == null:
			ui.focus_btn = take
		ui.box.add_child(take)
		i += 1
	var close := ThemeS.btn(App.tr("common.close"), func(): ui.close_ui())
	if ui.focus_btn == null:
		ui.focus_btn = close
	ui.box.add_child(close)

static func rebuild_controls(ui) -> void:
	ui._clear()
	ControlsFrame.prepare(ui)
	var acts := [
		["move_left", App.tr("controls.move_left")],
		["move_right", App.tr("controls.move_right")],
		["move_up", App.tr("controls.move_up")],
		["move_down", App.tr("controls.move_down")],
		["attack", App.tr("controls.attack")],
		["special", App.tr("controls.special")],
		["dash", App.tr("controls.dash")],
		["interact", App.tr("controls.interact")],
		["pause", App.tr("controls.pause")],
		["potion", App.tr("controls.potion")],
		["food", App.tr("controls.food")],
		["map_view", App.tr("controls.map_view")],
		["target_lock", App.tr("ui_hub.target_lock")],
	]
	for pair in acts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.set_meta("prompt_tap", false)
		PromptView.fill(row, [{"action": str(pair[0]), "verb": str(pair[1])}], 18, ThemeS.PAPER)
		ui.box.add_child(row)
	ui.focus_btn = ThemeS.btn(App.tr("common.leave"), func(): ui.close_ui())
	ControlsFrame.dress(ui.focus_btn)
	ui.box.add_child(ui.focus_btn)
