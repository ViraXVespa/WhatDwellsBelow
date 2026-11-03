extends Object

## Opt-in web perf hook. Only with ?wdb-playtest in the URL: window.wdbPlaytest(sec) starts one fresh-save AI run
## (Great Axe, real time) through the existing playtester; the finished run's telemetry lands in window.__wdbPlay.
## window.wdbZoom(z) sets the camera zoom (App.set_zoom, 1.0-4.0) for close-up shots.
## window.wdbEnter() takes the player's own way in (App.enter_dungeon: cover, load, reveal). Pair with ?wdb-seed=42 for a fixed floor. window.wdbBugDry() posts one bug_report dry run (relay stores nothing) and puts {code, labels, email, at} in window.__wdbBug.
## Without the URL flag nothing is registered.

const CliArgs := preload("res://scripts/app/cli_args.gd")

static var _cb: JavaScriptObject = null
static var _enter_cb: JavaScriptObject = null
static var _zoom_cb: JavaScriptObject = null
static var _bug_cb: JavaScriptObject = null

static func register() -> void:
	if not OS.has_feature("web") or not CliArgs.has("--wdb-playtest"):
		return
	_cb = JavaScriptBridge.create_callback(_start)
	JavaScriptBridge.get_interface("window").wdbPlaytest = _cb
	_enter_cb = JavaScriptBridge.create_callback(func(_a: Array): App.enter_dungeon())
	JavaScriptBridge.get_interface("window").wdbEnter = _enter_cb
	_zoom_cb = JavaScriptBridge.create_callback(func(a: Array): App.set_zoom(float(a[0]) if a.size() > 0 else 1.0))
	JavaScriptBridge.get_interface("window").wdbZoom = _zoom_cb
	_bug_cb = JavaScriptBridge.create_callback(func(_a: Array): _bug_dry())
	JavaScriptBridge.get_interface("window").wdbBugDry = _bug_cb

static func _start(args: Array) -> void:
	var sec: float = float(args[0]) if args.size() > 0 else 25.0
	App.playtest.enqueue({"save": "fresh", "weapon": "great_axe", "tool": "pickaxe", "gender": "male", "scale": 1.0, "limit": sec, "cfg": {}})

static func publish(d: Dictionary) -> void:
	if _cb == null:
		return
	d["seed"] = App.run_seed
	d["floor"] = App.floor_n
	d["stuck_t"] = snappedf(float(App.playtest.stuck_t), 0.1)
	d.merge(App.playtest.perf_report())
	JavaScriptBridge.eval("window.__wdbPlay=" + JSON.stringify(d), true)

static func _bug_dry() -> void:
	var send: GDScript = load("res://scripts/app/bug_report/bug_send.gd")
	send.post(send.payload({"area": 0, "kind": 0, "details": "web export dry run"}, "", true), func(code: int, data: Dictionary) -> void:
		var raw: String = JSON.stringify(data)
		var issue: Variant = data.get("issue", data)
		var labels: Variant = issue.get("labels", []) if issue is Dictionary else []
		JavaScriptBridge.eval("window.__wdbBug=" + JSON.stringify({"code": code, "labels": labels, "email": data.get("email"), "at": raw.substr(maxi(raw.find("@") - 40, 0), 80) if raw.contains("@") else "", "keys": data.keys()}), true))
