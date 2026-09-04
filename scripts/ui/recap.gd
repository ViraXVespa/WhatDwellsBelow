extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const RecapBars := preload("res://scripts/ui/recap_bars.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

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
	PromptView.footer(self, [{"action": "ui_accept", "verb": "continue"}])
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
	heads.add_child(RecapBars.skill_lab("Permanent XP", 18, Color(0.95, 0.8, 0.45)))
	head_right = RecapBars.skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45))
	heads.add_child(head_right)
	box.add_child(heads)
	skill_labs.clear()
	rows.clear()
	var first: Control = null
	for id in App.prog.SKILLS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 24)
		var perm_block := RecapBars.make_block(self, id, "perm")
		var run_block := RecapBars.make_block(self, id, "run")
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
	var cont := ThemeS.btn("Continue", func(): _finish())
	cont.set_meta("recap_continue", true)
	cont.disabled = true
	box.add_child(cont)
	focus_btn = first if first else cont
	_refresh_skills()
	call_deferred("_focus")


func _blur_tip() -> void:
	RecapBars.blur_tip(self)


func _hide_tip() -> void:
	RecapBars.hide_tip(self)


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


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
			shown[id] = move_toward(cur, 0.0, RecapBars.xfer_speed(self, id, cur) * delta)
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
		if n is Button and bool(n.get_meta("recap_continue", false)):
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
	RecapBars.refresh(self)


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
