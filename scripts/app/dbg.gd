extends Object

## Release-safe door to scripts/debug/. Release exports leave that folder out of the PCK, so shared code never
## preloads it: every call here loads a debug script only in a debug build (OS "debug" feature) and only when it is
## present. `--wdb-release` makes a debug binary act as a release build (smokes test the release path headless).

const DIR := "res://scripts/debug/"
const CliArgs := preload("res://scripts/app/cli_args.gd")

static var _on: int = -1
static var _cache: Dictionary = {}

static func on() -> bool:
	if _on < 0:
		_on = 1 if OS.has_feature("debug") and not CliArgs.has("--wdb-release") and ResourceLoader.exists(DIR + "smoke.gd") else 0
	return _on == 1

## The debug script `name` (path under scripts/debug/, no .gd), or null in a release build.
static func script(name: String) -> GDScript:
	if not on():
		return null
	if not _cache.has(name):
		var p := DIR + name + ".gd"
		_cache[name] = load(p) as GDScript if ResourceLoader.exists(p) else null
	return _cache[name]

## A new instance of debug script `name`, or null in a release build.
static func make(name: String) -> Object:
	var s := script(name)
	return s.new() if s else null

static func hitch(reason: String, origin: Vector2i = Vector2i.ZERO) -> void:
	var s := script("hitch_log")
	if s:
		s.mark(reason, origin)

static func hitch_begin(host: Node) -> void:
	var s := script("hitch_log")
	if s:
		s.begin(host)
		host.tree_exiting.connect(func(): s.close())

static func hitch_tick(host: Node, delta: float) -> void:
	var s := script("hitch_log")
	if s:
		s.tick(host, delta)

static func lt_mark(id: String) -> void:
	var s := script("load_timing")
	if s:
		s.mark(id)

static func lt_dmark(id: String) -> void:
	var s := script("load_timing")
	if s:
		s.dmark(id)

static func lt_note(key: String, val: String) -> void:
	var s := script("load_timing")
	if s:
		s.note(key, val)

static func lt_dnote(key: String, val: String) -> void:
	var s := script("load_timing")
	if s:
		s.dnote(key, val)

static func lt_finish() -> void:
	var s := script("load_timing")
	if s:
		s.finish()

static func smoke_active() -> bool:
	var s := script("smoke")
	return s != null and bool(s.active())

static func smoke_phase(n: int) -> bool:
	var s := script("smoke")
	return s != null and bool(s.phase(n))

static func smoke_hold_player() -> bool:
	var s := script("smoke")
	return s != null and bool(s.hold_player())

static func smoke_route_boot() -> bool:
	var s := script("smoke")
	return s != null and bool(s.route_boot())

## Smoke.attach_<what>(host): foundation, dungeon or camp.
static func smoke_attach(what: String, host: Node) -> void:
	var s := script("smoke")
	if s:
		s.call("attach_" + what, host)
