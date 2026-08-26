extends Control

func _ready() -> void:
	Sfx.set_music("hub")
	if Game.last_recap.get("verge", false) and not Game.last_recap.get("voluntary", false):
		Sfx.play("hurt")
	else:
		Sfx.play("ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var r: Dictionary = Game.last_recap
	var v := VBoxContainer.new()
	v.position = Vector2(480, 120)
	v.size = Vector2(960, 800)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	var sub := Label.new()
	if r.get("voluntary", false):
		title.text = "You pulled the plug."
		sub.text = "Cleaner disconnect. Still forgot most of it. That's the job."
	elif r.get("verge", false):
		title.text = "So close it hurts."
		sub.text = "The stairs were there. Or the guardian was. Then the dream ended. That's a bad one."
	else:
		title.text = "You woke up. That one stung."
		sub.text = "Hurt like hell. That's why the dream doesn't stick. Shake it off."
	title.add_theme_font_size_override("font_size", 40)
	v.add_child(title)
	sub.add_theme_font_size_override("font_size", 20)
	v.add_child(sub)
	var strip := Panel.new()
	strip.custom_minimum_size = Vector2(0, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	sb.border_color = Color(0.45, 0.38, 0.22)
	sb.set_border_width_all(2)
	strip.add_theme_stylebox_override("panel", sb)
	v.add_child(strip)
	var s := Label.new()
	s.position = Vector2(24, 16)
	s.size = Vector2(900, 270)
	var gear_lines := ""
	for g in r.get("gear", []):
		gear_lines += "\n  mailed: %s" % str(g)
	if gear_lines == "":
		gear_lines = "\n  no Gear Gopher this run (or you mailed none)"
	var lvl_lines := ""
	for lv in r.get("awake_levels", []):
		lvl_lines += "\n  woke up %s" % str(lv)
	s.text = (
		"Floor reached: %d\n" +
		"XP kept  mining %.1f  |  axe %.1f  |  str %.1f  |  def %.1f  |  hp %.1f  |  smith %.1f%s\n" +
		"Combat level: %d\n" +
		"Ore banked: %d\n" +
		"Gold mailed: %d   lost in the dream: %d\n" +
		"Bag vanished: %d slots of stuff%s"
	) % [
		int(r.get("floor", 1)),
		float(r.get("mining_kept", 0)),
		float(r.get("axe_kept", 0)),
		float(r.get("strength_kept", 0)),
		float(r.get("defense_kept", 0)),
		float(r.get("hitpoints_kept", 0)),
		float(r.get("smithing_kept", 0)),
		lvl_lines,
		int(r.get("combat_level", 1)),
		int(r.get("ore_banked", 0)),
		int(r.get("gold_mailed", 0)),
		int(r.get("gold_lost", 0)),
		int(r.get("bag_lost", 0)),
		gear_lines,
	]
	s.add_theme_font_size_override("font_size", 22)
	strip.add_child(s)
	var b := Button.new()
	b.text = "Back to %s" % Game.DEMO_TOWN
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func(): Game.go_plaza())
	v.add_child(b)
