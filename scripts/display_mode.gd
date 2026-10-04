extends Object
const Web := preload("res://scripts/display_mode/mode_web.gd")
const Desk := preload("res://scripts/display_mode/mode_desk.gd")

## Desktop window modes, web fullscreen / PWA, session gate, landscape lock.

static func is_web() -> bool:
	return OS.has_feature("web")

static func is_xbox() -> bool:
	return OS.has_feature("xbox")

static func uses_desktop_modes() -> bool:
	if is_web() or is_xbox():
		return false
	if OS.has_feature("android") or OS.has_feature("ios"):
		return false
	return true

static func uses_web_fs_toggle() -> bool:
	if is_xbox():
		return false
	return is_web() or OS.has_feature("android") or OS.has_feature("ios")

static func web_kind() -> String:
	return Desk.web_kind()

static func is_standalone() -> bool:
	return Desk.is_standalone()

static func is_fullscreen_now() -> bool:
	return Web.is_fullscreen_now()

static func gate_seen() -> bool:
	if not is_web():
		return false
	return _js_flag("""
		(function () {
			try { return sessionStorage.getItem('wdb_fs_gate_seen') === '1' ? '1' : '0'; }
			catch (e) { return '0'; }
		})();
	""")

static func mark_gate_seen() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("try{sessionStorage.setItem('wdb_fs_gate_seen','1')}catch(e){}", true)

static func wants_gate() -> bool:
	if not is_web() or is_xbox():
		return false
	if Desk.is_standalone() or Web.is_fullscreen_now() or gate_seen():
		return false
	return true

static func apply_saved() -> void:
	if is_xbox():
		return
	Web.ensure_web_hooks()
	if uses_desktop_modes():
		Web.set_desktop_mode(str(App.display_mode), false)
		return
	lock_landscape()

static func cycle_desktop() -> void:
	Desk.cycle_desktop()

static func desktop_label() -> String:
	var cur: String = str(App.display_mode)
	if cur == "windowed":
		return App.tr("display_mode.display_windowed")
	if cur == "exclusive":
		return App.tr("display_mode.display_true_fullscreen")
	return App.tr("display_mode.display_borderless_fullscreen")

static func set_web_fullscreen(on: bool, persist: bool = true) -> void:
	Web.set_web_fullscreen(on, persist)

static func toggle_web_fullscreen() -> void:
	var on: bool = not bool(App.web_fullscreen)
	if is_web():
		on = not Web.is_fullscreen_now()
	Web.set_web_fullscreen(on)

static func web_label() -> String:
	if is_web() and Web.is_fullscreen_now():
		return App.tr("common.fullscreen_on")
	if bool(App.web_fullscreen):
		return App.tr("common.fullscreen_on")
	return App.tr("display_mode.fullscreen_off")

static func try_fullscreen_gesture() -> bool:
	return Desk.try_fullscreen_gesture()

static func toggle_alt_enter() -> void:
	Desk.toggle_alt_enter()

static func handle_input(event: InputEvent) -> bool:
	return Web.handle_input(event)

static func request_quit() -> void:
	if is_xbox():
		return
	if is_web():
		Desk._js_close()
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit()

static func ensure_web_hooks() -> void:
	Web.ensure_web_hooks()

static func consume_web_esc() -> bool:
	if not is_web():
		return false
	Web.ensure_web_hooks()
	var v := str(JavaScriptBridge.eval("""
		(function () {
			try {
				if (window.__wdbEsc) { var v = window.__wdbEsc; window.__wdbEsc = 0; return String(v); }
			} catch (e) {}
			return '0';
		})();
	""", true))
	if v == "2" and not _esc_is_pause():
		send_esc()
		return false
	return v != "0"

## Browser fullscreen swallows Esc; the page hook reports it (2) and F1 (1, always pause). When Esc is
## not the pause bind, hand the key to the game as a normal Escape press so it acts as its bound action.
static func _esc_is_pause() -> bool:
	for e in InputMap.action_get_events("pause"):
		if e is InputEventKey and (e.physical_keycode == KEY_ESCAPE or e.keycode == KEY_ESCAPE):
			return true
	return false

static func send_esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)

static func lock_landscape() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("try{if(screen.orientation&&screen.orientation.lock)screen.orientation.lock('landscape').catch(function(){})}catch(e){}", true)

static func viewport_portrait() -> bool:
	var sz: Vector2i = DisplayServer.window_get_size()
	return sz.y > sz.x

static func _js_request_fs() -> void:
	Desk._js_request_fs()

static func _js_exit_fs() -> void:
	Desk._js_exit_fs()

static func _js_flag(src: String) -> bool:
	return str(JavaScriptBridge.eval(src, true)) == "1"

static func _probe_ua() -> String:
	return str(JavaScriptBridge.eval("(function(){try{return String(navigator.userAgent||'').toLowerCase()}catch(e){return ''}})();", true)).to_lower()
