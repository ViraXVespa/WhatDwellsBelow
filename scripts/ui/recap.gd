extends Control

func _ready() -> void:
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
	title.text = "You woke up." if r.get("voluntary", false) else "You woke up. That one stung."
	title.add_theme_font_size_override("font_size", 40)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Career hazard. Shake it off."
	sub.add_theme_font_size_override("font_size", 20)
	v.add_child(sub)
	var strip := Panel.new()
	strip.custom_minimum_size = Vector2(0, 280)
	v.add_child(strip)
	var s := Label.new()
	s.position = Vector2(24, 16)
	s.size = Vector2(900, 250)
	var gear_lines := ""
	for g in r.get("gear", []):
		gear_lines += "\n  analyzed: %s" % str(g)
	if gear_lines == "":
		gear_lines = "\n  no Gear Gopher this run (or you mailed none)"
	var lvl_lines := ""
	for lv in r.get("awake_levels", []):
		lvl_lines += "\n  woke up %s" % str(lv)
	s.text = (
		"Floor reached: %d\n" +
		"XP kept  mining %.1f  |  great axe %.1f  |  smithing %.1f%s\n" +
		"Ore banked: %d\n" +
		"Gold mailed: %d   lost in the dream: %d\n" +
		"Bag vanished: %d slots of stuff%s"
	) % [
		int(r.get("floor", 1)),
		float(r.get("mining_kept", 0)),
		float(r.get("axe_kept", 0)),
		float(r.get("smithing_kept", 0)),
		lvl_lines,
		int(r.get("ore_banked", 0)),
		int(r.get("gold_mailed", 0)),
		int(r.get("gold_lost", 0)),
		int(r.get("bag_lost", 0)),
		gear_lines,
	]
	s.add_theme_font_size_override("font_size", 22)
	strip.add_child(s)
	var b := Button.new()
	b.text = "Back to Vylenheim"
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func(): Game.go_plaza())
	v.add_child(b)
