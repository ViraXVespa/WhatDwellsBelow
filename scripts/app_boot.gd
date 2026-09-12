extends Object

const BalanceS := preload("res://scripts/data/balance.gd")
const DebugS := preload("res://scripts/combat/debug_menu.gd")
const SfxS := preload("res://scripts/combat/sfx.gd")
const ProgressS := preload("res://scripts/data/progress.gd")
const TelS := preload("res://scripts/debug/telemetry.gd")
const PauseS := preload("res://scripts/ui/pause_menu.gd")
const RecapS := preload("res://scripts/ui/recap.gd")
const Store := preload("res://scripts/data/save_store.gd")
const PresentS := preload("res://scripts/ui/present.gd")
const MusicS := preload("res://scripts/audio/music.gd")
const AnimS := preload("res://scripts/debug/anim_browser.gd")
const ArchS := preload("res://scripts/ui/archives_ui.gd")
const PlayS := preload("res://scripts/debug/playtest.gd")
const LoaderS := preload("res://scripts/ui/loader.gd")
const Smoke := preload("res://scripts/debug/smoke.gd")
const Binds := preload("res://scripts/input/binds.gd")
const Pad := preload("res://scripts/input/pad.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")
const TouchHudS := preload("res://scripts/ui/touch_hud.gd")
const WebPadS := preload("res://scripts/web_pad.gd")
const AppFlow := preload("res://scripts/app_flow.gd")
const AppRun := preload("res://scripts/app_run.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const Disp := preload("res://scripts/display_mode.gd")
const AppSet := preload("res://scripts/app_set.gd")

static func _ready(host: Node) -> void:
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.bal = BalanceS.new()
	host.prog = ProgressS.new()
	Binds.register()
	host.sfx_node = SfxS.new()
	host.add_child(host.sfx_node)
	host.tel = TelS.new()
	host.playtest = PlayS.new()
	host.add_child(host.playtest)
	host.debug = DebugS.new()
	host.add_child(host.debug)
	host.pause_menu = PauseS.new()
	host.add_child(host.pause_menu)
	host.recap = RecapS.new()
	host.add_child(host.recap)
	host.present = PresentS.new()
	host.add_child(host.present)
	host.music = MusicS.new()
	host.add_child(host.music)
	host.anim_browser = AnimS.new()
	host.add_child(host.anim_browser)
	host.archives_ui = ArchS.new()
	host.add_child(host.archives_ui)
	host.loader = LoaderS.new()
	host.add_child(host.loader)
	host.web_pad = WebPadS.new()
	host.add_child(host.web_pad)
	host.touch_hud = TouchHudS.new()
	host.add_child(host.touch_hud)
	host.get_tree().node_added.connect(host._on_node_added)
	host.get_tree().root.size_changed.connect(host.refresh_ui_text_scale)
	if not Smoke.active():
		Store.load_slot("live")
	host.set_zoom(host.cam_zoom)
	host.set_hud_scale(host.hud_scale)
	host.refresh_ui_text_scale()
	host.set_sprite_filter(host.sprite_filter, true)
	Disp.apply_saved()
	if "--wdb-debug" in OS.get_cmdline_user_args():
		host.call_deferred("_open_debug")



static func hitstop(host: Node, sec: float) -> void:
	if host.playtest and bool(host.playtest.get("live_running")):
		return
	if sec <= 0.0:
		return
	if Engine.time_scale < 0.5:
		return
	Engine.time_scale = 0.07
	host.get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)



static func _process(host: Node, delta: float) -> void:
	Pad.tick()
	if host._in_world() and not host.ui_open:
		var vp := host.get_viewport()
		if vp and vp.gui_get_focus_owner() != null:
			vp.gui_release_focus()
	elif (host.ui_open or not host._in_world()) and host.pad_just("interact"):
		var f := host.get_viewport().gui_get_focus_owner()
		if f is BaseButton and not (f as BaseButton).disabled:
			(f as BaseButton).pressed.emit()
	AppRun.tick(host, delta)



static func _input(host: Node, event: InputEvent) -> void:
	Pad.note_event(event)
	if Disp.handle_input(event):
		host.get_viewport().set_input_as_handled()



static func _unhandled_input(host: Node, event: InputEvent) -> void:
	Pad.note_event(event)
	if host._menu_loading and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back")):
		host.archive_cancel = true
		host.get_viewport().set_input_as_handled()
		return
	if host._in_world() and not host.ui_open and event.is_action_pressed("inventory"):
		if host.pause_menu and host.pause_menu.has_method("show_inventory"):
			host.pause_menu.show_inventory()
		host.get_viewport().set_input_as_handled()



