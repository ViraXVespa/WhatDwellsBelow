extends Object
const CombatP := preload("res://scripts/data/progress_combat.gd")

const ThemeS := preload("res://scripts/ui/theme.gd")
const TipPlace := preload("res://scripts/ui/tip_place.gd")
const SkillRow := preload("res://scripts/ui/skill_row_view.gd")


static func skill_title(ui: CanvasLayer, id: String) -> String:
	return str(ui.SKILL_NAMES.get(id, id))


static func perm_line(ui: CanvasLayer, id: String, perm: float) -> String:
	return "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
		skill_title(ui, id),
		CombatP.level_from_xp(App.prog, perm),
		int(round(CombatP.xp_to_next(App.prog, perm))),
		int(round(perm)),
	]


static func run_line(ui: CanvasLayer, id: String, perm: float, runx: float) -> String:
	var live: float = perm + runx
	return "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
		skill_title(ui, id),
		CombatP.level_from_xp(App.prog, live),
		int(round(runx)),
		int(round(CombatP.xp_to_next(App.prog, live))),
	]


static func skill_lab(text: String, size: int = 16, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	return SkillRow.skill_lab(text, size, col)


static func xp_bar(ratio: float, fill_col: Color) -> ColorRect:
	return SkillRow.single_fill(ratio, fill_col)


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


static func _footer_top(ui: CanvasLayer) -> float:
	var view: Rect2 = ui.get_viewport().get_visible_rect()
	var cut: float = view.position.y + view.size.y - 120.0
	var bar: Node = ui.get_node_or_null("gear_hint_bar")
	if bar is Control:
		var br: Rect2 = (bar as Control).get_global_rect()
		if br.size.y > 1.0:
			cut = minf(cut, br.position.y)
	return cut


static func paint_tip(ui: CanvasLayer) -> void:
	if ui.tip_id == "" or ui.tip_from == null or not is_instance_valid(ui.tip_from):
		if ui.tip_host:
			ui.tip_host.visible = false
		return
	ui.tip_lab.text = ThemeS.skill_tip(ui.tip_id, tip_lv(ui, ui.tip_id, ui.tip_kind))
	ui.tip_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var w: float = 404.0
	ui.tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h: float = maxf(80.0, ui.tip_lab.get_minimum_size().y + 20.0)
	ui.tip_host.size = Vector2(w, h)
	var r: Rect2 = ui.tip_from.get_global_rect()
	var cut: float = _footer_top(ui) - 8.0
	TipPlace.place_flip_below(ui.tip_host, r, cut, w)
	ui.tip_host.visible = true
	ui.tip_host.z_index = 90


static func build(ui: CanvasLayer) -> void:
	ui.box.add_child(ui._cap("Combat Level %d" % App.prog.combat_lv(), 24, Color(0.95, 0.8, 0.45)))
	ui.box.add_child(ui._cap("Highlight a skill for its bonuses.", 16, Color(0.78, 0.74, 0.66)))
	var perm_col: Color = Color(0.72, 0.56, 0.28)
	var run_col: Color = Color(0.86, 0.74, 0.32)
	var first: PanelContainer = null
	if App.in_dungeon:
		var heads: HBoxContainer = HBoxContainer.new()
		heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heads.add_theme_constant_override("separation", 24)
		heads.add_child(skill_lab("Permanent", 18, Color(0.95, 0.8, 0.45)))
		heads.add_child(skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45)))
		ui.box.add_child(heads)
		for id: String in App.prog.SKILLS:
			var perm: float = float(App.prog.skills_perm.get(id, 0.0))
			var runx: float = float(App.prog.skills_run.get(id, 0.0))
			var row: HBoxContainer = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 24)
			var left: PanelContainer = skill_block(ui, id, "perm", perm_line(ui, id, perm), CombatP.xp_ratio(App.prog, perm), perm_col)
			var right: PanelContainer = skill_block(ui, id, "run", run_line(ui, id, perm, runx), CombatP.xp_ratio(App.prog, perm + runx), run_col)
			row.add_child(left)
			row.add_child(right)
			ui.box.add_child(row)
			if first == null:
				first = left
	else:
		for id: String in App.prog.SKILLS:
			var perm2: float = float(App.prog.skills_perm.get(id, 0.0))
			var row2: PanelContainer = skill_block(ui, id, "perm", perm_line(ui, id, perm2), CombatP.xp_ratio(App.prog, perm2), perm_col)
			ui.box.add_child(row2)
			if first == null:
				first = row2
	if first:
		ui.focus_btn = first
