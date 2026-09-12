extends Object

static func ensure_web_hooks() -> void:
	var _fac = load("res://scripts/display_mode.gd")
	if not _fac.is_web():
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

static func set_desktop_mode(mode: String, persist: bool = true) -> void:
	var _fac = load("res://scripts/display_mode.gd")
	if not _fac.uses_desktop_modes():
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

static func handle_input(event: InputEvent) -> bool:
	var _fac = load("res://scripts/display_mode.gd")
	if _fac.is_xbox():
		return false
	if not _fac.uses_desktop_modes() and not _fac.uses_web_fs_toggle():
		return false
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	if (k.keycode == KEY_W or k.keycode == KEY_Q) and (k.ctrl_pressed or k.meta_pressed):
		_fac.request_quit()
		return true
	if k.keycode == KEY_F4 and k.alt_pressed:
		_fac.request_quit()
		return true
	if k.keycode != KEY_ENTER and k.keycode != KEY_KP_ENTER:
		return false
	if not k.alt_pressed:
		return false
	load("res://scripts/display_mode_desk.gd").toggle_alt_enter()
	return true

static func is_fullscreen_now() -> bool:
	var _fac = load("res://scripts/display_mode.gd")
	if _fac.is_web():
		return _fac._js_flag("""
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

static func set_web_fullscreen(on: bool, persist: bool = true) -> void:
	var _fac = load("res://scripts/display_mode.gd")
	App.web_fullscreen = on
	if _fac.is_web():
		if on:
			load("res://scripts/display_mode_desk.gd")._js_request_fs()
		else:
			load("res://scripts/display_mode_desk.gd")._js_exit_fs()
	elif OS.has_feature("android") or OS.has_feature("ios"):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_fac.lock_landscape()
	if persist and App.has_method("save_now"):
		App.save_now()
