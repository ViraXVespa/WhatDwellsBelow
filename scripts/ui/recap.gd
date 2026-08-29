extends CanvasLayer

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

var open := false
var box: VBoxContainer
var scroll: ScrollContainer
var draining := false
var applied := false
var shown: Dictionary = {}
var targets: Dictionary = {}
var perm0: Dictionary = {}
var run0: Dictionary = {}
var keep0: Dictionary = {}
var gain_now: Dictionary = {}
var rows: Dictionary = {}
var focus_btn: Control
var flavor: Label
var mailed_lab: Label
var head_right: Label
var skill_labs: Dictionary = {}
var last_title := ""
var tip_host: PanelContainer
var tip_lab: Label
var tip_id := ""
var tip_kind := ""
var tip_from: Control = null


func _ready() -> void:
	layer = 70
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.03, 0.92)
	add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.09, 0.07, 0.96)
	panel.position = Vector2(220, 40)
	panel.size = Vector2(1480, 1000)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(220, 40)
	edge.size = Vector2(1480, 8)
	add_child(edge)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(244, 72)
	scroll.size = Vector2(1432, 940)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.follow_focus = true
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1400, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_make_tip()


func _make_tip() -> void:
	tip_host = PanelContainer.new()
	tip_host.visible = false
	tip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_host.z_index = 20
	tip_host.add_theme_stylebox_override("panel", ThemeS.sb(Color(0.09, 0.07, 0.05, 0.97), Color(0.85, 0.68, 0.32)))
	tip_lab = Label.new()
	tip_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lab.custom_minimum_size = Vector2(380, 0)
	tip_lab.add_theme_font_size_override("font_size", 18)
	tip_lab.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	tip_lab.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	tip_lab.add_theme_constant_override("outline_size", 6)
	tip_host.add_child(tip_lab)
	add_child(tip_host)


func play(cond: String) -> void:
	open = true
	visible = true
	draining = true
	applied = false
	App.ui_open = true
	get_tree().paused = true
	shown.clear()
	targets.clear()
	perm0.clear()
	run0.clear()
	keep0.clear()
	gain_now.clear()
	rows.clear()
	skill_labs.clear()
	head_right = null
	_hide_tip()
	var keep: float = App.bal.xp_keep
	for id in App.prog.SKILLS:
		var runx := float(App.prog.skills_run.get(id, 0.0))
		var perm := float(App.prog.skills_perm.get(id, 0.0))
		run0[id] = runx
		perm0[id] = perm
		keep0[id] = runx * keep
		shown[id] = runx
		targets[id] = 0.0
		gain_now[id] = 0.0
	_rebuild(cond)
	set_process(true)


func _rebuild(cond: String) -> void:
	for c in box.get_children():
		c.queue_free()
	var title := "The depths keep their due."
	var sub := "A fragment remains."
	var empty := App.prog.bag_count() == 0 and App.gold <= 0 and App.ore <= 0 and App.wood <= 0
	var verge := (not App.extracted) and (App.boss_low or App.saw_stairs)
	if App.floor_n <= 1 and empty:
		title = "They lived just to die. What a waste."
		sub = "Floor 1. Empty-handed."
	elif cond == "dispel":
		title = "“Dispel”"
		sub = "A verge of success." if verge else "You chose the surface."
	elif App.extracted:
		title = "Some of it reached daylight."
		sub = "The guild will keep it."
	elif verge:
		title = "So close."
		sub = "A verge of success."
	elif App.floor_n >= 5:
		title = "Deep enough to matter."
		sub = "The Gate remembers."
	last_title = title
	box.add_child(ThemeS.lab(title, 32, Color(0.95, 0.82, 0.5)))
	box.add_child(ThemeS.lab(sub, 22, Color(0.82, 0.76, 0.66)))
	var end_n := "“Dispel”" if cond == "dispel" else ("Death" if cond == "death" else cond)
	box.add_child(ThemeS.lab("End: %s   Floor F%d" % [end_n, App.floor_n], 18, Color(0.8, 0.75, 0.65)))
	var dur := 0
	var kills := 0
	if App.tel:
		dur = int(App.tel.duration)
		kills = int(App.tel.kills)
	box.add_child(ThemeS.lab("Run  %ds  ·  %d kills  ·  %s  ·  %s  ·  %s" % [dur, kills, App.weapon, App.prog.tool_type, App.character_type], 18, Color(0.82, 0.76, 0.66)))
	box.add_child(ThemeS.lab("Carried  %dg  %d ore  %d wood  ·  bag %d" % [App.gold, App.ore, App.wood, App.prog.bag_count()], 18, Color(0.82, 0.76, 0.66)))
	flavor = ThemeS.lab("XP draining…", 18, Color(0.9, 0.84, 0.7))
	box.add_child(flavor)
	var heads := HBoxContainer.new()
	heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_theme_constant_override("separation", 24)
	heads.add_child(_skill_lab("Permanent XP", 18, Color(0.95, 0.8, 0.45)))
	head_right = _skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45))
	heads.add_child(head_right)
	box.add_child(heads)
	skill_labs.clear()
	rows.clear()
	var first: Control = null
	for id in App.prog.SKILLS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 24)
		var perm_block := _make_block(id, "perm")
		var run_block := _make_block(id, "run")
		row.add_child(perm_block.wrap)
		row.add_child(run_block.wrap)
		box.add_child(row)
		rows[id] = {
			"perm_lab": perm_block.lab,
			"perm_base": perm_block.base,
			"perm_gain": perm_block.gain,
			"run_lab": run_block.lab,
			"run_fill": run_block.base,
		}
		skill_labs[id] = perm_block.lab
		if first == null:
			first = perm_block.wrap
	mailed_lab = ThemeS.lab("", 18, Color(0.78, 0.86, 0.7))
	box.add_child(mailed_lab)
	var cont := ThemeS.btn("Continue  (A)", func(): _finish())
	cont.disabled = true
	box.add_child(cont)
	focus_btn = first if first else cont
	_refresh_skills()
	call_deferred("_focus")


func _make_block(id: String, kind: String) -> Dictionary:
	var wrap := ThemeS.skill_row()
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	var lab := _skill_lab("", 16, Color(0.9, 0.84, 0.7))
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
	wrap.focus_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.mouse_entered.connect(_on_skill_focus.bind(id, kind, wrap))
	wrap.focus_exited.connect(_on_skill_blur.bind(wrap))
	wrap.mouse_exited.connect(_on_skill_blur.bind(wrap))
	return {"wrap": wrap, "lab": lab, "base": base, "gain": gain}


func _on_skill_focus(id: String, kind: String, from: Control) -> void:
	if from is PanelContainer:
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(true))
	tip_id = id
	tip_kind = kind
	tip_from = from
	_paint_tip()


func _on_skill_blur(from: Control) -> void:
	if from is PanelContainer and not from.has_focus():
		(from as PanelContainer).add_theme_stylebox_override("panel", ThemeS.skill_row_sb(false))
	call_deferred("_blur_tip")


func _skill_lab(text: String, size := 16, col := Color(0.9, 0.84, 0.7)) -> Label:
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


func _blur_tip() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and f.has_meta("skill_id"):
		return
	_hide_tip()


func _hide_tip() -> void:
	tip_id = ""
	tip_kind = ""
	tip_from = null
	if tip_host:
		tip_host.visible = false


func _tip_lv(id: String, kind: String) -> int:
	var start := float(perm0.get(id, 0.0))
	if kind == "run":
		if applied:
			return _xp_lv(start)
		return _xp_lv(start + float(shown.get(id, 0.0)))
	return _xp_lv(start + float(gain_now.get(id, 0.0)))


func _paint_tip() -> void:
	if tip_id == "" or tip_from == null or not is_instance_valid(tip_from):
		if tip_host:
			tip_host.visible = false
		return
	tip_lab.text = ThemeS.skill_tip(tip_id, _tip_lv(tip_id, tip_kind))
	var w := 404.0
	tip_lab.custom_minimum_size = Vector2(w - 24.0, 0.0)
	var h := maxf(80.0, tip_lab.get_minimum_size().y + 20.0)
	tip_host.size = Vector2(w, h)
	var r := tip_from.get_global_rect()
	var pos := Vector2(r.position.x, r.position.y + r.size.y + 8.0)
	if pos.y + h > 1060.0:
		pos.y = r.position.y - h - 8.0
	if pos.x + w > 1900.0:
		pos.x = 1900.0 - w
	if pos.x < 20.0:
		pos.x = 20.0
	tip_host.position = pos
	tip_host.visible = true


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _xp_span() -> float:
	return maxf(1.0, App.bal.xp_level)


func _xp_lv(total: float) -> int:
	return 1 + int(total / _xp_span())


func _xp_to_next(total: float) -> int:
	var span := _xp_span()
	var into := fmod(total, span)
	if into <= 0.0001:
		return int(round(span))
	return int(round(span - into))


func _skill_title(id: String) -> String:
	return str(SKILL_NAMES.get(id, id))


func _set_span(fill: ColorRect, left_r: float, right_r: float) -> void:
	fill.anchor_left = clampf(left_r, 0.0, 1.0)
	fill.anchor_right = clampf(right_r, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_right = 0.0


func _perm_ratios(start_xp: float, gain: float) -> Vector2:
	var span := _xp_span()
	var total := start_xp + gain
	var into := fmod(total, span)
	var start_lv := _xp_lv(start_xp)
	var now_lv := _xp_lv(total)
	if now_lv > start_lv:
		return Vector2(0.0, clampf(into / span, 0.0, 1.0))
	var base_into := fmod(start_xp, span)
	var base_r := clampf(base_into / span, 0.0, 1.0)
	var gain_r := clampf((into - base_into) / span, 0.0, 1.0)
	return Vector2(base_r, gain_r)


func _xfer_speed(id: String, rem: float) -> float:
	var start := float(run0.get(id, 0.0))
	var peak := maxf(8.0, start * 1.8)
	if start <= 0.0001:
		return peak
	var p := clampf(1.0 - rem / start, 0.0, 1.0)
	return 8.0 + (peak - 8.0) * sin(PI * p)


func _mark_starting() -> void:
	if head_right:
		head_right.text = "Starting XP"


func _process(delta: float) -> void:
	if not draining:
		return
	var left := false
	for id in App.prog.SKILLS:
		var cur := float(shown.get(id, 0.0))
		var start := float(run0.get(id, 0.0))
		if cur > 0.2:
			shown[id] = move_toward(cur, 0.0, _xfer_speed(id, cur) * delta)
			left = true
		else:
			shown[id] = 0.0
		if start > 0.0001:
			gain_now[id] = float(keep0.get(id, 0.0)) * (1.0 - float(shown[id]) / start)
		else:
			gain_now[id] = float(keep0.get(id, 0.0))
	if not left:
		draining = false
		_lock_totals()
		_mark_starting()
		_refresh_skills()
		if flavor:
			flavor.text = "Permanent totals locked in."
		if mailed_lab:
			mailed_lab.text = _mailed_line()
		var cont := _continue_btn()
		if cont:
			cont.disabled = false
			cont.grab_focus()
	else:
		_refresh_skills()


func _continue_btn() -> Button:
	for n in box.get_children():
		if n is Button and (n as Button).text.begins_with("Continue"):
			return n
	return null


func _lock_totals() -> void:
	if applied:
		return
	applied = true
	for id in App.prog.SKILLS:
		shown[id] = 0.0
		gain_now[id] = float(keep0.get(id, 0.0))
	App.prog.keep_fragments()
	App.save_now()
	if App.tel:
		App.tel.recap_drain = true


func _refresh_skills() -> void:
	for id in rows.keys():
		var rec: Dictionary = rows[id]
		var start := float(perm0.get(id, 0.0))
		var run_left := float(shown.get(id, 0.0))
		var gain := float(gain_now.get(id, 0.0))
		var perm_total := start + gain
		var run_total := start + run_left
		(rec.perm_lab as Label).text = "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
			_skill_title(id),
			_xp_lv(perm_total),
			_xp_to_next(perm_total),
			int(round(perm_total)),
		]
		if applied:
			(rec.run_lab as Label).text = "%s Lv %d | Next Level: %dXP | Total XP: %dXP" % [
				_skill_title(id),
				_xp_lv(start),
				_xp_to_next(start),
				int(round(start)),
			]
		else:
			(rec.run_lab as Label).text = "%s Lv %d | This Run: %dXP | Next Level: %dXP" % [
				_skill_title(id),
				_xp_lv(run_total),
				int(round(run_left)),
				_xp_to_next(run_total),
			]
		var pr := _perm_ratios(start, gain)
		_set_span(rec.perm_base, 0.0, pr.x)
		_set_span(rec.perm_gain, pr.x, pr.x + pr.y)
		(rec.perm_base as ColorRect).color = COL_PERM
		(rec.perm_gain as ColorRect).color = COL_GAIN
		var span := _xp_span()
		var run_r := clampf(fmod(run_total, span) / span, 0.0, 1.0)
		_set_span(rec.run_fill, 0.0, run_r)
		(rec.run_fill as ColorRect).color = COL_DUNGEON
	if tip_id != "":
		_paint_tip()


func _mailed_line() -> String:
	var g := int(App.prog.mailed_gold)
	var o := int(App.prog.mailed_ore)
	var w := int(App.prog.mailed_wood)
	var r := int(App.prog.mailed_root)
	var names: PackedStringArray = App.prog.mailed_names
	if g + o + w + r + names.size() <= 0:
		return "Nothing reached the surface."
	var bits: PackedStringArray = PackedStringArray()
	if g > 0:
		bits.append("%dg" % g)
	if o > 0:
		bits.append("%d ore" % o)
	if w > 0:
		bits.append("%d wood" % w)
	if r > 0:
		bits.append("%d root" % r)
	if names.size() > 0:
		bits.append(", ".join(names))
	return "Extracted: " + ", ".join(bits)


func skip_drain() -> void:
	for id in App.prog.SKILLS:
		shown[id] = 0.0
		gain_now[id] = float(keep0.get(id, 0.0))
	draining = false
	_lock_totals()
	_mark_starting()
	_refresh_skills()
	if flavor:
		flavor.text = "Permanent totals locked in."
	if mailed_lab:
		mailed_lab.text = _mailed_line()
	var cont := _continue_btn()
	if cont:
		cont.disabled = false


func _finish() -> void:
	if draining:
		return
	_hide_tip()
	open = false
	visible = false
	App.ui_open = false
	get_tree().paused = false
	set_process(false)
	App.prog.lose_unextracted()
	if App.playtest and App.playtest.has_method("consume_recap") and App.playtest.consume_recap():
		return
	App.wake_pending = true
	App.go_camp()


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_accept") and not draining:
		_finish()
		get_viewport().set_input_as_handled()