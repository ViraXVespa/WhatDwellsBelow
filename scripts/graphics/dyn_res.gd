extends Object

## Dynamic 3D render scale. Starts and stays at 1.0 (no change) until real fps holds under DYNRES_FPS_LOW
## for one DYNRES_WINDOW_S window; then drops one DYNRES_STEP, never under DYNRES_MIN. Climbs back one step
## after DYNRES_RECOVER_WINDOWS windows at or over DYNRES_FPS_HIGH. A climb that gets undone doubles the wait.
## Off: DYNRES_ON false in tunables.gd, or the launch flag --wdb-no-dynres (web: ?wdb-no-dynres).
const T := preload("res://scripts/data/tunables.gd")
const CliArgs := preload("res://scripts/debug/cli_args.gd")

static var _acc := 0.0
static var _n := 0
static var _last_us := 0
static var _drop := 0
static var _good := 0
static var _wait := 0
static var _probe := false
static var _off := -1

static func enabled() -> bool:
	if _off < 0:
		_off = 0 if T.DYNRES_ON and not CliArgs.has("--wdb-no-dynres") else 1
	return _off == 0

static func scale() -> float:
	return maxf(T.DYNRES_MIN, 1.0 - float(_drop) * T.DYNRES_STEP)

static func _max_drop() -> int:
	return int(round((1.0 - T.DYNRES_MIN) / T.DYNRES_STEP))

## Real time (not Engine.time_scale), so hit-stop does not look like a slow frame.
static func tick(host: Node) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1000000.0
	_last_us = now
	if not enabled():
		if _drop != 0:
			_apply(host, 0)
		return
	if dt <= 0.0 or dt > T.DYNRES_HITCH_S or host.get_tree().paused or host._menu_loading or not host._in_world():
		_acc = 0.0
		_n = 0
		return
	_acc += dt
	_n += 1
	if _acc < T.DYNRES_WINDOW_S:
		return
	var fps: float = float(_n) / _acc
	_acc = 0.0
	_n = 0
	_decide(host, fps)

static func _decide(host: Node, fps: float) -> void:
	if fps < T.DYNRES_FPS_LOW:
		_good = 0
		if _probe:
			_wait = mini(maxi(_wait, T.DYNRES_RECOVER_WINDOWS) * 2, T.DYNRES_RECOVER_WINDOWS * T.DYNRES_BACKOFF_MAX)
			_probe = false
		if _drop < _max_drop():
			_apply(host, _drop + 1)
	elif fps >= T.DYNRES_FPS_HIGH and _drop > 0:
		_good += 1
		if _good >= maxi(_wait, T.DYNRES_RECOVER_WINDOWS):
			_good = 0
			_probe = true
			_apply(host, _drop - 1)
	else:
		_good = 0

static func _apply(host: Node, level: int) -> void:
	_drop = level
	if level == 0:
		_wait = 0
		_probe = false
	host.get_tree().root.scaling_3d_scale = scale()
