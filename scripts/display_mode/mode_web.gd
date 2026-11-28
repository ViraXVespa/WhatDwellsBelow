extends Object

## Window and fullscreen changes: desktop modes, the web / mobile fullscreen toggle, Alt+Enter and quit chords.

const Env := preload("res://scripts/display_mode/mode_env.gd")
const Desk := preload("res://scripts/display_mode/mode_desk.gd")

static func set_desktop_mode(mode: String, persist: bool = true) -> void:
	if not Env.uses_desktop_modes():
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

static func set_web_fullscreen(on: bool, persist: bool = true) -> void:
	App.web_fullscreen = on
	if Env.is_web():
		if on:
			Desk._js_request_fs()
		else:
			Desk._js_exit_fs()
	elif OS.has_feature("android") or OS.has_feature("ios"):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Env.lock_landscape()
	if persist and App.has_method("save_now"):
		App.save_now()

static func toggle_alt_enter() -> void:
	if Env.is_xbox():
		return
	if Env.uses_desktop_modes():
		if Env.is_fullscreen_now():
			set_desktop_mode("windowed")
			return
		var kind: String = str(App.display_fs_kind)
		if kind != "exclusive":
			kind = "borderless"
		set_desktop_mode(kind)
		return
	if Env.uses_web_fs_toggle():
		set_web_fullscreen(not Env.is_fullscreen_now())

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

static func handle_input(event: InputEvent) -> bool:
	if Env.is_xbox():
		return false
	if not Env.uses_desktop_modes() and not Env.uses_web_fs_toggle():
		return false
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	if _is_quit_chord(k):
		request_quit()
		return true
	if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.alt_pressed:
		toggle_alt_enter()
		return true
	return false

## Ctrl/Cmd+W, Ctrl/Cmd+Q or Alt+F4.
static func _is_quit_chord(k: InputEventKey) -> bool:
	if (k.keycode == KEY_W or k.keycode == KEY_Q) and (k.ctrl_pressed or k.meta_pressed):
		return true
	return k.keycode == KEY_F4 and k.alt_pressed

static func request_quit() -> void:
	if Env.is_xbox():
		return
	if Env.is_web():
		Desk._js_close()
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit()
