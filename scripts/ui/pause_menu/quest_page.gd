extends Object

## Pause Quest tab: the taken poster on the left sheet, progress and cancel on the right.

const ThemeS: GDScript = preload("res://scripts/ui/theme.gd")
const Confirm: GDScript = preload("res://scripts/ui/confirm_dlg.gd")
const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")
const JournalSpread: GDScript = preload("res://scripts/ui/journal_spread.gd")
const Board: GDScript = preload("res://scripts/ui/progress_ui/quest_board.gd")

static func build(ui: CanvasLayer) -> void:
	var pair: Array = JournalSpread.cols(ui, Journal.EVEN_LEFT)
	var left_r: Rect2 = pair[0]
	var right_r: Rect2 = pair[1]
	var span_w: float = right_r.position.x + right_r.size.x
	var sheet: Control = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.custom_minimum_size = Vector2(span_w, 520.0)
	ui.box.add_child(sheet)
	var left: Control = Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.position = Vector2(left_r.position.x + 20.0, 28.0)
	left.size = Vector2(maxf(40.0, left_r.size.x - 40.0), 460.0)
	sheet.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.position = Vector2(right_r.position.x + 20.0, 28.0)
	right.size = Vector2(maxf(40.0, right_r.size.x - 40.0), 0.0)
	right.custom_minimum_size = Vector2(maxf(40.0, right_r.size.x - 40.0), 0.0)
	right.add_theme_constant_override("separation", 14)
	sheet.add_child(right)
	var raw: Variant = App.prog.quest_active
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		right.add_child(ThemeS.lab(App.tr("quest_tab.none"), 28, ThemeS.INK))
		return
	var q: Dictionary = raw as Dictionary
	var paper: Control = Control.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.position = Vector2(8, 8)
	paper.size = Vector2(320, 420)
	left.add_child(paper)
	Board.pinned(paper, q, Vector2(320, 420))
	right.add_child(ThemeS.lab(str(q.get("title", "")), 32, ThemeS.INK))
	right.add_child(ThemeS.lab(App.tr(Board.seal_key(str(q.get("kind", "")))), 20, ThemeS.INK_SOFT))
	right.add_child(ThemeS.lab(App.tr("quest_tab.progress") % [int(q.get("have", 0)), int(q.get("need", 1))], 22, ThemeS.INK))
	right.add_child(ThemeS.lab(App.tr("quest_tab.reward") % str(q.get("reward", "")), 22, ThemeS.INK))
	var cancel: Button = ThemeS.btn(App.tr("ui_hub.abandon_active_task"), func() -> void:
		Confirm.open(ui, App.tr("ui_hub.abandon_task"), App.tr("ui_hub.abandon_the_active_guild_task"), func() -> void:
			ui._st(App.prog.abandon_quest())
			ui._rebuild()
		, Callable(), "danger")
	, true, "danger")
	ui.focus_btn = cancel
	right.add_child(cancel)
