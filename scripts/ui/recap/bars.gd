extends Object
const CombatP := preload("res://scripts/data/progress_combat.gd")

const ThemeS := preload("res://scripts/ui/theme.gd")
const LocS := preload("res://scripts/app/app_loc.gd")
const SkillRow := preload("res://scripts/ui/skill_row_view.gd")
const TipHover := preload("res://scripts/ui/tip_hover.gd")
const Journal: GDScript = preload("res://scripts/ui/pause_menu/journal_page.gd")

const COL_PERM := Color(0.72, 0.56, 0.28)
const COL_GAIN := Color(0.46, 0.78, 0.42)
const COL_DUNGEON := Color(0.86, 0.74, 0.32)

static func skill_title(id: String) -> String:
	return LocS.tr_or("skill." + id, id)

static func skill_lab(text: String, size: int = 16, col: Color = ThemeS.INK) -> Label:
	return SkillRow.skill_lab(text, size, col)

static func make_block(host: Node, id: String, kind: String) -> Dictionary:
	var shell := ThemeS.skill_row()
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	var lab := skill_lab("", 16, ThemeS.INK)
	inner.add_child(lab)
	var track := SkillRow.make_track()
	inner.add_child(track)
	var base := ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.color = COL_PERM
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.anchor_right = 0.0
	base.offset_left = 0.0
	base.offset_top = 0.0
	base.offset_right = 0.0
	base.offset_bottom = 0.0
	track.add_child(base)
	var gain := ColorRect.new()
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain.color = COL_GAIN
	gain.set_anchors_preset(Control.PRESET_FULL_RECT)
	gain.anchor_left = 0.0
	gain.anchor_right = 0.0
	gain.offset_left = 0.0
	gain.offset_top = 0.0
	gain.offset_right = 0.0
	gain.offset_bottom = 0.0
	track.add_child(gain)
	shell.add_child(inner)
	shell.set_meta("skill_id", id)
	shell.set_meta("skill_kind", kind)
	TipHover.attach(shell, host, id, kind, paint_tip, _hl)
	_hl(shell, false)
	return {"wrap": shell, "lab": lab, "base": base, "gain": gain}

static func _hl(row: Control, on: bool) -> void:
	SkillRow.hl(row, on)
	if not row is PanelContainer:
		return
	var sb: StyleBox = (row as PanelContainer).get_theme_stylebox("panel")
	if not sb is StyleBoxFlat:
		return
	var flat: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
	flat.content_margin_top = 4
	flat.content_margin_bottom = 4
	(row as PanelContainer).add_theme_stylebox_override("panel", flat)

static func tip_lv(host: Node, id: String, kind: String) -> int:
	var start := float(host.perm0.get(id, 0.0))
	if kind == "run":
		if host.applied:
			return CombatP.level_from_xp(App.prog, start)
		return CombatP.level_from_xp(App.prog, start + float(host.shown.get(id, 0.0)))
	return CombatP.level_from_xp(App.prog, start + float(host.gain_now.get(id, 0.0)))

static func paint_tip(host: Node) -> void:
	if not TipHover.live(host):
		return
	var sheet: Rect2 = host.tip_sheet
	if sheet.size.x < 8.0:
		return
	host.tip_lab.text = ThemeS.skill_tip(host.tip_id, tip_lv(host, host.tip_id, host.tip_kind))
	host.tip_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host.tip_lab.add_theme_font_override("font", ThemeS.ink_font())
	host.tip_lab.add_theme_constant_override("outline_size", 0)
	var w: float = sheet.size.x - 36.0
	host.tip_lab.custom_minimum_size = Vector2(w - 28.0, 0.0)
	var h: float = maxf(120.0, host.tip_lab.get_minimum_size().y + 28.0)
	host.tip_host.position = Vector2(sheet.position.x + 18.0, sheet.position.y + Journal.TEXT_DROP + 8.0)
	host.tip_host.size = Vector2(w, h)
	host.tip_host.visible = true
	host.tip_host.z_index = 4

static func set_span(fill: ColorRect, left_r: float, right_r: float) -> void:
	fill.anchor_left = clampf(left_r, 0.0, 1.0)
	fill.anchor_right = clampf(right_r, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_right = 0.0

static func perm_ratios(start_xp: float, gain: float) -> Vector2:
	var total := start_xp + gain
	var start_lv := CombatP.level_from_xp(App.prog, start_xp)
	var now_lv := CombatP.level_from_xp(App.prog, total)
	var into := CombatP.xp_ratio(App.prog, total)
	if now_lv > start_lv:
		return Vector2(0.0, into)
	var base_r := CombatP.xp_ratio(App.prog, start_xp)
	return Vector2(base_r, clampf(into - base_r, 0.0, 1.0))

static func xfer_speed(host: Node, id: String, rem: float) -> float:
	var start := float(host.run0.get(id, 0.0))
	var peak := maxf(8.0, start * 1.8)
	if start <= 0.0001:
		return peak
	var p := clampf(1.0 - rem / start, 0.0, 1.0)
	return 8.0 + (peak - 8.0) * sin(PI * p)

static func refresh(host: Node) -> void:
	for id in host.rows.keys():
		var rec: Dictionary = host.rows[id]
		var start := float(host.perm0.get(id, 0.0))
		var run_left := float(host.shown.get(id, 0.0))
		var gain := float(host.gain_now.get(id, 0.0))
		var perm_total := start + gain
		var run_total := start + run_left
		(rec.perm_lab as Label).text = App.tr("common.lv_next_level_xp_total") % [
			skill_title(id),
			CombatP.level_from_xp(App.prog, perm_total),
			int(round(CombatP.xp_to_next(App.prog, perm_total))),
			int(round(perm_total)),
		]
		if host.applied:
			(rec.run_lab as Label).text = App.tr("common.lv_next_level_xp_total") % [
				skill_title(id),
				CombatP.level_from_xp(App.prog, start),
				int(round(CombatP.xp_to_next(App.prog, start))),
				int(round(start)),
			]
		else:
			(rec.run_lab as Label).text = App.tr("common.lv_this_run_xp_next") % [
				skill_title(id),
				CombatP.level_from_xp(App.prog, run_total),
				int(round(run_left)),
				int(round(CombatP.xp_to_next(App.prog, run_total))),
			]
		var pr := perm_ratios(start, gain)
		set_span(rec.perm_base, 0.0, pr.x)
		set_span(rec.perm_gain, pr.x, pr.x + pr.y)
		(rec.perm_base as ColorRect).color = COL_PERM
		(rec.perm_gain as ColorRect).color = COL_GAIN
		var run_r := CombatP.xp_ratio(App.prog, run_total)
		set_span(rec.run_fill, 0.0, run_r)
		(rec.run_fill as ColorRect).color = COL_DUNGEON
	if host.tip_id != "":
		paint_tip(host)
