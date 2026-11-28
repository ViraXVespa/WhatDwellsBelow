extends Object

## Platform probes shared by the display files: build kind, fullscreen state, browser kind, landscape lock. Reaches nothing else.

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

static func js_flag(src: String) -> bool:
	return str(JavaScriptBridge.eval(src, true)) == "1"

static func probe_ua() -> String:
	return str(JavaScriptBridge.eval("(function(){try{return String(navigator.userAgent||'').toLowerCase()}catch(e){return ''}})();", true)).to_lower()

static func lock_landscape() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("try{if(screen.orientation&&screen.orientation.lock)screen.orientation.lock('landscape').catch(function(){})}catch(e){}", true)

## Run a JS snippet that returns '1' or '0' (false off the web).
static func web_flag(js: String) -> bool:
	if not is_web():
		return false
	return js_flag(js)

static func is_fullscreen_now() -> bool:
	if is_web():
		return js_flag("""
			(function () {
				try {
					if (document.fullscreenElement) return '1';
					if (window.matchMedia && window.matchMedia('(display-mode: fullscreen)').matches) return '1';
					if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return '1';
				} catch (e) {}
				return '0';
			})();
		""")
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

static func is_standalone() -> bool:
	return web_flag("""
		(function () {
			try {
				if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return '1';
				if (window.navigator && window.navigator.standalone) return '1';
			} catch (e) {}
			return '0';
		})();
	""")

static func web_kind() -> String:
	if OS.has_feature("ios") and not is_web():
		return "ios"
	if OS.has_feature("android") and not is_web():
		return "android"
	if not is_web():
		return "web"
	var ua: String = probe_ua()
	if ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("ipod") >= 0:
		return "ios"
	if ua.find("android") >= 0:
		return "android"
	return "web"
