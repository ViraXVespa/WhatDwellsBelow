class_name FloorCrystal
extends Interactable

var _picker: CanvasLayer


func _ready() -> void:
	super._ready()
	prompt = "Floor crystal"
	var tex := Art.load_tex("res://assets/sprites/props/crystal.png")
	if tex == null:
		tex = Art.solid(Vector2i(44, 64), Color(0.35, 0.85, 0.9))
	add_child(Art.make_sprite(tex, 0.85))


func get_prompt() -> String:
	if Game.run == null:
		return "Crystal"
	if Game.save == null or Game.save.deepest_floor <= Game.run.current_floor:
		return "Crystal (no deeper memory)"
	return "Crystal: skip deeper"


func interact(_player: Node) -> void:
	if Game.run == null or Game.save == null:
		return
	var dests: Array = []
	for f in range(Game.run.current_floor + 1, Game.save.deepest_floor + 1):
		dests.append(f)
	if dests.is_empty():
		return
	if dests.size() == 1:
		Game.enter_floor(int(dests[0]))
		return
	_open_picker(dests)


func _unhandled_input(event: InputEvent) -> void:
	if _picker == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_picker()
		get_viewport().set_input_as_handled()


func _open_picker(dests: Array) -> void:
	if _picker:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_to_group("wdb_modal")
	get_tree().paused = true
	var panel := Panel.new()
	panel.position = Vector2(660, 220)
	panel.size = Vector2(600, 520)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 20
	v.offset_right = -24
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var lab := Label.new()
	lab.text = "Skip down. You've walked these before."
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 20)
	v.add_child(lab)
	for f in dests:
		var fl := int(f)
		var b := Button.new()
		b.text = "Floor %d" % fl
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func():
			_close_picker()
			Game.enter_floor(fl)
		)
		v.add_child(b)
	var c := Button.new()
	c.text = "Stay"
	c.custom_minimum_size = Vector2(0, 48)
	c.pressed.connect(_close_picker)
	v.add_child(c)
	PadUi.wire(panel)
	_picker = layer
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)


func _close_picker() -> void:
	get_tree().paused = false
	if _picker:
		_picker.queue_free()
		_picker = null
	process_mode = Node.PROCESS_MODE_INHERIT
