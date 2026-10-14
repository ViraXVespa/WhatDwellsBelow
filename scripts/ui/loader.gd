extends CanvasLayer
const Plate := preload("res://scripts/ui/plate_chrome.gd")
const Tok: GDScript = preload("res://scripts/ui/ui_tokens.gd")
const CliArgs := preload("res://scripts/debug/cli_args.gd")

## Menu load overlay. Lives on App so it survives the title → camp swap.

var open := false
var _target := 0.0 ## last reached milestone (set_progress / stage)
var _ceil := 0.0 ## end of the step now running: the shown value creeps toward it, never past it
var _shown := 0.0 ## the one value the fill and the % label draw; never goes back
## Creep rate toward _ceil while a step runs (share of the remaining gap per second), and how close it may get.
const CREEP := 0.9
const CREEP_GAP := 0.012
var _dim: ColorRect
var _card: ColorRect
var _title: Label
var _status: Label
var _pct: Label
var _edge: ColorRect
var _track: ColorRect
var _fill: ColorRect
var _bar_w := 720.0
var _bar_h := 20.0
const DIM_SOFT := Color(0.04, 0.03, 0.025, 0.88)
const DIM_SOLID := Color(0.0, 0.0, 0.0, 254.0 / 255.0)

func _ready() -> void:
	layer = 110
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = DIM_SOLID
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_card = ColorRect.new()
	_card.color = Plate.PLATE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_title = _lab(tr("loader.loading"), 36, Tok.INK)
	add_child(_title)
	_status = _lab("", 20, Tok.INK_SOFT)
	add_child(_status)
	_edge = ColorRect.new()
	_edge.color = Plate.EDGE
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge)
	_track = ColorRect.new()
	_track.color = Color(0.55, 0.42, 0.30, 1)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	_fill = ColorRect.new()
	_fill.color = Tok.INK
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
	_pct = _lab("0%", 18, Tok.INK)
	add_child(_pct)
	_layout_bar()

func begin(heading: String, status: String = "") -> void:
	open = true
	visible = true
	_target = 0.0
	_ceil = 0.02
	_shown = 0.0
	_title.text = heading
	_status.text = status
	_pct.text = tr("loader.text") % 0
	set_solid(true)
	_layout_bar()
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(_bar_w * _shown, _bar_h)
	if App:
		App.ui_open = true

func set_solid(on: bool) -> void:
	if _dim == null:
		return
	if on:
		_dim.color = DIM_SOLID
	else:
		_dim.color = DIM_SOFT

func set_status(text: String) -> void:
	if _status:
		_status.text = text

## A milestone that has really been reached. Below 1.0 only: finish() is the one place the bar fills.
func set_progress(v: float) -> void:
	_target = maxf(_target, clampf(v, 0.0, 0.99))
	_ceil = maxf(_ceil, _target)

## A step starts: the bar is at `from` and may creep toward `to` while the step works (hub weights: flow_hub.gd P_*).
func stage(from: float, to: float) -> void:
	set_progress(from)
	_ceil = maxf(_ceil, clampf(to, _target, 0.99))

## Sub-progress inside the running stage: u in 0..1 of the way from its start to its end.
func stage_at(from: float, to: float, u: float) -> void:
	_ceil = maxf(_ceil, clampf(to, 0.0, 0.99))
	set_progress(lerpf(from, to, clampf(u, 0.0, 1.0)))

func finish() -> void:
	_target = 1.0
	_shown = 1.0
	_sync_bar()
	_trace()
	set_solid(false)
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
	# Real frames can be long (a blocking step); cap delta so one long frame does not leap the creep.
	var d := minf(delta, 0.1)
	if _shown < _target:
		var gap := _target - _shown
		_shown = move_toward(_shown, _target, maxf(0.6 * d, gap * 6.0 * d))
	elif _shown < _ceil - CREEP_GAP:
		_shown = minf(_shown + (_ceil - CREEP_GAP - _shown) * CREEP * d, _ceil - CREEP_GAP)
	_sync_bar()
	_trace()

## ?wdb-loader-trace / --wdb-loader-trace: one console row per drawn frame (ms, target, shown, label, status) for tools/load_bars.py.
static var _trace_on := -1

func _trace() -> void:
	if _trace_on < 0:
		_trace_on = 1 if CliArgs.has("--wdb-loader-trace") else 0
	if _trace_on == 1:
		print("LOADTRACE %d %.4f %.4f %s|%s" % [Time.get_ticks_msec(), _target, _shown, _pct.text, _status.text])

func _vp() -> Vector2:
	var vp := get_viewport()
	if vp:
		var r := vp.get_visible_rect().size
		if r.x > 1.0 and r.y > 1.0:
			return r
	return load("res://scripts/data/tunables.gd").base_size()

func _layout_bar() -> void:
	var s := _vp()
	var cx := s.x * 0.5
	var cy := s.y * 0.5
	if _dim:
		_dim.position = Vector2.ZERO
		_dim.size = s
	if _card:
		_card.position = Vector2(cx - 520.0, cy - 120.0)
		_card.size = Vector2(1040.0, 240.0)
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
		# Same value as the fill; floor so the label never reads ahead of the bar, and 100 only from finish().
		_pct.text = tr("loader.text") % mini(int(floor(clampf(_shown, 0.0, 1.0) * 100.0)), 100 if _shown >= 1.0 else 99)

func _lab(text: String, font_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Tok.OUTLINE)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	return l
