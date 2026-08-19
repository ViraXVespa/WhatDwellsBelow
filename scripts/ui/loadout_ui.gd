class_name LoadoutUI
extends CanvasLayer

var panel: Panel
var axe_list: ItemList
var pick_list: ItemList
var floor_list: ItemList
var axes: Array = []
var picks: Array = []


func _ready() -> void:
	add_to_group("loadout_ui")
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(360, 80)
	panel.size = Vector2(1200, 860)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 20
	v.offset_right = -28
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Delve loadout"
	t.add_theme_font_size_override("font_size", 30)
	v.add_child(t)
	v.add_child(_lab("Great Axe"))
	axe_list = ItemList.new()
	axe_list.custom_minimum_size = Vector2(0, 160)
	v.add_child(axe_list)
	v.add_child(_lab("Pickaxe (your one tool)"))
	pick_list = ItemList.new()
	pick_list.custom_minimum_size = Vector2(0, 140)
	v.add_child(pick_list)
	v.add_child(_lab("Start at floor (town crystal)"))
	floor_list = ItemList.new()
	floor_list.custom_minimum_size = Vector2(0, 120)
	v.add_child(floor_list)
	v.add_child(_btn("Enter the dungeon", _enter))
	v.add_child(_btn("Cancel", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	panel.visible = true
	get_tree().paused = true
	_fill()
	PadUi.focus_first(panel)


func close() -> void:
	panel.visible = false
	get_tree().paused = false


func _fill() -> void:
	axe_list.clear()
	pick_list.clear()
	floor_list.clear()
	axes = [ItemData.make_starter_axe()]
	picks = [ItemData.make_starter_pickaxe()]
	for it in Game.save.analyzed_axes:
		if it.forged:
			axes.append(it)
	for it in Game.save.analyzed_pickaxes:
		if it.forged:
			picks.append(it)
	for it in axes:
		axe_list.add_item(it.full_name())
	axe_list.select(0)
	for it in picks:
		pick_list.add_item(it.full_name())
	pick_list.select(0)
	var deep: int = Game.save.deepest_floor
	for f in range(1, deep + 1):
		floor_list.add_item("Floor %d" % f)
	floor_list.select(0)


func _enter() -> void:
	var ai := 0 if axe_list.get_selected_items().is_empty() else axe_list.get_selected_items()[0]
	var pi := 0 if pick_list.get_selected_items().is_empty() else pick_list.get_selected_items()[0]
	var fi := 0 if floor_list.get_selected_items().is_empty() else floor_list.get_selected_items()[0]
	var w: ItemData = axes[ai]
	var t: ItemData = picks[pi]
	var fl := fi + 1
	close()
	Game.begin_run(w, t, fl)


func _lab(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 20)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	return b
