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
const Touch := preload("res://scripts/input/touch_pad.gd")
const Pad := preload("res://scripts/input/pad.gd")

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

static func _shot_size() -> Vector2i:
	var shot: Vector2i = Args.win_size()
	if shot.x <= 0 or shot.y <= 0:
		shot = Vector2i(1920, 1080)
	return shot


## Called before the scene exists (smoke) and again from attach. Size the OS window to the shot so _ready lays out at that size. Do not reparent and do not park off-screen.
static func hide_window() -> void:
	if Args.show_window():
		return
	var win: Window = Engine.get_main_loop().root as Window
	var shot: Vector2i = _shot_size()
	if win != null:
		win.unfocusable = true
		win.borderless = true
		win.mode = Window.MODE_WINDOWED
		win.size = shot
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(shot)
	printerr("SHOT: mark=window shown=0")


## Move the loaded scene into a SubViewport of the exact shot size. The PNG is that texture. The OS window then drops to a small GL host; a hidden or off-screen window does not draw the child viewport.
static func mount_capture(host: Node) -> void:
	var shot: Vector2i = _shot_size()
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var win: Window = tree.root
	if host.get_parent() != win:
		return
	var snap: SubViewport = SubViewport.new()
	snap.name = "ShotCapture"
	snap.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	snap.handle_input_locally = true
	snap.size = shot
	if Args.show_window():
		var box: SubViewportContainer = SubViewportContainer.new()
		box.name = "ShotCaptureBox"
		box.stretch = true
		win.borderless = true
		win.size = shot
		win.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(snap)
	else:
		win.add_child(snap)
	win.remove_child(host)
	snap.add_child(host)
	tree.current_scene = host
	_route_app_layers(win, snap)
	snap.size = shot + Vector2i(0, 1)
	snap.size = shot
	if not Args.show_window():
		win.size = Vector2i(64, 64)
		DisplayServer.window_set_size(Vector2i(64, 64))
	printerr("SHOT: mark=capture %dx%d" % [shot.x, shot.y])


## App-owned overlays (pause menu, recap, presentation) are CanvasLayers under the root window, which now only
## draws a 64x64 GL host. Point them at the capture viewport so a PNG shows them; their input stays with the root.
static func _route_app_layers(win: Window, snap: SubViewport) -> void:
	var app: Node = win.get_node_or_null("App")
	if app == null:
		return
	# Lay those layers out at the shot size 1:1 (the 64x64 host with stretch expand would size them for a square).
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	win.content_scale_size = snap.size
	for n: Node in app.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).custom_viewport = snap


static func attach_dungeon(host: Node) -> void:
	if not active():
		return
	var scheme := Args.scheme()
	if scheme == "touch":
		Touch.force_show = true
	elif scheme == "gamepad":
		Pad.mode = true
		Touch.force_show = false
	elif scheme == "pc":
		Pad.mode = false
		Touch.force_show = false
	hide_window()
	mount_capture(host)
	if not Args.aim_line():
		App.bal.aim_line_on = false  # this run only: shot saves are isolated (save_guard)
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
