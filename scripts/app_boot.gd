extends Object

const DebugS := preload("res://scripts/debug/debug_menu/debug_menu.gd")
const AnimS := preload("res://scripts/debug/anim_browser.gd")

static func _ready(host: Node) -> void:
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.bal = App.BalanceS.new()
	host.prog = App.ProgressS.new()
	App.Binds.register()
	host.sfx_node = App.SfxS.new()
	host.add_child(host.sfx_node)
	host.tel = App.TelS.new()
	host.playtest = App.PlayS.new()
	host.add_child(host.playtest)
	host.pause_menu = App.PauseS.new()
	host.add_child(host.pause_menu)
	host.recap = App.RecapS.new()
	host.add_child(host.recap)
	host.present = App.PresentS.new()
	host.add_child(host.present)
	host.music = App.MusicS.new()
	host.add_child(host.music)
	host.archives_ui = App.ArchS.new()
	host.add_child(host.archives_ui)
	host.loader = App.LoaderS.new()
	host.add_child(host.loader)
	host.web_pad = App.WebPadS.new()
	host.add_child(host.web_pad)
	host.touch_hud = App.TouchHudS.new()
	host.add_child(host.touch_hud)
	host.get_tree().node_added.connect(host._on_node_added)
	host.get_tree().root.size_changed.connect(host.refresh_ui_text_scale)
	if not App.Smoke.active():
		App.Store.load_slot("live")
	host.set_zoom(host.cam_zoom)
	host.set_hud_scale(host.hud_scale)
	host.refresh_ui_text_scale()
	host.set_sprite_filter(host.sprite_filter, true)
	App.Disp.apply_saved()
	if App.Smoke.active() or "--wdb-debug" in OS.get_cmdline_user_args():
		ensure_debug(host)
		ensure_anim_browser(host)
	else:
		host.call_deferred("ensure_debug")
		host.call_deferred("ensure_anim_browser")
	if "--wdb-debug" in OS.get_cmdline_user_args():
		host.call_deferred("_open_debug")



static func ensure_debug(host: Node) -> void:
	if host.debug != null:
		return
	host.debug = DebugS.new()
	host.add_child(host.debug)


static func ensure_anim_browser(host: Node) -> void:
	if host.anim_browser != null:
		return
	host.anim_browser = AnimS.new()
	host.add_child(host.anim_browser)


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
	App.Pad.tick()
	if host._in_world() and not host.ui_open:
		var vp := host.get_viewport()
		if vp and vp.gui_get_focus_owner() != null:
			vp.gui_release_focus()
	elif (host.ui_open or not host._in_world()) and host.pad_just("interact"):
		var f := host.get_viewport().gui_get_focus_owner()
		if f is BaseButton and not (f as BaseButton).disabled:
			(f as BaseButton).pressed.emit()
	App.AppRun.tick(host, delta)



static func _input(host: Node, event: InputEvent) -> void:
	App.Pad.note_event(event)
	if App.Disp.handle_input(event):
		host.get_viewport().set_input_as_handled()



static func _unhandled_input(host: Node, event: InputEvent) -> void:
	App.Pad.note_event(event)
	if host._menu_loading and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("anim_back")):
		host.archive_cancel = true
		host.get_viewport().set_input_as_handled()
		return
	if host._in_world() and not host.ui_open and event.is_action_pressed("inventory"):
		if host.pause_menu and host.pause_menu.has_method("show_inventory"):
			host.pause_menu.show_inventory()
		host.get_viewport().set_input_as_handled()


