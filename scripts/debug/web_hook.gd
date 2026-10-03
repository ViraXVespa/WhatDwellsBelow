extends Object

## Opt-in web perf hook. Only with ?wdb-playtest in the URL: window.wdbPlaytest(sec) starts one fresh-save AI run
## (Great Axe, real time) through the existing playtester; the finished run's telemetry lands in window.__wdbPlay.
## Pair with ?wdb-seed=42 for a fixed floor. Without the URL flag nothing is registered.

const CliArgs := preload("res://scripts/debug/cli_args.gd")

static var _cb: JavaScriptObject = null

static func register() -> void:
	if not OS.has_feature("web") or not CliArgs.has("--wdb-playtest"):
		return
	_cb = JavaScriptBridge.create_callback(_start)
	JavaScriptBridge.get_interface("window").wdbPlaytest = _cb

static func _start(args: Array) -> void:
	var sec: float = float(args[0]) if args.size() > 0 else 25.0
	App.playtest.enqueue({"save": "fresh", "weapon": "great_axe", "tool": "pickaxe", "gender": "male", "scale": 1.0, "limit": sec, "cfg": {}})

static func publish(d: Dictionary) -> void:
	if _cb == null:
		return
	d["seed"] = App.run_seed
	d["floor"] = App.floor_n
	d["stuck_t"] = snappedf(float(App.playtest.stuck_t), 0.1)
	JavaScriptBridge.eval("window.__wdbPlay=" + JSON.stringify(d), true)
