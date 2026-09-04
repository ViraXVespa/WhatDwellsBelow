extends Object

const Prompts := preload("res://scripts/input/prompts.gd")


static func lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func btn(t: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_focus_color", Color(1, 0.92, 0.55))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
	b.add_theme_stylebox_override("normal", sb(Color(0.22, 0.16, 0.12), Color(0.5, 0.38, 0.2)))
	b.add_theme_stylebox_override("hover", sb(Color(0.3, 0.22, 0.14), Color(0.75, 0.58, 0.28)))
	b.add_theme_stylebox_override("pressed", sb(Color(0.16, 0.12, 0.08), Color(0.9, 0.7, 0.3)))
	b.add_theme_stylebox_override("focus", sb(Color(0.28, 0.2, 0.12), Color(0.95, 0.78, 0.35)))
	b.add_theme_stylebox_override("disabled", sb(Color(0.12, 0.1, 0.09), Color(0.28, 0.24, 0.2)))
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(cb)
	return b


static func skill_row_sb(lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if lit:
		s.bg_color = Color(0.26, 0.19, 0.12, 0.72)
		s.border_color = Color(0.95, 0.78, 0.35)
	else:
		s.bg_color = Color(0.16, 0.12, 0.09, 0.18)
		s.border_color = Color(0.32, 0.24, 0.16, 0.4)
	s.set_border_width_all(2)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	return s


static func skill_row() -> PanelContainer:
	var p := PanelContainer.new()
	p.focus_mode = Control.FOCUS_ALL
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 52)
	p.add_theme_stylebox_override("panel", skill_row_sb(false))
	return p


static func skill_name(id: String) -> String:
	match id:
		"axe":
			return "Great Axe"
		"staff":
			return "Staff"
		"bow":
			return "Longbow"
		"str":
			return "Strength"
		"mag":
			return "Magic"
		"rng":
			return "Ranged"
		"def":
			return "Defense"
		"hp":
			return "Hitpoints"
		"mine":
			return "Mining"
		"wood":
			return "Woodcutting"
		"smith":
			return "Smithing"
	return id


static func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


static func skill_tip(id: String, lv: int) -> String:
	lv = maxi(1, lv)
	var ranks := maxi(0, lv - 1)
	var n := skill_name(id)
	var wpn := float(App.bal.skill_dmg_weapon)
	var sty := float(App.bal.skill_dmg_style)
	var spec := float(App.bal.skill_special_bonus)
	var now := ""
	var per := ""
	match id:
		"axe":
			if ranks <= 0:
				now = "Now: no damage bonus yet."
			else:
				now = "Now: +%s Great Axe damage.\n	  +%s Great Axe special damage." % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = "Each level after 1: +%s Great Axe damage, +%s special damage." % [_pct(wpn), _pct(spec)]
		"staff":
			if ranks <= 0:
				now = "Now: no damage bonus yet."
			else:
				now = "Now: +%s staff damage.\n	  +%s staff special damage." % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = "Each level after 1: +%s staff damage, +%s special damage." % [_pct(wpn), _pct(spec)]
		"bow":
			if ranks <= 0:
				now = "Now: no damage bonus yet."
			else:
				now = "Now: +%s Longbow damage.\n	  +%s Longbow special damage." % [_pct(ranks * wpn), _pct(ranks * spec)]
			per = "Each level after 1: +%s Longbow damage, +%s special damage." % [_pct(wpn), _pct(spec)]
		"str":
			if ranks <= 0:
				now = "Now: no style bonus yet."
			else:
				now = "Now: +%s melee-style damage (Great Axe and staff melee)." % _pct(ranks * sty)
			per = "Each level after 1: +%s style damage." % _pct(sty)
		"mag":
			if ranks <= 0:
				now = "Now: no style bonus yet."
			else:
				now = "Now: +%s magic-style damage (staff special)." % _pct(ranks * sty)
			per = "Each level after 1: +%s style damage." % _pct(sty)
		"rng":
			if ranks <= 0:
				now = "Now: no style bonus yet."
			else:
				now = "Now: +%s ranged-style damage (Longbow)." % _pct(ranks * sty)
			per = "Each level after 1: +%s style damage." % _pct(sty)
		"def":
			var dnow := float(ranks) * float(App.bal.skill_def_per_lv)
			if ranks <= 0:
				now = "Now: no defense bonus yet."
			else:
				now = "Now: +%.1f defense." % dnow
			per = "Each level after 1: +%.1f defense." % float(App.bal.skill_def_per_lv)
		"hp":
			var hnow := int(round(float(ranks) * float(App.bal.skill_hp_per_lv)))
			if ranks <= 0:
				now = "Now: no Hitpoints bonus yet."
			else:
				now = "Now: +%d max HP." % hnow
			per = "Each level after 1: +%d max HP." % int(round(float(App.bal.skill_hp_per_lv)))
		"mine":
			now = "Now: +%s mining success chance." % _pct(float(lv) * float(App.bal.skill_gather))
			per = "Each level: +%s mining success chance." % _pct(float(App.bal.skill_gather))
		"wood":
			now = "Now: +%s woodcutting success chance." % _pct(float(lv) * float(App.bal.skill_gather))
			per = "Each level: +%s woodcutting success chance." % _pct(float(App.bal.skill_gather))
		"smith":
			var speed := 1.0 + float(ranks) * 0.12
			var extra := int(lv / 4)
			now = "Now: forge cost −%dg −%d ore.\n	  Forge time ÷ %.2f.\n	  Forged weapons +%d extra damage." % [lv * 2, lv, speed, extra]
			per = "Each level: −2g −1 ore on forge cost.\nEach level after 1: 12% faster forging.\nEvery 4 levels: +1 extra forged weapon damage."
		_:
			now = "Now: no listed bonus."
			per = "No per-level bonus is defined."
	return "%s  ·  Level %d\n\n%s\n\n%s" % [n, lv, now, per]


static func bind_text(action: String) -> String:
	return Prompts.chip_for(action)


static func _joy_btn(i: int) -> String:
	match i:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "View"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
	return "Pad " + str(i)


static func _joy_axis(axis: int, val: float) -> String:
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		return "RT"
	if axis == JOY_AXIS_TRIGGER_LEFT:
		return "LT"
	if axis == JOY_AXIS_LEFT_X:
		return "Left Stick X"
	if axis == JOY_AXIS_LEFT_Y:
		return "Left Stick Y"
	if axis == JOY_AXIS_RIGHT_X:
		return "Right Stick X"
	if axis == JOY_AXIS_RIGHT_Y:
		return "Right Stick Y"
	return "Axis %d%s" % [axis, "+" if val >= 0.0 else "-"]


static func sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
