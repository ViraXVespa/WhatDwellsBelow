class_name AnvilUI
extends CanvasLayer

var panel: Panel
var list: ItemList
var hint: Label


func _ready() -> void:
	add_to_group("anvil_ui")
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(560, 180)
	panel.size = Vector2(800, 620)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 24
	v.offset_right = -24
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Anvil"
	t.add_theme_font_size_override("font_size", 28)
	v.add_child(t)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 260)
	v.add_child(list)
	v.add_child(_btn("Forge selected (free after analysis)", _forge))
	v.add_child(_btn("Smelt 1 ore → bar (slow smithing XP)", _smelt))
	v.add_child(_btn("Close", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	Sfx.play("ui")
	panel.visible = true
	get_tree().paused = true
	_refresh()
	PadUi.focus_first(panel)


func close() -> void:
	panel.visible = false
	get_tree().paused = false


func _refresh() -> void:
	list.clear()
	hint.text = "Banked ore: %d   Bars: %d   Smithing XP: %.0f\nForge analyzed gear so you can bring copies next delve." % [
		Game.save.banked_ore, Game.save.banked_bars, Game.save.smithing_xp
	]
	var i := 0
	for it in Game.save.analyzed_axes:
		list.add_item("%s  [%s]" % [it.full_name(), "forged" if it.forged else "needs forge"])
		list.set_item_metadata(list.item_count - 1, {"fam": "axe", "i": i})
		i += 1
	i = 0
	for it in Game.save.analyzed_pickaxes:
		list.add_item("%s  [%s]" % [it.full_name(), "forged" if it.forged else "needs forge"])
		list.set_item_metadata(list.item_count - 1, {"fam": "pick", "i": i})
		i += 1
	if list.item_count > 0:
		list.select(0)


func _forge() -> void:
	if list.get_selected_items().is_empty():
		return
	var meta: Dictionary = list.get_item_metadata(list.get_selected_items()[0])
	var arr: Array = Game.save.analyzed_axes if meta.fam == "axe" else Game.save.analyzed_pickaxes
	var it: ItemData = arr[meta.i]
	it.forged = true
	Game.grant_xp("smithing", 8.0, true)
	Game.save.write()
	_refresh()


func _smelt() -> void:
	if Game.save.banked_ore <= 0:
		return
	Game.save.banked_ore -= 1
	Game.save.banked_bars += 1
	Game.grant_xp("smithing", 6.0, true)
	Game.save.write()
	_refresh()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
