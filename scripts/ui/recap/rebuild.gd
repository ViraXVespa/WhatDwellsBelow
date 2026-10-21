extends Object

## Recap content rebuild after a run ends.

const ThemeS := preload("res://scripts/ui/theme.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
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
	_header(host)
	_line(host, title, 32, ThemeS.INK)
	_line(host, sub, 22, ThemeS.INK_SOFT)
	var end_n := "“Dispel”" if cond == "dispel" else ("Death" if cond == "death" else cond)
	_line(host, App.tr("rebuild.end_floor_f") % [end_n, App.floor_n], 18, ThemeS.INK)
	var dur := 0
	var kills := 0
	if App.tel:
		dur = int(App.tel.duration)
		kills = int(App.tel.kills)
	_line(host, App.tr("rebuild.run_s_kills") % [dur, kills, App.weapon, App.prog.tool_type, App.character_type], 18, ThemeS.INK)
	_line(host, App.tr("rebuild.carried_g_ore_wood_bag") % [App.gold, App.ore, App.wood, App.prog.bag_count()], 18, ThemeS.INK)
	host.flavor = _line(host, App.tr("rebuild.xp_host_draining"), 18, ThemeS.INK_SOFT)
	var heads: HBoxContainer = HBoxContainer.new()
	heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_theme_constant_override("separation", 24)
	heads.custom_minimum_size = Vector2(host.sheet_rect.size.x, 0.0)
	var head_left: Label = RecapBars.skill_lab(App.tr("rebuild.permanent_xp"), 18, ThemeS.INK)
	head_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_child(head_left)
	host.head_right = RecapBars.skill_lab(App.tr("common.dungeon_xp"), 18, ThemeS.INK)
	host.head_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_child(host.head_right)
	host.header.add_child(heads)
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
	_footer(host)
	host.mailed_lab = ThemeS.lab("", 18, Color(0.16, 0.38, 0.16))
	host.mailed_lab.custom_minimum_size = Vector2(host.sheet_rect.size.x, 0.0)
	host.footer.add_child(host.mailed_lab)
	var cont: Button = ThemeS.btn(App.tr("common.continue"), func(): host._finish(), true, "primary")
	cont.set_meta("recap_continue", true)
	cont.disabled = true
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_glyph_label(cont)
	host.footer.add_child(cont)
	host.cont_btn = cont
	host.focus_btn = first if first else cont
	RecapBars.refresh(host)
	host._fit_sheet()
	host.call_deferred("_fit_sheet")
	host.call_deferred("_focus")

static func _header(host: CanvasLayer) -> void:
	if host.header == null:
		var col: VBoxContainer = VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		col.position = host.sheet_rect.position
		col.size = Vector2(host.sheet_rect.size.x, 0.0)
		host.add_child(col)
		host.header = col
		return
	var old: Array[Node] = host.header.get_children()
	for c: Node in old:
		host.header.remove_child(c)
		c.free()

static func _footer(host: CanvasLayer) -> void:
	if host.footer == null:
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.position = host.sheet_rect.position
		col.size = Vector2(host.sheet_rect.size.x, 0.0)
		host.add_child(col)
		host.footer = col
		return
	var old: Array[Node] = host.footer.get_children()
	for c: Node in old:
		host.footer.remove_child(c)
		c.free()

static func _line(host: CanvasLayer, text: String, font_px: int, col: Color) -> Label:
	var lab: Label = ThemeS.lab(text, font_px, col)
	lab.custom_minimum_size = Vector2(host.sheet_rect.size.x, 0.0)
	host.header.add_child(lab)
	return lab

## Accept glyph + "Continue" centred as one group on the button (the button text moves into the group).
static func _glyph_label(cont: Button) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var g: TextureRect = TextureRect.new()
	g.texture = Prompts.texture_for("ui_accept")
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.custom_minimum_size = Vector2(26, 26)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(g)
	var lab: Label = Label.new()
	lab.text = cont.text
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", cont.get_theme_font("font"))
	lab.add_theme_font_size_override("font_size", cont.get_theme_font_size("font_size"))
	lab.add_theme_color_override("font_color", cont.get_theme_color("font_color"))
	row.add_child(lab)
	cont.custom_minimum_size.y = maxf(cont.get_combined_minimum_size().y, 34.0)
	cont.text = ""
	cont.add_child(row)
	cont.set_meta("glyph", g)
	cont.set_meta("glyph_lab", lab)
