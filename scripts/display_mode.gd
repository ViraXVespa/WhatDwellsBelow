extends Object
const Web := preload("res://scripts/display_mode_web.gd")
const Desk := preload("res://scripts/display_mode_desk.gd")

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

static func set_desktop_mode(mode: String, persist: bool = true) -> void:
	Web.set_desktop_mode(mode, persist)

static func cycle_desktop() -> void:
	Desk.cycle_desktop()

static func desktop_label() -> String:
	var cur: String = str(App.display_mode)
	if cur == "windowed":
		return "Display: Windowed"
	if cur == "exclusive":
		return "Display: True fullscreen"
	return "Display: Borderless fullscreen"

static func set_web_fullscreen(on: bool, persist: bool = true) -> void:
	Web.set_web_fullscreen(on, persist)

static func toggle_web_fullscreen() -> void:
	var on: bool = not bool(App.web_fullscreen)
	if is_web():
		on = not Web.is_fullscreen_now()
	Web.set_web_fullscreen(on)

static func web_label() -> String:
	if is_web() and Web.is_fullscreen_now():
		return "Fullscreen: On"
	if bool(App.web_fullscreen):
		return "Fullscreen: On"
	return "Fullscreen: Off"

static func try_fullscreen_gesture() -> bool:
	return Desk.try_fullscreen_gesture()

static func try_install_prompt() -> bool:
	return Desk.try_install_prompt()

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
	return _js_flag("""
		(function () {
			try {
				if (window.__wdbEsc) { window.__wdbEsc = 0; return '1'; }
			} catch (e) {}
			return '0';
		})();
	""")

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

static func _js_close() -> void:
	Desk._js_close()

static func _js_flag(src: String) -> bool:
	return str(JavaScriptBridge.eval(src, true)) == "1"

static func _probe_ua() -> String:
	return str(JavaScriptBridge.eval("(function(){try{return String(navigator.userAgent||'').toLowerCase()}catch(e){return ''}})();", true)).to_lower()
