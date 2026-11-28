extends Object

## Browser fullscreen requests (JS), the first-gesture entry and the install prompt. Reaches only the env and hooks leaves.

const Env := preload("res://scripts/display_mode/mode_env.gd")
const Hooks := preload("res://scripts/display_mode/mode_hooks.gd")

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

## Fullscreen the page root, not #canvas: Godot's web virtual keyboard is a hidden <input>/<textarea> beside the
## canvas, and Chromium makes everything outside the fullscreen element inert, so with the canvas fullscreen the
## input could not take focus and no phone keyboard opened. The canvas is the fallback where the root can't go fullscreen.
## bug_report_touch_check.gd pins the order.
const REQUEST_FS_JS := """
	(function () {
		try {
			var c = document.documentElement;
			var fn = c.requestFullscreen || c.webkitRequestFullscreen;
			if (!fn) {
				c = document.getElementById('canvas');
				fn = c && (c.requestFullscreen || c.webkitRequestFullscreen);
			}
			if (!fn) return;
			try { fn.call(c, { keyboardLock: 'browser' }); }
			catch (e1) { fn.call(c); }
		} catch (e) {}
	})();
"""

static func _js_request_fs() -> void:
	Hooks.ensure_web_hooks()
	JavaScriptBridge.eval(REQUEST_FS_JS, true)

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

static func try_fullscreen_gesture() -> bool:
	Hooks.ensure_web_hooks()
	App.web_fullscreen = true
	if App.has_method("save_now"):
		App.save_now()
	Env.lock_landscape()
	if Env.is_web():
		_js_request_fs()
		try_install_prompt()
		return Env.is_fullscreen_now() or Env.is_standalone()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	return true

static func try_install_prompt() -> bool:
	return Env.web_flag("""
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
