extends Object

## Recap content rebuild after a run ends.

const ThemeS := preload("res://scripts/ui/theme.gd")
const RecapBars := preload("res://scripts/ui/recap/bars.gd")

static func rebuild(host: CanvasLayer, cond: String) -> void:
	for c in host.box.get_children():
		c.queue_free()
	var title := App.tr("rebuild.the_depths_keep_their_due")
	var sub := App.tr("rebuild.a_fragment_remains")
	var empty := App.prog.bag_count() == 0 and App.gold <= 0 and App.ore <= 0 and App.wood <= 0
	var verge := (not App.extracted) and (App.boss_low or App.saw_stairs)
	if App.floor_n <= 1 and empty:
		title = App.tr("rebuild.they_lived_just_to_die")
		sub = App.tr("rebuild.floor_1_empty_handed")
	elif cond == "dispel":
		title = App.tr("rebuild.dispel")
		sub = App.tr("common.a_verge_of_success") if verge else App.tr("rebuild.you_chose_the_surface")
	elif App.extracted:
		title = App.tr("rebuild.some_of_it_reached_daylight")
		sub = App.tr("rebuild.the_guild_will_keep_it")
	elif verge:
		title = App.tr("rebuild.so_close")
		sub = App.tr("common.a_verge_of_success")
	elif App.floor_n >= 5:
		title = App.tr("rebuild.deep_enough_to_matter")
		sub = App.tr("rebuild.the_gate_remembers")
	host.last_title = title
	host.box.add_child(ThemeS.lab(title, 32, ThemeS.INK))
	host.box.add_child(ThemeS.lab(sub, 22, Color(0.82, 0.76, 0.66)))
	var end_n := "“Dispel”" if cond == "dispel" else ("Death" if cond == "death" else cond)
	host.box.add_child(ThemeS.lab(App.tr("rebuild.end_floor_f") % [end_n, App.floor_n], 18, Color(0.8, 0.75, 0.65)))
	var dur := 0
	var kills := 0
	if App.tel:
		dur = int(App.tel.duration)
		kills = int(App.tel.kills)
	host.box.add_child(ThemeS.lab(App.tr("rebuild.run_s_kills") % [dur, kills, App.weapon, App.prog.tool_type, App.character_type], 18, Color(0.82, 0.76, 0.66)))
	host.box.add_child(ThemeS.lab(App.tr("rebuild.carried_g_ore_wood_bag") % [App.gold, App.ore, App.wood, App.prog.bag_count()], 18, Color(0.82, 0.76, 0.66)))
	host.flavor = ThemeS.lab(App.tr("rebuild.xp_host_draining"), 18, ThemeS.INK_SOFT)
	host.box.add_child(host.flavor)
	var heads := HBoxContainer.new()
	heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_theme_constant_override("separation", 24)
	heads.add_child(RecapBars.skill_lab(App.tr("rebuild.permanent_xp"), 18, ThemeS.INK))
	host.head_right = RecapBars.skill_lab(App.tr("common.dungeon_xp"), 18, ThemeS.INK)
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
	host.mailed_lab = ThemeS.lab("", 18, Color(0.16, 0.38, 0.16))
	host.box.add_child(host.mailed_lab)
	var cont := ThemeS.btn(App.tr("common.continue"), func(): host._finish(), true, "primary")
	cont.set_meta("recap_continue", true)
	cont.disabled = true
	host.box.add_child(cont)
	host.focus_btn = first if first else cont
	RecapBars.refresh(host)
	host.call_deferred("_focus")
