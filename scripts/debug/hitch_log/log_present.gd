extends Object

## Split from hitch_log.gd: present, _present_at, _present_row....

const Run := preload("res://scripts/debug/hitch_log/log_run.gd")

## Display server read-back. Queried at most twice a second; every frame was a web stall.
static var _present_at: int = -100000
static var _present_row: Dictionary = {}
## Float slack so a frame at exactly 1/60 is not a hitch when vsync is actually off.
const BUDGET_EPS_SEC := 0.0005

const BUDGET_SEC := 1.0 / 60.0
## Refresh-paced frames cluster a few ms over one refresh. That cluster is the present, not a stall.
const PRESENT_SLACK_SEC := 0.003
static var _dts: PackedFloat32Array = PackedFloat32Array()
const MULT := 4.0
static var _mult: float = 0.0

## Read-back of the window the frame was actually presented on. Web is always paced:
## DisplayServerWeb ignores window_set_vsync_mode and the loop is requestAnimationFrame.
static func present() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if not _present_row.is_empty() and now - _present_at < 500:
		return _present_row
	var mode: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	var hz: float = DisplayServer.screen_get_refresh_rate()
	if hz <= 1.0:
		hz = 60.0
	var paced: int = 0
	if OS.has_feature("web") or mode != DisplayServer.VSYNC_DISABLED:
		paced = 1
	var scr_i: int = DisplayServer.window_get_current_screen()
	var screen: Vector2i = DisplayServer.screen_get_size(scr_i)
	var win: Vector2i = DisplayServer.window_get_size()
	_present_at = now
	_present_row = {
		"vsync": int(mode),
		"max_fps": Engine.max_fps,
		"refresh_hz": snappedf(hz, 0.1),
		"paced": paced,
		"renderer": RenderingServer.get_current_rendering_method(),
		"win_w": win.x,
		"win_h": win.y,
		"screen_w": screen.x,
		"screen_h": screen.y,
	}
	return _present_row

static func present_text() -> String:
	var info: Dictionary = present()
	return "vsync=%d max_fps=%d refresh=%.1f paced=%d" % [int(info["vsync"]), int(info["max_fps"]), float(info["refresh_hz"]), int(info["paced"])]

static func _stamp_present(row: Dictionary) -> void:
	var info: Dictionary = present()
	row["vsync"] = int(info["vsync"])
	row["max_fps"] = int(info["max_fps"])
	row["refresh_hz"] = float(info["refresh_hz"])
	row["paced"] = int(info["paced"])
	row["renderer"] = str(info["renderer"])
	row["win_w"] = int(info["win_w"])
	row["win_h"] = int(info["win_h"])
	row["screen_w"] = int(info["screen_w"])
	row["screen_h"] = int(info["screen_h"])

static func _refresh_n(dt_ms: float) -> int:
	var info: Dictionary = present()
	var refresh_ms: float = 1000.0 / float(info["refresh_hz"])
	if refresh_ms <= 0.0:
		return 1
	return maxi(1, roundi(dt_ms / refresh_ms))

## True when this delta is a stall. A refresh-paced present within 3 ms of one
## refresh is not a stall. An uncapped desktop frame is a stall over the 60 FPS budget.
static func _over_budget(delta: float) -> bool:
	var budget: float = BUDGET_SEC * mult()
	var info: Dictionary = present()
	if int(info["paced"]) == 1:
		var refresh: float = 1.0 / float(info["refresh_hz"])
		var line: float = budget
		if refresh > line:
			line = refresh
		return delta > line + PRESENT_SLACK_SEC
	return delta > budget + BUDGET_EPS_SEC

## Counted-frame shape. edge is one late refresh, stutter is two or more, spike is 100 ms or more.
static func _slow_shape() -> Dictionary:
	var info: Dictionary = present()
	var refresh_ms: float = 1000.0 / float(info["refresh_hz"])
	var two: float = refresh_ms * 2.0
	if int(info["paced"]) == 0:
		two = BUDGET_SEC * mult() * 1000.0 * 2.0
	Run._break_run()
	var edge: int = 0
	var stutter: int = 0
	var spike: int = 0
	for dt: float in _dts:
		if not _over_budget(dt / 1000.0):
			continue
		if dt >= 100.0:
			spike += 1
		elif dt >= two:
			stutter += 1
		else:
			edge += 1
	var med: float = 0.0
	if Run._run_best_vals.size() > 0:
		var ordered: PackedFloat32Array = Run._copy_run(Run._run_best_vals)
		ordered.sort()
		med = snappedf(ordered[int(float(ordered.size()) / 2.0)], 0.1)
	return {
		"n_edge": edge,
		"n_stutter": stutter,
		"n_spike": spike,
		"slow_run_n": Run._run_best,
		"slow_run_med_ms": med,
	}

static func _percentile(p: float) -> float:
	var n: int = _dts.size()
	if n <= 0:
		return 0.0
	var i: int = int(float(n - 1) * p)
	return snappedf(_dts[i], 0.1)

static func mult() -> float:
	return _mult if _mult > 0.0 else MULT
