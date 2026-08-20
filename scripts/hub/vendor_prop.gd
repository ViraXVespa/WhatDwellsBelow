class_name VendorProp
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Talk: stall auntie"
	var tex := Art.load_tex("res://assets/sprites/npcs/vendor.png")
	if tex == null:
		tex = Art.body(Vector2i(56, 56), Color(0.55, 0.35, 0.2), Color(0.9, 0.75, 0.4))
	add_child(Art.make_sprite(tex, 0.82))
	Art.add_blocker(self, Vector2(30, 36))


func interact(_player: Node) -> void:
	_open()


func _open() -> void:
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
	lab.text = _copy()
	lab.add_theme_font_size_override("font_size", 20)
	v.add_child(lab)
	v.add_child(_btn("Buy ration (5g) — next bag", func():
		if Game.save.gold < 5:
			lab.text = "I'm flattered. Your purse isn't."
			return
		Game.save.gold -= 5
		Game.save.extra_food += 1
		Game.save.write()
		lab.text = _copy() + "\nRation's on the next dive. Don't skip breakfast in a hole."
	))
	v.add_child(_btn("Buy potion (15g) — next bag", func():
		if Game.save.gold < 15:
			lab.text = "Potions are 15. That's not a negotiation, that's arithmetic."
			return
		Game.save.gold -= 15
		Game.save.extra_potion += 1
		Game.save.write()
		lab.text = _copy() + "\nRed bottle. For when the job gets opinionated."
	))
	v.add_child(_btn("Sell 5 ore (10g)", func():
		if Game.save.banked_ore < 5:
			lab.text = "Bring me five rocks that used to be a wall. Then we talk."
			return
		Game.save.banked_ore -= 5
		Game.save.gold += 10
		Game.save.write()
		lab.text = _copy() + "\nUgly ore. Pretty coins. Everybody wins."
	))
	v.add_child(_btn("Close", func():
		get_tree().paused = false
		layer.queue_free()
	))
	PadUi.wire(panel)
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)
	layer.set_process_unhandled_input(true)


func _copy() -> String:
	return "Placeholdia stall. Gold %d. Banked ore %d.\nRations 5g. Potions 15g. I'll take 5 ore for 10g." % [
		Game.save.gold if Game.save else 0,
		Game.save.banked_ore if Game.save else 0,
	]


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
