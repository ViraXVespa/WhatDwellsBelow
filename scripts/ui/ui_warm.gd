extends Object

## Hub menus open in one frame. Two parts, both before the hub loader lifts:
## start() (title screen, then Play): a worker thread draws every object frame's code-drawn art once (cached by
##   each *_art.gd) and the progress panel scripts load threaded.
## finish(scene): makes the hub's menu host, then opens the heavy menus once under the solid loader so fonts,
##   frame art and the gear board are on the GPU, and closes them without saving or sounds.
## A new menu, tab or object frame: add its row to open_timing.gd first; if its first open is over the budget,
## open it in one of the steps below (each step is one hidden frame, so keep the list to the heavy ones).

const UiSession := preload("res://scripts/ui/ui_session.gd")
const PauseFlow := preload("res://scripts/ui/pause_menu/menu_flow.gd")
const HOST_PATH := "res://scripts/ui/progress_ui.gd"
const FRAME_SET := "res://scripts/ui/progress_ui/frame_set.gd"

static var _task: int = -1

static func start() -> void:
	if _task != -1:
		return
	ResourceLoader.load_threaded_request(HOST_PATH)
	## Web builds have no threads: the art is drawn by finish(), still behind the loader.
	if not OS.has_feature("threads"):
		_task = -2
		return
	_task = WorkerThreadPool.add_task(_draw_art, true, "ui art")

static func _draw_art() -> void:
	var skins: Array = (load(FRAME_SET) as GDScript).get("SKINS")
	for skin: GDScript in skins:
		var scratch := Control.new()
		skin.build(scratch)
		scratch.free()

static func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2
	if ResourceLoader.load_threaded_get_status(HOST_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(HOST_PATH)

static func finish(scene: Node) -> void:
	wait()
	if scene == null or not scene.has_method("ensure_ui"):
		return
	scene.ensure_ui()
	var ui: CanvasLayer = scene.get("ui")
	var was_open: bool = App.ui_open
	var was_paused: bool = scene.get_tree().paused
	var pm: CanvasLayer = App.pause_menu
	var rc: CanvasLayer = App.recap
	ui.open_anvil()
	if pm:
		pm.show_menu()
	if rc:
		rc.play("death")
		rc.set_process(false)
	await _frame(scene)
	ui.close_ui()
	ui.open_vendor()
	if pm:
		pm.show_inventory()
	if rc:
		rc.set("draining", false)
		_quiet(rc)
	await _frame(scene)
	ui.close_ui()
	ui.open_loadout()
	if pm:
		PauseFlow.close_ui(pm, true)
	await _frame(scene)
	ui.close_ui()
	ui.open_controls()
	await _frame(scene)
	ui.close_ui()
	App.ui_open = was_open
	scene.get_tree().paused = was_paused

static func _frame(scene: Node) -> void:
	RenderingServer.force_draw()
	await scene.get_tree().process_frame

## Hide the recap without its own close (that applies the run).
static func _quiet(host: CanvasLayer) -> void:
	host.set("open", false)
	host.visible = false
	UiSession.close(host)
