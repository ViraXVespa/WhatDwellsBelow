extends "res://scripts/view3d/spot_3d.gd"


func _build_kind() -> void:
	match kind:
		"town_crystal":
			prompt = "Enter the dungeon"
			_spr_from(tex_path if tex_path != "" else V3.a("props", "crystal.png"), 1.35, true)
			V3.add_box(self, Vector3(0.85, 0.45, 0.45), Vector3(0, 0.22, 0.2))
		"receptionist":
			prompt = "Talk: Guild clerk"
			_spr_from(V3.a("npcs", "receptionist.png"), 1.1, true)
			V3.add_cyl(self, 0.18, 0.5, Vector3(0, 0.25, 0))
		"sign":
			prompt = title if title != "" else "Sign"
			_spr_from(tex_path if tex_path != "" else V3.a("props", "sign.png"), 0.95 if tex_path.ends_with("dumpster.png") else 0.85, true)
			if tex_path.ends_with("dumpster.png"):
				V3.add_box(self, Vector3(1.2, 0.8, 0.75), Vector3(0, 0.4, 0))
			else:
				V3.add_box(self, Vector3(0.44, 0.7, 0.28), Vector3(0, 0.35, 0))
		"vendor":
			prompt = "Talk: Stallkeep"
			process_mode = Node.PROCESS_MODE_ALWAYS
			_spr_from(V3.a("npcs", "vendor.png"), 1.05, true)
			V3.add_cyl(self, 0.2, 0.5, Vector3(0, 0.25, 0.1))
		"anvil":
			prompt = "Anvil"
			_spr_from(V3.a("props", "anvil.png"), 0.7, true)
			V3.add_box(self, Vector3(1.1, 0.55, 0.65), Vector3(0, 0.28, 0.15))
		_:
			super._build_kind()


func interact(_player: Node) -> void:
	match kind:
		"town_crystal":
			var uis := get_tree().get_nodes_in_group("loadout_ui")
			if uis.is_empty():
				Game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)
				return
			uis[0].open()
		"receptionist":
			var copy := "Welcome to Placeholdia, pop. whoever showed up. Real city's still in permitting. Crystal's open. Dying's a workplace hazard — pack snacks."
			if Game.save and not Game.save.has_dived:
				copy = "First time? Eh, I'm sure you'll be able to figure it out.\n\n" + copy
			_long_toast(copy)
		"sign":
			_long_toast(body)
		"vendor":
			if _layer:
				return
			_open_vendor()
		"anvil":
			var uis := get_tree().get_nodes_in_group("anvil_ui")
			if not uis.is_empty():
				uis[0].open()


func _open_vendor() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var panel := Panel.new()
	panel.position = Vector2(640, 260)
	panel.size = Vector2(640, 360)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 12)
	v.offset_left = 24
	v.offset_top = 24
	v.offset_right = -24
	v.offset_bottom = -24
	panel.add_child(v)
	Sfx.play("ui")
	var lab := Label.new()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.text = _vendor_copy()
	lab.add_theme_font_size_override("font_size", 20)
	v.add_child(lab)
	v.add_child(_btn("Buy ration (5g) — next bag", func():
		if Game.save.gold < 5:
			lab.text = "I'm flattered. Your purse isn't."
			return
		if Game.save.extra_food >= 20:
			lab.text = "Twenty rations is a picnic, not a dive. Eat some first."
			return
		Game.save.gold -= 5
		Game.save.extra_food += 1
		Game.save.write()
		lab.text = _vendor_copy() + "\nRation's on the next dive. Don't skip breakfast in a hole."
	))
	v.add_child(_btn("Buy potion (15g) — next bag", func():
		if Game.save.gold < 15:
			lab.text = "Potions are 15. That's not a negotiation, that's arithmetic."
			return
		Game.save.gold -= 15
		Game.save.extra_potion += 1
		Game.save.write()
		lab.text = _vendor_copy() + "\nRed bottle. For when the job gets opinionated."
	))
	v.add_child(_btn("Sell 5 ore (10g)", func():
		if Game.save.banked_ore < 5:
			lab.text = "Bring me five rocks that used to be a wall. Then we talk."
			return
		Game.save.banked_ore -= 5
		Game.save.gold += 10
		Game.save.write()
		lab.text = _vendor_copy() + "\nUgly ore. Pretty coins. Everybody wins."
	))
	v.add_child(_btn("Close", _close_layer))
	PadUi.wire(panel)
	_layer = layer
	layer.add_to_group("wdb_modal")
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)


func _vendor_copy() -> String:
	return "Placeholdia stall. Gold %d. Banked ore %d.\nPacked for the next dive: %d/20 rations, %d potions in the sack.\nRations 5g. Potions 15g. I'll take 5 ore for 10g." % [
		Game.save.gold if Game.save else 0,
		Game.save.banked_ore if Game.save else 0,
		Game.save.extra_food if Game.save else 0,
		Game.save.extra_potion if Game.save else 0,
	]
