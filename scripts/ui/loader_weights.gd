extends Object

## Title -> Placeholdia loader milestones (scripts/ui/loader.gd stage). Each step's share of the bar is its expected
## time: the last runs' measured step times on this machine (user://loader_steps.cfg, eased 50/50 per run), else the
## platform default below (measured on the box: web export in headless Chrome, desktop OpenGL). Web and desktop differ
## a lot (desktop builds the camp ~3x faster, its fps settle is a few short frames), so one fixed table stalls or jumps
## on one of them. The bar ends at END; finish() fills the rest.

const STEPS: Array[StringName] = [&"preload", &"camp", &"warm_frame", &"warm_ui", &"settle"]
const WEB_MS := {&"preload": 150.0, &"camp": 1290.0, &"warm_frame": 800.0, &"warm_ui": 1110.0, &"settle": 1830.0}
const DESKTOP_MS := {&"preload": 45.0, &"camp": 560.0, &"warm_frame": 420.0, &"warm_ui": 500.0, &"settle": 570.0}
const END := 0.98
const PATH := "user://loader_steps.cfg"

static var _ms: Dictionary = {}
static var _t0: int = 0
static var _last: int = 0
static var _got: Dictionary = {}

static func begin() -> void:
	_ms = (WEB_MS if OS.has_feature("web") else DESKTOP_MS).duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k: StringName in STEPS:
			var v: float = float(cf.get_value("ms", String(k), -1.0))
			if v > 0.0:
				_ms[k] = v
	_t0 = Time.get_ticks_msec()
	_last = _t0
	_got = {}

## Bar value where `step` starts (&"start" is 0, &"end" is END).
static func at(step: StringName) -> float:
	if _ms.is_empty():
		begin()
	var total := 0.0
	for k: StringName in STEPS:
		total += float(_ms[k])
	var acc := 0.0
	for k: StringName in STEPS:
		if k == step:
			return END * acc / maxf(total, 1.0)
		acc += float(_ms[k])
	return END

## Bar value where `step` ends.
static func after(step: StringName) -> float:
	var i: int = STEPS.find(step)
	return END if i < 0 or i + 1 >= STEPS.size() else at(STEPS[i + 1])

## Expected ms of a step, for time-based sub-progress inside it.
static func expect(step: StringName) -> float:
	return float(_ms.get(step, 500.0))

## `step` has just finished: keep its measured time.
static func done(step: StringName) -> void:
	var now: int = Time.get_ticks_msec()
	_got[step] = float(now - _last)
	_last = now

## Blend this run's step times into the saved ones (after the loader finishes).
static func save() -> void:
	if _got.size() != STEPS.size():
		return
	print("LOADSTEPS ", _got)
	var cf := ConfigFile.new()
	for k: StringName in STEPS:
		cf.set_value("ms", String(k), 0.5 * float(_ms[k]) + 0.5 * float(_got[k]))
	cf.save(PATH)
