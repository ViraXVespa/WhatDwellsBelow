extends Object
const CombatP := preload("res://scripts/data/progress_combat.gd")

const ThemeS := preload("res://scripts/ui/theme.gd")
const LocS := preload("res://scripts/app/app_loc.gd")
const SkillRow := preload("res://scripts/ui/skill_row_view.gd")
const Journal := preload("res://scripts/ui/pause_menu/journal_page.gd")

static func skill_title(_ui: CanvasLayer, id: String) -> String:
	return LocS.tr_or("skill." + id, id)

static func perm_line(ui: CanvasLayer, id: String, perm: float) -> String:
	return App.tr("common.lv_next_level_xp_total") % [
		skill_title(ui, id),
		CombatP.level_from_xp(App.prog, perm),
		int(round(CombatP.xp_to_next(App.prog, perm))),
		int(round(perm)),
	]

static func run_line(ui: CanvasLayer, id: String, perm: float, runx: float) -> String:
	var live: float = perm + runx
	return App.tr("common.lv_this_run_xp_next") % [
		skill_title(ui, id),
		CombatP.level_from_xp(App.prog, live),
		int(round(runx)),
		int(round(CombatP.xp_to_next(App.prog, live))),
	]

static func skill_lab(text: String, size: int = 16, col: Color = ThemeS.INK) -> Label:
	return SkillRow.skill_lab(text, size, col)

static func skill_block(ui: CanvasLayer, id: String, kind: String, text: String, ratio: float, fill_col: Color) -> PanelContainer:
	var shell: PanelContainer = SkillRow.row_single(text, ratio, fill_col)
	shell.set_meta("skill_id", id)
	shell.set_meta("skill_kind", kind)
	shell.focus_entered.connect(ui._on_skill_focus.bind(id, kind, shell))
	shell.mouse_entered.connect(ui._on_skill_focus.bind(id, kind, shell))
	shell.focus_exited.connect(ui._on_skill_blur.bind(shell))
	shell.mouse_exited.connect(ui._on_skill_blur.bind(shell))
	return shell

static func tip_lv(_ui: CanvasLayer, id: String, kind: String) -> int:
	var perm: float = float(App.prog.skills_perm.get(id, 0.0))
	var runx: float = float(App.prog.skills_run.get(id, 0.0))
	if kind == "run":
		return CombatP.level_from_xp(App.prog, perm + runx)
	return CombatP.level_from_xp(App.prog, perm)

static func _page_w(ui: CanvasLayer) -> float:
	var span: float = 1752.0
	if ui.scroll and ui.scroll.size.x > 10.0:
		span = ui.scroll.size.x
	return (span - Journal.GUTTER) * 0.5

static func _left_col(ui: CanvasLayer) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size = Vector2(_page_w(ui) - 16.0, 0.0)
	col.add_theme_constant_override("separation", 8)
	ui.box.add_child(col)
	return col

static func paint_tip(ui: CanvasLayer) -> void:
	if ui.tip_id == "" or ui.tip_host == null or ui.tip_lab == null:
		if ui.tip_host:
			ui.tip_host.visible = false
		return
	var page: float = _page_w(ui)
	var origin: Vector2 = ui.scroll.position if ui.scroll else Vector2(84, 102)
	var w: float = page - 36.0
	ui.tip_lab.text = ThemeS.skill_tip(ui.tip_id, tip_lv(ui, ui.tip_id, ui.tip_kind))
	ui.tip_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.tip_lab.add_theme_font_override("font", ThemeS.ink_font())
	ui.tip_lab.add_theme_constant_override("outline_size", 0)
	ui.tip_lab.custom_minimum_size = Vector2(w - 28.0, 0.0)
	var h: float = maxf(120.0, ui.tip_lab.get_minimum_size().y + 28.0)
	ui.tip_host.position = Vector2(origin.x + page + Journal.GUTTER + 18.0, origin.y + 8.0)
	ui.tip_host.size = Vector2(w, h)
	ui.tip_host.visible = true
	ui.tip_host.z_index = 4

static func _show_first(ui: CanvasLayer, row: PanelContainer) -> void:
	ui.focus_btn = row
	ui.tip_from = row
	ui.tip_id = str(row.get_meta("skill_id"))
	ui.tip_kind = str(row.get_meta("skill_kind"))
	paint_tip(ui)

static func build(ui: CanvasLayer) -> void:
	var left: VBoxContainer = _left_col(ui)
	left.add_child(ui._cap(App.tr("pause_skills.combat_level") % App.prog.combat_lv(), 24, ThemeS.INK))
	left.add_child(ui._cap(App.tr("pause_skills.highlight_a_skill_for_its"), 16, ThemeS.INK_SOFT))
	var perm_col: Color = Color(0.72, 0.56, 0.28)
	var run_col: Color = Color(0.86, 0.74, 0.32)
	var first: PanelContainer = null
	if App.in_dungeon:
		left.add_child(skill_lab(App.tr("pause_skills.permanent"), 18, ThemeS.INK))
		for id: String in App.prog.SKILLS:
			var perm: float = float(App.prog.skills_perm.get(id, 0.0))
			var block: PanelContainer = skill_block(ui, id, "perm", perm_line(ui, id, perm), CombatP.xp_ratio(App.prog, perm), perm_col)
			left.add_child(block)
			if first == null:
				first = block
		left.add_child(skill_lab(App.tr("common.dungeon_xp"), 18, ThemeS.INK))
		for id2: String in App.prog.SKILLS:
			var perm_d: float = float(App.prog.skills_perm.get(id2, 0.0))
			var runx: float = float(App.prog.skills_run.get(id2, 0.0))
			left.add_child(skill_block(ui, id2, "run", run_line(ui, id2, perm_d, runx), CombatP.xp_ratio(App.prog, perm_d + runx), run_col))
	else:
		for id3: String in App.prog.SKILLS:
			var perm2: float = float(App.prog.skills_perm.get(id3, 0.0))
			var row2: PanelContainer = skill_block(ui, id3, "perm", perm_line(ui, id3, perm2), CombatP.xp_ratio(App.prog, perm2), perm_col)
			left.add_child(row2)
			if first == null:
				first = row2
	if first:
		_show_first(ui, first)
