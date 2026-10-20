extends Object

## Hub menus open in one frame. Two parts, both before the hub loader lifts:
## start() (title screen, then Play): every object frame's baked art PNG and the progress panel scripts load
##   threaded (ResourceLoader; a load() inside a WorkerThreadPool task leaks its load token at exit), and wait()
##   builds each frame skin once on the main thread from those cached PNGs (cached by each *_art.gd).
## finish(scene): makes the hub's menu host, then opens the heavy menus once under the solid loader so fonts,
##   frame art and the gear board are on the GPU, and closes them without saving or sounds.
## A new menu, tab or object frame: add its row to open_timing.gd first; if its first open is over the budget,
## open it in one of the steps below (each step is one hidden frame, so keep the list to the heavy ones).

const UiSession := preload("res://scripts/ui/ui_session.gd")
const PauseFlow := preload("res://scripts/ui/pause_menu/menu_flow.gd")
const BtnSkin := preload("res://scripts/ui/btn_skin.gd")
const HOST_PATH := "res://scripts/ui/progress_ui.gd"
const FRAME_SET := "res://scripts/ui/progress_ui/frame_set.gd"

const ART_DIR := "res://assets/ui/frames/"

static var _task: int = -1
static var _art: PackedStringArray = PackedStringArray()

static func start() -> void:
	if _task != -1:
		return
	BtnSkin.prewarm()
	## A nothreads web export never finishes load_threaded_request: status stays
	## IN_PROGRESS and load_threaded_get spins on the main thread. finish() draws
	## the art on that build, still behind the loader. Desktop loads the PNGs threaded.
	if not OS.has_feature("threads"):
		_task = -2
		return
	ResourceLoader.load_threaded_request(HOST_PATH)
	for dir: String in ResourceLoader.list_directory(ART_DIR):
		for f: String in ResourceLoader.list_directory(ART_DIR + dir):
			if f.ends_with(".png"):
				_art.append(ART_DIR + dir + f)
				ResourceLoader.load_threaded_request(_art[-1])
	_task = 1

static func _draw_art() -> void:
	var skins: Array = (load(FRAME_SET) as GDScript).get("SKINS")
	for skin: GDScript in skins:
		var scratch := Control.new()
		skin.build(scratch)
		scratch.free()

static func wait() -> void:
	if _task >= 0:
		var held: Array[Resource] = []
		for p: String in _art:
			if ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				held.append(ResourceLoader.load_threaded_get(p))
		_art.clear()
		_draw_art()
		_task = -2
	if not OS.has_feature("threads"):
		ResourceLoader.load(HOST_PATH)
		return
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
