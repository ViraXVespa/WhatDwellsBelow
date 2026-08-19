class_name VendorProp
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "Vendor"
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
	var lab := Label.new()
	lab.text = "Vendor — gold: %d\nRation 5g  |  Potion 15g" % Game.save.gold
	lab.add_theme_font_size_override("font_size", 22)
	v.add_child(lab)
	v.add_child(_btn("Buy ration (5g)", func():
		if Game.save.gold < 5:
			return
		Game.save.gold -= 5
		Game.save.extra_food += 1
		Game.save.write()
		lab.text = "Vendor — gold: %d\nBought a ration (goes in your next delve bag)." % Game.save.gold
	))
	v.add_child(_btn("Buy potion (15g)", func():
		if Game.save.gold < 15:
			return
		Game.save.gold -= 15
		Game.save.extra_potion += 1
		Game.save.write()
		lab.text = "Vendor — gold: %d\nBought a potion (goes in your next delve bag)." % Game.save.gold
	))
	v.add_child(_btn("Close", func():
		get_tree().paused = false
		layer.queue_free()
	))
	PadUi.wire(panel)
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)
	layer.set_process_unhandled_input(true)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
