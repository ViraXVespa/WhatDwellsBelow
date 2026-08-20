class_name LoadoutUI
extends CanvasLayer

var panel: Panel
var axe_list: ItemList
var pick_list: ItemList
var floor_box: HBoxContainer
var floor_group: ButtonGroup
var axes: Array = []
var picks: Array = []
var chosen_floor: int = 1


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
	v.add_child(_lab("Start at floor  (D-pad L/R)"))
	floor_box = HBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 10)
	v.add_child(floor_box)
	var hint := Label.new()
	hint.text = "D-pad / stick: move   A: confirm   B: back"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	v.add_child(hint)
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
	Sfx.play("ui")
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
	for c in floor_box.get_children():
		floor_box.remove_child(c)
		c.free()
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
	floor_group = ButtonGroup.new()
	chosen_floor = 1
	for f in range(1, deep + 1):
		var b := Button.new()
		b.text = "  %d  " % f
		b.toggle_mode = true
		b.button_group = floor_group
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(72, 52)
		b.set_meta("floor", f)
		b.pressed.connect(_pick_floor.bind(f))
		b.focus_entered.connect(_pick_floor.bind(f))
		floor_box.add_child(b)
		if f == 1:
			b.button_pressed = true
	PadUi.wire(floor_box)


func _enter() -> void:
	var ai := 0 if axe_list.get_selected_items().is_empty() else axe_list.get_selected_items()[0]
	var pi := 0 if pick_list.get_selected_items().is_empty() else pick_list.get_selected_items()[0]
	var w: ItemData = axes[ai]
	var t: ItemData = picks[pi]
	close()
	Game.begin_run(w, t, chosen_floor)


func _pick_floor(f: int) -> void:
	chosen_floor = f


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
