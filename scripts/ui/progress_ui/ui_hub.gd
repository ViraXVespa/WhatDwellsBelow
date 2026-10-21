extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const Board := preload("res://scripts/ui/gear_board.gd")
const GearAct := preload("res://scripts/ui/gear_board/board_act.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const ControlsFrame := preload("res://scripts/ui/progress_ui/controls_frame.gd")
const QuestBoard := preload("res://scripts/ui/progress_ui/quest_board.gd")
const Reception := preload("res://scripts/ui/progress_ui/receptionist.gd")

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

static func rebuild_quest(ui: CanvasLayer) -> void:
	QuestBoard.rebuild(ui)

## Receptionist body: Talk and Ask? (receptionist.gd owns the page stack).
static func rebuild_receptionist(ui) -> void:
	Reception.rebuild(ui)

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
	var col: float = PromptView.glyph_col(acts.map(func(p): return p[0]), 18)
	for pair in acts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.set_meta("prompt_tap", false)
		row.set_meta("glyph_col", col)
		PromptView.fill(row, [{"action": str(pair[0]), "verb": str(pair[1])}], 18, ThemeS.PAPER)
		ui.box.add_child(row)
	ui.focus_btn = ThemeS.btn(App.tr("common.leave"), func(): ui.close_ui())
	ControlsFrame.dress(ui.focus_btn)
	ui.box.add_child(ui.focus_btn)
