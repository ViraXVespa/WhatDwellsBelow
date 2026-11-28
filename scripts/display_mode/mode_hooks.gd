extends Object

## Page-level key hooks (Esc, F1, close chords) for the web build. Idempotent.

const Env := preload("res://scripts/display_mode/mode_env.gd")

static func ensure_web_hooks() -> void:
	if not Env.is_web():
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
				window.__wdbEsc = 2;
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
