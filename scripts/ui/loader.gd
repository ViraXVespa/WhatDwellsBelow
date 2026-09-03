extends CanvasLayer

## Menu load overlay. Lives on App so it survives the title → camp swap.

var open := false
var _target := 0.0
var _shown := 0.0
var _dim: ColorRect
var _title: Label
var _status: Label
var _pct: Label
var _edge: ColorRect
var _track: ColorRect
var _fill: ColorRect
var _bar_w := 720.0
var _bar_h := 20.0


func _ready() -> void:
	layer = 110
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.025, 0.88)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_title = _lab("Loading", 36, Color(0.95, 0.86, 0.55))
	add_child(_title)
	_status = _lab("", 20, Color(0.82, 0.76, 0.64))
	add_child(_status)
	_edge = ColorRect.new()
	_edge.color = Color(0.55, 0.42, 0.22, 1)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge)
	_track = ColorRect.new()
	_track.color = Color(0.16, 0.12, 0.09, 1)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	_fill = ColorRect.new()
	_fill.color = Color(0.92, 0.74, 0.32, 1)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
	_pct = _lab("0%", 18, Color(0.95, 0.88, 0.62))
	add_child(_pct)
	_layout_bar()


func begin(heading: String, status: String = "") -> void:
	open = true
	visible = true
	_target = 0.0
	_shown = 0.0
	_title.text = heading
	_status.text = status
	_pct.text = "0%"
	_layout_bar()
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(0, _bar_h)
	if App:
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


func _vp() -> Vector2:
	var vp := get_viewport()
	if vp:
		var r := vp.get_visible_rect().size
		if r.x > 1.0 and r.y > 1.0:
			return r
	return Vector2(1920, 1080)


func _layout_bar() -> void:
	var s := _vp()
	var cx := s.x * 0.5
	var cy := s.y * 0.5
	if _dim:
		_dim.position = Vector2.ZERO
		_dim.size = s
	if _title:
		_title.position = Vector2(cx - 480.0, cy - 90.0)
		_title.size = Vector2(960.0, 50.0)
	if _status:
		_status.position = Vector2(cx - 480.0, cy - 28.0)
		_status.size = Vector2(960.0, 36.0)
	if _edge:
		_edge.position = Vector2(cx - _bar_w * 0.5 - 2.0, cy + 22.0)
		_edge.size = Vector2(_bar_w + 4.0, _bar_h + 4.0)
	if _track:
		_track.position = Vector2(cx - _bar_w * 0.5, cy + 24.0)
		_track.size = Vector2(_bar_w, _bar_h)
	if _fill:
		_fill.position = Vector2.ZERO
		_fill.size = Vector2(_bar_w * clampf(_shown, 0.0, 1.0), _bar_h)
	if _pct:
		_pct.position = Vector2(cx - 80.0, cy + 56.0)
		_pct.size = Vector2(160.0, 32.0)


func _sync_bar() -> void:
	_layout_bar()
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
