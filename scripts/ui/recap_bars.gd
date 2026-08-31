extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")

const SKILL_NAMES := {
	"axe": "Great Axe",
	"staff": "Staff",
	"bow": "Longbow",
	"str": "Strength",
	"mag": "Magic",
	"rng": "Ranged",
	"def": "Defense",
	"hp": "Hitpoints",
	"mine": "Mining",
	"wood": "Woodcutting",
	"smith": "Smithing",
}

const COL_PERM := Color(0.72, 0.56, 0.28)
const COL_GAIN := Color(0.46, 0.78, 0.42)
const COL_DUNGEON := Color(0.86, 0.74, 0.32)
const COL_TRACK := Color(0.18, 0.14, 0.1)


static func skill_title(id: String) -> String:
	return str(SKILL_NAMES.get(id, id))


static func skill_lab(text: String, size := 16, col := Color(0.9, 0.84, 0.7)) -> Label:
	var l := Label.new()
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


static func make_block(host: Node, id: String, kind: String) -> Dictionary:
	var wrap := ThemeS.skill_row()
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	var lab := skill_lab("", 16, Color(0.9, 0.84, 0.7))
	inner.add_child(lab)
	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, 16)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = COL_TRACK
	track.clip_contents = true
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
	wrap.add_child(inner)
	wrap.set_meta("skill_id", id)
	wrap.set_meta("skill_kind", kind)
	wrap.focus_entered.connect(func(): on_skill_focus(host, id, kind, wrap))
	wrap.mouse_entered.connect(func(): on_skill_focus(host, id, kind, wrap))
	wrap.focus_exited.connect(func(): on_skill_blur(host, wrap))
	wrap.mouse_exited.connect(func(): on_skill_blur(host, wrap))
	return {"wrap": wrap, "lab": lab, "base": base, "gain": gain}


static func on_skill_focus(host: Node, id: String, kind: String, from: Control) -> void:
	if from is PanelContainer:
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(true))
	host.tip_id = id
	host.tip_kind = kind
	host.tip_from = from
	paint_tip(host)


static func on_skill_blur(host: Node, from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	host.call_deferred("_blur_tip")


static func blur_tip(host: Node) -> void:
	var f := host.get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	hide_tip(host)


static func hide_tip(host: Node) -> void:
	host.tip_id = ""
	host.tip_kind = ""
	host.tip_from = null
	if host.tip_host:
		host.tip_host.visible = false


static func tip_lv(host: Node, id: String, kind: String) -> int:
	var start := float(host.perm0.get(id, 0.0))
	if kind == "run":
		if host.applied:
			return xp_lv(start)
		return xp_lv(start + float(host.shown.get(id, 0.0)))
	return xp_lv(start + float(host.gain_now.get(id, 0.0)))


static func paint_tip(host: Node) -> void:
	if host.tip_id == "" or host.tip_from == null or not is_instance_valid(host.tip_from):
		if host.tip_host:
			host.tip_host.visible = false
		return
	host.tip_lab.text = ThemeS.skill_tip(host.tip_id, tip_lv(host, host.tip_id, host.tip_kind))
	var w := 404.0
	host.tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h := maxf(80.0, host.tip_lab.get_minimum_size().y + 20.0)
	host.tip_host.size = Vector2(w, h)
	var r := host.tip_from.get_global_rect()
	var pos := Vector2(r.position.x, r.position.y + r.size.y + 8.0)
	if pos.y + h > 1060.0:
		pos.y = r.position.y - h - 8.0
	if pos.x + w > 1900.0:
		pos.x = 1900.0 - w
	if pos.x < 20.0:
		pos.x = 20.0
	host.tip_host.position = pos
	host.tip_host.visible = true


static func xp_lv(total: float) -> int:
	return App.prog.level_from_xp(total)


static func xp_to_next(total: float) -> int:
	return int(round(App.prog.xp_to_next(total)))


static func set_span(fill: ColorRect, left_r: float, right_r: float) -> void:
	fill.anchor_left = clampf(left_r, 0.0, 1.0)
	fill.anchor_right = clampf(right_r, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_right = 0.0


static func perm_ratios(start_xp: float, gain: float) -> Vector2:
	var total := start_xp + gain
	var start_lv := xp_lv(start_xp)
	var now_lv := xp_lv(total)
	var into := App.prog.xp_ratio(total)
	if now_lv > start_lv:
		return Vector2(0.0, into)
	var base_r := App.prog.xp_ratio(start_xp)
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
		(rec.perm_lab as Label).text = "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
			skill_title(id),
			xp_lv(perm_total),
			xp_to_next(perm_total),
			int(round(perm_total)),
		]
		if host.applied:
			(rec.run_lab as Label).text = "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
				skill_title(id),
				xp_lv(start),
				xp_to_next(start),
				int(round(start)),
			]
		else:
			(rec.run_lab as Label).text = "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
				skill_title(id),
				xp_lv(run_total),
				int(round(run_left)),
				xp_to_next(run_total),
			]
		var pr := perm_ratios(start, gain)
		set_span(rec.perm_base, 0.0, pr.x)
		set_span(rec.perm_gain, pr.x, pr.x + pr.y)
		(rec.perm_base as ColorRect).color = COL_PERM
		(rec.perm_gain as ColorRect).color = COL_GAIN
		var run_r := App.prog.xp_ratio(run_total)
		set_span(rec.run_fill, 0.0, run_r)
		(rec.run_fill as ColorRect).color = COL_DUNGEON
	if host.tip_id != "":
		paint_tip(host)
