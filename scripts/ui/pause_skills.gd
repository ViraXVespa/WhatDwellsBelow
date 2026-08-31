extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")


static func xp_lv(total: float) -> int:
	return App.prog.level_from_xp(total)


static func xp_to_next(total: float) -> int:
	return int(round(App.prog.xp_to_next(total)))


static func xp_ratio(total: float) -> float:
	return App.prog.xp_ratio(total)


static func skill_title(ui: CanvasLayer, id: String) -> String:
	return str(ui.SKILL_NAMES.get(id, id))


static func perm_line(ui: CanvasLayer, id: String, perm: float) -> String:
	return "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
		skill_title(ui, id),
		xp_lv(perm),
		xp_to_next(perm),
		int(round(perm)),
	]


static func run_line(ui: CanvasLayer, id: String, perm: float, runx: float) -> String:
	var live: float = perm + runx
	return "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
		skill_title(ui, id),
		xp_lv(live),
		int(round(runx)),
		xp_to_next(live),
	]


static func skill_lab(text: String, size: int = 16, col: Color = Color(0.9, 0.84, 0.7)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func xp_bar(ratio: float, fill_col: Color) -> ColorRect:
	var track: ColorRect = ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, 16)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = Color(0.18, 0.14, 0.1)
	track.clip_contents = true
	var fill: ColorRect = ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_col
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	return track


static func skill_block(ui: CanvasLayer, id: String, kind: String, text: String, ratio: float, fill_col: Color) -> PanelContainer:
	var wrap: PanelContainer = ThemeS.skill_row()
	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	inner.add_child(skill_lab(text))
	inner.add_child(xp_bar(ratio, fill_col))
	wrap.add_child(inner)
	wrap.set_meta("skill_id", id)
	wrap.set_meta("skill_kind", kind)
	wrap.focus_entered.connect(ui._on_skill_focus.bind(id, kind, wrap))
	wrap.mouse_entered.connect(ui._on_skill_focus.bind(id, kind, wrap))
	wrap.focus_exited.connect(ui._on_skill_blur.bind(wrap))
	wrap.mouse_exited.connect(ui._on_skill_blur.bind(wrap))
	return wrap


static func tip_lv(ui: CanvasLayer, id: String, kind: String) -> int:
	var perm: float = float(App.prog.skills_perm.get(id, 0.0))
	var runx: float = float(App.prog.skills_run.get(id, 0.0))
	if kind == "run":
		return xp_lv(perm + runx)
	return xp_lv(perm)


static func paint_tip(ui: CanvasLayer) -> void:
	if ui.tip_id == "" or ui.tip_from == null or not is_instance_valid(ui.tip_from):
		if ui.tip_host:
			ui.tip_host.visible = false
		return
	ui.tip_lab.text = ThemeS.skill_tip(ui.tip_id, tip_lv(ui, ui.tip_id, ui.tip_kind))
	var w: float = 404.0
	ui.tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h: float = maxf(80.0, ui.tip_lab.get_minimum_size().y + 20.0)
	ui.tip_host.size = Vector2(w, h)
	var r: Rect2 = ui.tip_from.get_global_rect()
	var pos: Vector2 = Vector2(r.position.x, r.position.y + r.size.y + 8.0)
	if pos.y + h > 1060.0:
		pos.y = r.position.y - h - 8.0
	if pos.x + w > 1900.0:
		pos.x = 1900.0 - w
	if pos.x < 20.0:
		pos.x = 20.0
	ui.tip_host.position = pos
	ui.tip_host.visible = true


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
			var left: PanelContainer = skill_block(ui, id, "perm", perm_line(ui, id, perm), xp_ratio(perm), perm_col)
			var right: PanelContainer = skill_block(ui, id, "run", run_line(ui, id, perm, runx), xp_ratio(perm + runx), run_col)
			row.add_child(left)
			row.add_child(right)
			ui.box.add_child(row)
			if first == null:
				first = left
	else:
		for id: String in App.prog.SKILLS:
			var perm2: float = float(App.prog.skills_perm.get(id, 0.0))
			var row2: PanelContainer = skill_block(ui, id, "perm", perm_line(ui, id, perm2), xp_ratio(perm2), perm_col)
			ui.box.add_child(row2)
			if first == null:
				first = row2
	if first:
		ui.focus_btn = first
	ui.box.add_child(ThemeS.btn("Close  (B)", ui.close_ui))
