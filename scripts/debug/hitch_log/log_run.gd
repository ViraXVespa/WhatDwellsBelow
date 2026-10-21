extends Object

## Split from hitch_log.gd: _copy_run, _break_run, _track_run....

static var _run_n: int = 0
static var _run_best: int = 0
static var _run_vals: PackedFloat32Array = PackedFloat32Array()
static var _run_best_vals: PackedFloat32Array = PackedFloat32Array()

static func _copy_run(src: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(src.size())
	for i: int in src.size():
		out[i] = src[i]
	return out

static func _break_run() -> void:
	if _run_n > _run_best:
		_run_best = _run_n
		_run_best_vals = _copy_run(_run_vals)
	_run_n = 0
	_run_vals = PackedFloat32Array()

static func _track_run(dt_ms: float, slow: bool) -> void:
	if not slow:
		_break_run()
		return
	_run_n += 1
	_run_vals.append(dt_ms)
