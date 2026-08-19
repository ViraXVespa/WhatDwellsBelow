class_name InventoryUI
extends CanvasLayer

var panel: Panel
var list: ItemList
var open_flag := false


func _ready() -> void:
	layer = 34
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(560, 140)
	panel.size = Vector2(800, 700)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 24
	v.offset_right = -24
	v.offset_bottom = -24
	panel.add_child(v)
	var lab := Label.new()
	lab.text = "Bag"
	lab.add_theme_font_size_override("font_size", 28)
	v.add_child(lab)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 520)
	v.add_child(list)
	var b := Button.new()
	b.text = "Close"
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(close)
	v.add_child(b)
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if open_flag:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if open_flag and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if Game.run == null:
		return
	open_flag = true
	panel.visible = true
	get_tree().paused = true
	list.clear()
	for i in RunState.BAG_SIZE:
		var it: ItemData = Game.run.bag[i]
		if it:
			list.add_item("%02d  %s" % [i + 1, it.full_name()])
		else:
			list.add_item("%02d  —" % (i + 1))
	PadUi.focus_first(panel)


func close() -> void:
	open_flag = false
	panel.visible = false
	get_tree().paused = false
