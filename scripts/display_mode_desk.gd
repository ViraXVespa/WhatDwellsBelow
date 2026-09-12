extends Object

const Web := preload("res://scripts/display_mode_web.gd")

static func _js_close() -> void:
	JavaScriptBridge.eval("""
		(function () {
			try { if (navigator.keyboard && navigator.keyboard.unlock) navigator.keyboard.unlock(); } catch (e) {}
			try {
				var fn = document.exitFullscreen || document.webkitExitFullscreen;
				if (fn && document.fullscreenElement) fn.call(document);
			} catch (e) {}
			try { window.close(); } catch (e) {}
		})();
	""", true)

static func _js_request_fs() -> void:
	Web.ensure_web_hooks()
	JavaScriptBridge.eval("""
		(function () {
			try {
				var c = document.getElementById('canvas') || document.documentElement;
				var fn = c.requestFullscreen || c.webkitRequestFullscreen;
				if (!fn) return;
				try { fn.call(c, { keyboardLock: 'browser' }); }
				catch (e1) { fn.call(c); }
			} catch (e) {}
		})();
	""", true)

static func web_kind() -> String:
	var _fac = load("res://scripts/display_mode.gd")
	if OS.has_feature("ios") and not _fac.is_web():
		return "ios"
	if OS.has_feature("android") and not _fac.is_web():
		return "android"
	if not _fac.is_web():
		return "web"
	var ua: String = _fac._probe_ua()
	if ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("ipod") >= 0:
		return "ios"
	if ua.find("android") >= 0:
		return "android"
	return "web"

static func _js_exit_fs() -> void:
	JavaScriptBridge.eval("""
		(function () {
			try { if (navigator.keyboard && navigator.keyboard.unlock) navigator.keyboard.unlock(); } catch (e) {}
			try {
				var fn = document.exitFullscreen || document.webkitExitFullscreen;
				if (fn && document.fullscreenElement) fn.call(document);
			} catch (e) {}
		})();
	""", true)

static func toggle_alt_enter() -> void:
	var _fac = load("res://scripts/display_mode.gd")
	if _fac.is_xbox():
		return
	if _fac.uses_desktop_modes():
		if Web.is_fullscreen_now():
			Web.set_desktop_mode("windowed")
			return
		var kind: String = str(App.display_fs_kind)
		if kind != "exclusive":
			kind = "borderless"
		Web.set_desktop_mode(kind)
		return
	if _fac.uses_web_fs_toggle():
		Web.set_web_fullscreen(not Web.is_fullscreen_now())

static func try_fullscreen_gesture() -> bool:
	var _fac = load("res://scripts/display_mode.gd")
	Web.ensure_web_hooks()
	App.web_fullscreen = true
	if App.has_method("save_now"):
		App.save_now()
	_fac.lock_landscape()
	if _fac.is_web():
		_js_request_fs()
		try_install_prompt()
		return Web.is_fullscreen_now() or is_standalone()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	return true

static func is_standalone() -> bool:
	var _fac = load("res://scripts/display_mode.gd")
	if not _fac.is_web():
		return false
	return _fac._js_flag("""
		(function () {
			try {
				if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return '1';
				if (window.navigator && window.navigator.standalone) return '1';
			} catch (e) {}
			return '0';
		})();
	""")

static func try_install_prompt() -> bool:
	var _fac = load("res://scripts/display_mode.gd")
	if not _fac.is_web():
		return false
	return _fac._js_flag("""
		(function () {
			try {
				var p = window.__wdbInstallPrompt;
				if (!p || !p.prompt) return '0';
				p.prompt();
				window.__wdbInstallPrompt = null;
				return '1';
			} catch (e) { return '0'; }
		})();
	""")

static func cycle_desktop() -> void:
	var cur: String = str(App.display_mode)
	var nxt: String = "borderless"
	if cur == "windowed":
		nxt = "borderless"
	elif cur == "borderless":
		nxt = "exclusive"
	else:
		nxt = "windowed"
	Web.set_desktop_mode(nxt)
