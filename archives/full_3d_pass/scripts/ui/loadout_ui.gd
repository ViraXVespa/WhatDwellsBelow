class_name LoadoutUI
extends CanvasLayer

var panel: Panel
var lists: Dictionary = {}
var floor_box: HBoxContainer
var floor_group: ButtonGroup
var chosen_floor: int = 1
var keys := ["weapon", "tool", "potion", "head", "body", "legs"]
var hold_map := {
	"weapon": "great_axe",
	"tool": "pickaxe",
	"potion": "potion",
	"head": "head",
	"body": "body",
	"legs": "legs",
}


func _ready() -> void:
	add_to_group("loadout_ui")
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(300, 40)
	panel.size = Vector2(1320, 980)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 16
	v.offset_right = -24
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Delve loadout — pick from your 3 forged holds. Armor can be empty."
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in keys:
		var box := VBoxContainer.new()
		box.add_child(_lab(k.capitalize()))
		var il := ItemList.new()
		il.custom_minimum_size = Vector2(0, 120)
		box.add_child(il)
		lists[k] = il
		grid.add_child(box)
	v.add_child(_lab("Start at floor"))
	floor_box = HBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 10)
	v.add_child(floor_box)
	v.add_child(_btn("Enter the dungeon", _enter))
	v.add_child(_btn("Cancel", close))
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
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
	for c in floor_box.get_children():
		floor_box.remove_child(c)
		c.free()
	for k in keys:
		var il: ItemList = lists[k]
		il.clear()
		il.set_meta("items", [])
		var arr: Array = []
		if k in ["head", "body", "legs"]:
			il.add_item("(empty)")
			arr.append(null)
		for it in Game.save.holds_of(str(hold_map[k])):
			il.add_item("%s  %s" % [it.full_name(), it.stat_line()])
			arr.append(it)
		if arr.is_empty():
			if k == "weapon":
				var a := ItemData.make_starter_axe()
				il.add_item(a.full_name())
				arr.append(a)
			elif k == "tool":
				var p := ItemData.make_starter_pickaxe()
				il.add_item(p.full_name())
				arr.append(p)
		il.set_meta("items", arr)
		if il.item_count > 0:
			il.select(arr.size() - 1)
	var deep: int = Game.save.deepest_floor
	floor_group = ButtonGroup.new()
	chosen_floor = 1
	for f in range(1, deep + 1):
		var b := Button.new()
		b.text = "  %d  " % f
		b.toggle_mode = true
		b.button_group = floor_group
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(72, 48)
		b.pressed.connect(_pick_floor.bind(f))
		b.focus_entered.connect(_pick_floor.bind(f))
		floor_box.add_child(b)
		if f == 1:
			b.button_pressed = true
	PadUi.wire(floor_box)


func _pick(k: String) -> ItemData:
	var il: ItemList = lists[k]
	var arr: Array = il.get_meta("items")
	if arr.is_empty():
		return null
	var i := 0 if il.get_selected_items().is_empty() else il.get_selected_items()[0]
	i = clampi(i, 0, arr.size() - 1)
	return arr[i]


func _enter() -> void:
	var chosen := {
		"weapon": _pick("weapon"),
		"tool": _pick("tool"),
		"potion": _pick("potion"),
		"head": _pick("head"),
		"body": _pick("body"),
		"legs": _pick("legs"),
	}
	close()
	Game.begin_run(chosen, chosen_floor)


func _pick_floor(f: int) -> void:
	chosen_floor = f


func _lab(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 18)
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b
