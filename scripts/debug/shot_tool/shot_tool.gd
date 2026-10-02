extends RefCounted

## Standalone postcard worker. Not a numbered P1–P9 smoke.
## CLI: --wdb-shot
## Optional: --wdb-shot-seed=N --wdb-shot-floor=N --wdb-shot-out=PATH
##		   --wdb-shot-scale=PCT --wdb-shot-settle-ms=N

const Args := preload("res://scripts/debug/shot_tool/shot_tool_args.gd")
const Pose := preload("res://scripts/debug/shot_tool/shot_tool_pose.gd")
const Capture := preload("res://scripts/debug/shot_tool/shot_tool_capture.gd")

const FLAG := Args.FLAG

static func active() -> bool:
	return Args.active()

static func scene_name() -> String:
	return Args.scene_name()

static func run_seed() -> int:
	return Args.run_seed()

static func floor_n() -> int:
	return Args.floor_n()

static func hide_window() -> void:
	var win: Window = Engine.get_main_loop().root as Window
	if win != null:
		win.unfocusable = true
		win.borderless = true
		win.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(-32000, -32000))
	printerr("SHOT: mark=window shown=0")
static func attach_dungeon(host: Node) -> void:
	if not active():
		return
	hide_window()
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var rd := RenderingServer.get_rendering_device()
	printerr("SHOT: mark=renderer method=%s rd=%s" % [method, "0" if rd == null else "1"])
	printerr("SHOT: mark=attach seed=%d floor=%d scale=%d out=%s" % [run_seed(), floor_n(), Args.scale_pct(), Args.out_path()])
	Pose._apply_pose(host)
	var tree: SceneTree = host.get_tree()
	var sec: float = Args.settle_sec()
	if sec <= 0.0:
		tree.process_frame.connect(func() -> void: Capture._arm_capture(host), CONNECT_ONE_SHOT)
		return
	tree.create_timer(sec).timeout.connect(func() -> void: Capture._arm_capture(host))
