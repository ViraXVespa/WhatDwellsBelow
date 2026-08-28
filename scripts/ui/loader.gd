extends CanvasLayer

## Menu load overlay. Lives on App so it survives the title → camp swap.

var open := false
var _target := 0.0
var _shown := 0.0
var _title: Label
var _status: Label
var _pct: Label
var _track: ColorRect
var _fill: ColorRect
var _bar_w := 720.0


func _ready() -> void:
	layer = 110
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.025, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_title = _lab("Loading", 36, Color(0.95, 0.86, 0.55))
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.offset_left = -480
	_title.offset_right = 480
	_title.offset_top = -90
	_title.offset_bottom = -40
	add_child(_title)
	_status = _lab("", 20, Color(0.82, 0.76, 0.64))
	_status.set_anchors_preset(Control.PRESET_CENTER)
	_status.offset_left = -480
	_status.offset_right = 480
	_status.offset_top = -28
	_status.offset_bottom = 8
	add_child(_status)
	_track = ColorRect.new()
	_track.color = Color(0.16, 0.12, 0.09, 1)
	_track.set_anchors_preset(Control.PRESET_CENTER)
	_track.offset_left = -_bar_w * 0.5
	_track.offset_right = _bar_w * 0.5
	_track.offset_top = 24
	_track.offset_bottom = 44
	add_child(_track)
	var edge := ColorRect.new()
	edge.color = Color(0.55, 0.42, 0.22, 1)
	edge.set_anchors_preset(Control.PRESET_CENTER)
	edge.offset_left = -_bar_w * 0.5 - 2
	edge.offset_right = _bar_w * 0.5 + 2
	edge.offset_top = 22
	edge.offset_bottom = 46
	add_child(edge)
	move_child(edge, _track.get_index())
	_fill = ColorRect.new()
	_fill.color = Color(0.92, 0.74, 0.32, 1)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(0, 20)
	_track.add_child(_fill)
	_pct = _lab("0%", 18, Color(0.95, 0.88, 0.62))
	_pct.set_anchors_preset(Control.PRESET_CENTER)
	_pct.offset_left = -80
	_pct.offset_right = 80
	_pct.offset_top = 56
	_pct.offset_bottom = 88
	add_child(_pct)


func begin(heading: String, status: String = "") -> void:
	open = true
	visible = true
	_target = 0.0
	_shown = 0.0
	_title.text = heading
	_status.text = status
	_pct.text = "0%"
	_fill.size = Vector2(0, _track.size.y if _track.size.y > 0.0 else 20.0)
	App.ui_open = true


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func set_progress(v: float) -> void:
	_target = clampf(v, 0.0, 1.0)


func finish() -> void:
	_target = 1.0
	_shown = 1.0
	_sync_bar()
	open = false
	visible = false
	_title.text = ""
	_status.text = ""
	if App.pause_menu == null or not bool(App.pause_menu.get("open")):
		if App.archives_ui == null or not bool(App.archives_ui.get("open")):
			App.ui_open = false
	App.wake_web_pad()


func _process(delta: float) -> void:
	if not visible:
		return
	_shown = move_toward(_shown, maxf(_shown, _target), maxf(0.35 * delta, absf(_target - _shown) * 8.0 * delta))
	if _target >= 0.999:
		_shown = move_toward(_shown, 1.0, 2.4 * delta)
	_sync_bar()


func _sync_bar() -> void:
	var w := _track.size.x if _track.size.x > 1.0 else _bar_w
	var h := _track.size.y if _track.size.y > 1.0 else 20.0
	_fill.size = Vector2(w * clampf(_shown, 0.0, 1.0), h)
	if _pct:
		_pct.text = "%d%%" % int(round(clampf(_shown, 0.0, 1.0) * 100.0))


func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	return l