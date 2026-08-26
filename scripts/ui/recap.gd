extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")

var open := false
var box: VBoxContainer
var draining := false
var shown: Dictionary = {}
var targets: Dictionary = {}
var focus_btn: Button
var flavor: Label
var mailed_lab: Label
var skill_labs: Dictionary = {}
var last_title := ""


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
	panel.position = Vector2(360, 80)
	panel.size = Vector2(1200, 920)
	add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.position = Vector2(360, 80)
	edge.size = Vector2(1200, 8)
	add_child(edge)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(392, 112)
	scroll.size = Vector2(1136, 856)
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)


func play(cond: String) -> void:
	open = true
	visible = true
	draining = true
	App.ui_open = true
	get_tree().paused = true
	shown.clear()
	targets.clear()
	var keep: float = App.bal.xp_keep
	for id in App.prog.SKILLS:
		shown[id] = float(App.prog.skills_run.get(id, 0.0))
		targets[id] = float(App.prog.skills_run.get(id, 0.0)) * keep
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
	skill_labs.clear()
	for id in App.prog.SKILLS:
		var l := ThemeS.lab(_line(id), 18, Color(0.88, 0.82, 0.7))
		skill_labs[id] = l
		box.add_child(l)
	mailed_lab = ThemeS.lab("", 18, Color(0.78, 0.86, 0.7))
	box.add_child(mailed_lab)
	focus_btn = ThemeS.btn("Continue  (A)", func(): _finish())
	focus_btn.disabled = true
	box.add_child(focus_btn)
	call_deferred("_focus")


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _process(delta: float) -> void:
	if not draining:
		return
	var left := false
	for id in App.prog.SKILLS:
		var cur := float(shown[id])
		var tgt := float(targets[id])
		if cur > tgt + 0.2:
			shown[id] = move_toward(cur, tgt, maxf(8.0, cur * 1.8) * delta)
			left = true
	if not left:
		draining = false
		App.prog.keep_fragments()
		App.tel.recap_drain = true
		_refresh_skills()
		if flavor:
			flavor.text = "Permanent totals locked in."
		if mailed_lab:
			mailed_lab.text = _mailed_line()
		if focus_btn:
			focus_btn.disabled = false
			focus_btn.grab_focus()
	else:
		_refresh_skills()


func _line(id: String) -> String:
	return "%s   run %.0f  →  keep %.0f   perm %.0f   lv %d" % [id, shown[id], targets[id], App.prog.skills_perm.get(id, 0.0), App.prog.skill_lv(id)]


func _refresh_skills() -> void:
	for id in skill_labs.keys():
		(skill_labs[id] as Label).text = _line(id)


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
		shown[id] = float(targets[id])
	draining = false
	App.prog.keep_fragments()
	App.tel.recap_drain = true
	_refresh_skills()
	if flavor:
		flavor.text = "Permanent totals locked in."
	if mailed_lab:
		mailed_lab.text = _mailed_line()
	if focus_btn:
		focus_btn.disabled = false


func _finish() -> void:
	if draining:
		return
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
