extends Object

## Recap content rebuild after a run ends.

const ThemeS := preload("res://scripts/ui/theme.gd")
const RecapBars := preload("res://scripts/ui/recap_bars.gd")


static func rebuild(host: CanvasLayer, cond: String) -> void:
	for c in host.box.get_children():
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
	host.last_title = title
	host.box.add_child(ThemeS.lab(title, 32, Color(0.95, 0.82, 0.5)))
	host.box.add_child(ThemeS.lab(sub, 22, Color(0.82, 0.76, 0.66)))
	var end_n := "“Dispel”" if cond == "dispel" else ("Death" if cond == "death" else cond)
	host.box.add_child(ThemeS.lab("End: %s   Floor F%d" % [end_n, App.floor_n], 18, Color(0.8, 0.75, 0.65)))
	var dur := 0
	var kills := 0
	if App.tel:
		dur = int(App.tel.duration)
		kills = int(App.tel.kills)
	host.box.add_child(ThemeS.lab("Run  %ds  ·  %d kills  ·  %s  ·  %s  ·  %s" % [dur, kills, App.weapon, App.prog.tool_type, App.character_type], 18, Color(0.82, 0.76, 0.66)))
	host.box.add_child(ThemeS.lab("Carried  %dg  %d ore  %d wood  ·  bag %d" % [App.gold, App.ore, App.wood, App.prog.bag_count()], 18, Color(0.82, 0.76, 0.66)))
	host.flavor = ThemeS.lab("XP host.draining…", 18, Color(0.9, 0.84, 0.7))
	host.box.add_child(host.flavor)
	var heads := HBoxContainer.new()
	heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_theme_constant_override("separation", 24)
	heads.add_child(RecapBars.skill_lab("Permanent XP", 18, Color(0.95, 0.8, 0.45)))
	host.head_right = RecapBars.skill_lab("Dungeon XP", 18, Color(0.95, 0.8, 0.45))
	heads.add_child(host.head_right)
	host.box.add_child(heads)
	host.skill_labs.clear()
	host.rows.clear()
	var first: Control = null
	for id in App.prog.SKILLS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 24)
		var perm_block := RecapBars.make_block(host, id, "perm")
		var run_block := RecapBars.make_block(host, id, "run")
		row.add_child(perm_block.wrap)
		row.add_child(run_block.wrap)
		host.box.add_child(row)
		host.rows[id] = {
			"perm_lab": perm_block.lab,
			"perm_base": perm_block.base,
			"perm_gain": perm_block.gain,
			"run_lab": run_block.lab,
			"run_fill": run_block.base,
		}
		host.skill_labs[id] = perm_block.lab
		if first == null:
			first = perm_block.wrap
	host.mailed_lab = ThemeS.lab("", 18, Color(0.78, 0.86, 0.7))
	host.box.add_child(host.mailed_lab)
	var cont := ThemeS.btn("Continue", func(): host._finish())
	cont.set_meta("recap_continue", true)
	cont.disabled = true
	host.box.add_child(cont)
	host.focus_btn = first if first else cont
	RecapBars.refresh(host)
	host.call_deferred("_focus")