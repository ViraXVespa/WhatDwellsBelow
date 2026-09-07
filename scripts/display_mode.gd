extends Object

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
	if OS.has_feature("ios") and not is_web():
		return "ios"
	if OS.has_feature("android") and not is_web():
		return "android"
	if not is_web():
		return "web"
	var ua: String = _probe_ua()
	if ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("ipod") >= 0:
		return "ios"
	if ua.find("android") >= 0:
		return "android"
	return "web"


static func is_standalone() -> bool:
	if not is_web():
		return false
	return _js_flag("""
		(function () {
			try {
				if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return '1';
				if (window.navigator && window.navigator.standalone) return '1';
			} catch (e) {}
			return '0';
		})();
	""")


static func is_fullscreen_now() -> bool:
	if is_web():
		return _js_flag("""
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
	if is_standalone() or is_fullscreen_now() or gate_seen():
		return false
	return true


static func apply_saved() -> void:
	if is_xbox():
		return
	ensure_web_hooks()
	if uses_desktop_modes():
		set_desktop_mode(str(App.display_mode), false)
		return
	lock_landscape()


static func set_desktop_mode(mode: String, persist: bool = true) -> void:
	if not uses_desktop_modes():
		return
	var next: String = mode
	if next != "windowed" and next != "exclusive":
		next = "borderless"
	App.display_mode = next
	if next == "borderless" or next == "exclusive":
		App.display_fs_kind = next
	if next == "windowed":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif next == "exclusive":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if persist and App.has_method("save_now"):
		App.save_now()


static func cycle_desktop() -> void:
	var cur: String = str(App.display_mode)
	var nxt: String = "borderless"
	if cur == "windowed":
		nxt = "borderless"
	elif cur == "borderless":
		nxt = "exclusive"
	else:
		nxt = "windowed"
	set_desktop_mode(nxt)


static func desktop_label() -> String:
	var cur: String = str(App.display_mode)
	if cur == "windowed":
		return "Display: Windowed"
	if cur == "exclusive":
		return "Display: True fullscreen"
	return "Display: Borderless fullscreen"


static func set_web_fullscreen(on: bool, persist: bool = true) -> void:
	App.web_fullscreen = on
	if is_web():
		if on:
			_js_request_fs()
		else:
			_js_exit_fs()
	elif OS.has_feature("android") or OS.has_feature("ios"):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	lock_landscape()
	if persist and App.has_method("save_now"):
		App.save_now()


static func toggle_web_fullscreen() -> void:
	var on: bool = not bool(App.web_fullscreen)
	if is_web():
		on = not is_fullscreen_now()
	set_web_fullscreen(on)


static func web_label() -> String:
	if is_web() and is_fullscreen_now():
		return "Fullscreen: On"
	if bool(App.web_fullscreen):
		return "Fullscreen: On"
	return "Fullscreen: Off"


static func try_fullscreen_gesture() -> bool:
	ensure_web_hooks()
	App.web_fullscreen = true
	if App.has_method("save_now"):
		App.save_now()
	lock_landscape()
	if is_web():
		_js_request_fs()
		try_install_prompt()
		return is_fullscreen_now() or is_standalone()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	return true


static func try_install_prompt() -> bool:
	if not is_web():
		return false
	return _js_flag("""
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


static func toggle_alt_enter() -> void:
	if is_xbox():
		return
	if uses_desktop_modes():
		if is_fullscreen_now():
			set_desktop_mode("windowed")
			return
		var kind: String = str(App.display_fs_kind)
		if kind != "exclusive":
			kind = "borderless"
		set_desktop_mode(kind)
		return
	if uses_web_fs_toggle():
		set_web_fullscreen(not is_fullscreen_now())


static func handle_input(event: InputEvent) -> bool:
	if is_xbox():
		return false
	if not uses_desktop_modes() and not uses_web_fs_toggle():
		return false
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	if (k.keycode == KEY_W or k.keycode == KEY_Q) and (k.ctrl_pressed or k.meta_pressed):
		request_quit()
		return true
	if k.keycode == KEY_F4 and k.alt_pressed:
		request_quit()
		return true
	if k.keycode != KEY_ENTER and k.keycode != KEY_KP_ENTER:
		return false
	if not k.alt_pressed:
		return false
	toggle_alt_enter()
	return true


static func request_quit() -> void:
	if is_xbox():
		return
	if is_web():
		_js_close()
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit()


static func ensure_web_hooks() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("""
		(function () {
			if (window.__wdbFsHooks3) return;
			window.__wdbFsHooks3 = 1;
			window.__wdbEsc = 0;
			function unlockFs() {
				try { if (navigator.keyboard && navigator.keyboard.unlock) navigator.keyboard.unlock(); } catch (e) {}
				try {
					var fn = document.exitFullscreen || document.webkitExitFullscreen;
					if (fn && document.fullscreenElement) fn.call(document);
				} catch (e) {}
			}
			document.addEventListener('keydown', function (e) {
				var k = e.key || e.code;
				var closeChord = ((e.ctrlKey || e.metaKey) && (k === 'w' || k === 'W' || k === 'KeyW' || k === 'q' || k === 'Q' || k === 'KeyQ')) || (e.altKey && (k === 'F4' || k === 'F4'));
				if (closeChord) {
					unlockFs();
					try { window.close(); } catch (err) {}
					return;
				}
				if (k === 'F1' || k === 'Help') {
					e.preventDefault();
					if (e.stopPropagation) e.stopPropagation();
					window.__wdbEsc = 1;
					return;
				}
				if (k !== 'Escape' && k !== 'Esc') return;
				if (!document.fullscreenElement) return;
				e.preventDefault();
				if (e.stopPropagation) e.stopPropagation();
				window.__wdbEsc = 1;
			}, true);
			document.addEventListener('fullscreenchange', function () {
				try {
					if (document.fullscreenElement && navigator.keyboard && navigator.keyboard.lock) {
						navigator.keyboard.lock(['Escape']);
					} else if (navigator.keyboard && navigator.keyboard.unlock) {
						navigator.keyboard.unlock();
					}
				} catch (err) {}
			});
		})();
	""", true)


static func consume_web_esc() -> bool:
	if not is_web():
		return false
	ensure_web_hooks()
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
	ensure_web_hooks()
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


static func _js_flag(src: String) -> bool:
	return str(JavaScriptBridge.eval(src, true)) == "1"


static func _probe_ua() -> String:
	return str(JavaScriptBridge.eval("(function(){try{return String(navigator.userAgent||'').toLowerCase()}catch(e){return ''}})();", true)).to_lower()
