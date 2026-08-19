class_name PauseMenu
extends CanvasLayer

var panel: Panel
var open := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(660, 240)
	panel.size = Vector2(600, 420)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 32
	v.offset_top = 32
	v.offset_right = -32
	v.offset_bottom = -32
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := Label.new()
	title.name = "Title"
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	v.add_child(_btn("Resume", _close))
	if true:
		var d := Button.new()
		d.name = "Dispel"
		d.text = "Dispel Avatar (Return to Town)"
		d.custom_minimum_size = Vector2(0, 52)
		d.pressed.connect(_dispel)
		v.add_child(d)
	PadUi.wire(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
		return
	if open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	open = true
	panel.visible = true
	get_tree().paused = true
	var d: Button = panel.find_child("Dispel", true, false)
	if d:
		d.visible = Game.in_dungeon
	PadUi.focus_first(panel)


func _close() -> void:
	open = false
	panel.visible = false
	get_tree().paused = false


func _dispel() -> void:
	_close()
	Game.end_run(true)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	return b
