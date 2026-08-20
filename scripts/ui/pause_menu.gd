class_name PauseMenu
extends CanvasLayer

var panel: Panel
var open := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(620, 140)
	panel.size = Vector2(680, 760)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 32
	v.offset_top = 28
	v.offset_right = -32
	v.offset_bottom = -28
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.name = "Title"
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	v.add_child(_btn("Resume", _close))
	var d := Button.new()
	d.name = "Dispel"
	d.text = "Dispel Avatar (Return to Town)"
	d.custom_minimum_size = Vector2(0, 52)
	d.pressed.connect(_dispel)
	v.add_child(d)
	v.add_child(_slider_row("Music", "music"))
	v.add_child(_slider_row("SFX", "sfx"))
	v.add_child(_slider_row("Zoom", "zoom"))
	var pat := LinkButton.new()
	pat.text = "Support on Patreon"
	pat.uri = Game.PATREON_URL
	pat.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	pat.add_theme_font_size_override("font_size", 20)
	pat.add_theme_color_override("font_color", Color(0.95, 0.55, 0.42))
	v.add_child(pat)
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


func _slider_row(label: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = label
	lab.custom_minimum_size = Vector2(90, 0)
	lab.add_theme_font_size_override("font_size", 18)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(280, 28)
	if kind == "zoom":
		sl.min_value = 1.0
		sl.max_value = 1.75
		sl.step = 0.05
		sl.value = Game.save.cam_zoom if Game.save else 1.0
	elif kind == "music":
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Game.save.music_vol if Game.save else 0.7
	else:
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Game.save.sfx_vol if Game.save else 0.85
	sl.value_changed.connect(func(v: float): _slide(kind, v))
	row.add_child(sl)
	return row


func _slide(kind: String, v: float) -> void:
	if Game.save == null:
		return
	if kind == "zoom":
		Game.set_cam_zoom(v)
		return
	if kind == "music":
		Game.save.music_vol = v
	else:
		Game.save.sfx_vol = v
	Game.save.write()
	Sfx.apply_volumes()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(cb)
	return b
