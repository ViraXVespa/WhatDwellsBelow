extends RefCounted

## Standalone postcard worker. Not a numbered P1–P9 smoke.
## CLI: --wdb-shot
## Optional: --wdb-shot-seed=N --wdb-shot-floor=N --wdb-shot-out=PATH
##		   --wdb-shot-scale=PCT --wdb-shot-settle-ms=N
## Scripted flow: --wdb-shot-steps=FILE.json [--wdb-shot-frames=DIR] [--wdb-shot-nopix=1]
##		   (step_runner.gd; ops in step_ops.gd; design/shot-tool.md)

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")
const Pose := preload("res://scripts/debug/shot_tool/tool_pose.gd")
const Capture := preload("res://scripts/debug/shot_tool/capture.gd")
const Guard := preload("res://scripts/debug/shot_tool/save_guard.gd")

const FLAG := Args.FLAG

static func active() -> bool:
	return Args.active()

static func scene_name() -> String:
	return Args.scene_name()

## Non-empty when the flow boots a menu screen (title / splash / fs_gate) instead of a world.
static func screen_path() -> String:
	return Args.screen_path()

## Boot a menu screen for the shot tool: refuse (fail loudly) unless saves are isolated, then load the scene and arm the capture on it.
static func boot_screen(tree: SceneTree) -> void:
	var why: String = Guard.arm()
	if not why.is_empty():
		printerr("SHOT: ok=false err=isolation %s" % why)
		tree.quit(1)
		return
	var want: String = Args.screen_path()
	tree.call_deferred("change_scene_to_file", want)
	for _i: int in 900:
		await tree.process_frame
		var cs: Node = tree.current_scene
		if cs != null and cs.scene_file_path == want:
			attach_dungeon(cs)
			return
	printerr("SHOT: ok=false err=screen_never_loaded %s" % want)
	tree.quit(1)

static func run_seed() -> int:
	return Args.run_seed()

static func floor_n() -> int:
	return Args.floor_n()

static func hide_window() -> void:
	if Args.show_window():
		return
	var win: Window = Engine.get_main_loop().root as Window
	if win != null:
		win.unfocusable = true
		win.borderless = true
		win.mode = Window.MODE_WINDOWED
		if Args.win_size().x > 0 and Args.win_size().y > 0:
			win.size = Args.win_size()
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
