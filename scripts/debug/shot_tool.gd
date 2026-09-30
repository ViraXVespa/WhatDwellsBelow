extends RefCounted

## Standalone postcard worker. Not a numbered P1–P9 smoke.
## CLI: --wdb-shot
## Optional: --wdb-shot-seed=N --wdb-shot-floor=N --wdb-shot-out=PATH
##		   --wdb-shot-scale=PCT --wdb-shot-settle-ms=N

const FLAG := "--wdb-shot"

static var _cached: int = -1


static func args() -> PackedStringArray:
	var user: PackedStringArray = OS.get_cmdline_user_args()
	if user.size() > 0:
		return user
	return OS.get_cmdline_args()


static func _flag_on() -> bool:
	return FLAG in args()


static func active() -> bool:
	if _cached < 0:
		_cached = 1 if _flag_on() else 0
	return _cached == 1


static func _arg_int(key: String, fallback: int) -> int:
	var prefix: String = key + "="
	for a: String in args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return int(s.substr(prefix.length()))
	return fallback



static func _arg_val(flag: String) -> String:
	var prefix: String = flag + "="
	for a: String in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return ""

static func _arg_str(key: String, fallback: String) -> String:
	var prefix: String = key + "="
	for a: String in args():
		var s: String = str(a)
		if s.begins_with(prefix):
			return s.substr(prefix.length())
	return fallback


static func scene_name() -> String:
	var s: String = _arg_str("--wdb-shot-scene", "dungeon")
	if s == "camp" or s == "hub":
		return "camp"
	return "dungeon"


static func run_seed() -> int:
	var n: int = _arg_int("--wdb-shot-seed", 42)
	if n == 0:
		return 1
	return n


static func floor_n() -> int:
	return maxi(1, _arg_int("--wdb-shot-floor", 1))


static func out_path() -> String:
	var p: String = _arg_str("--wdb-shot-out", "")
	if p != "":
		return p
	return ProjectSettings.globalize_path("user://wdb_shot.png")


static func scale_pct() -> int:
	return clampi(_arg_int("--wdb-shot-scale", 100), 1, 100)


static func settle_sec() -> float:
	var ms: int = maxi(0, _arg_int("--wdb-shot-settle-ms", 1000))
	return float(ms) / 1000.0


static func show_window() -> bool:
	return _arg_int("--wdb-shot-show", 0) != 0


static func hud_on() -> bool:
	return _arg_int("--wdb-shot-hud", 1) != 0


static func taskbar_on() -> bool:
	return _arg_int("--wdb-shot-taskbar", 0) != 0


static func win_w() -> int:
	return _arg_int("--wdb-shot-width", 0)


static func win_h() -> int:
	return _arg_int("--wdb-shot-height", 0)


static func zoom() -> float:
	var raw: String = _arg_val("--wdb-shot-zoom")
	if raw.is_empty():
		return 1.0
	return maxf(0.1, raw.to_float())


static func has_player_pos() -> bool:
	return not _arg_val("--wdb-shot-px").is_empty() or not _arg_val("--wdb-shot-pz").is_empty()


static func player_x() -> float:
	return _arg_val("--wdb-shot-px").to_float()


static func player_z() -> float:
	return _arg_val("--wdb-shot-pz").to_float()


static func cam_x() -> float:
	return _arg_val("--wdb-shot-cx").to_float()


static func cam_z() -> float:
	return _arg_val("--wdb-shot-cz").to_float()


static func hide_window() -> void:
	if show_window():
		printerr("SHOT: mark=window shown=1")
		return
	var win: Window = Engine.get_main_loop().root as Window
	if win != null:
		win.unfocusable = true
		win.borderless = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var ww: int = win_w()
	var hh: int = win_h()
	if ww > 0 and hh > 0:
		DisplayServer.window_set_size(Vector2i(ww, hh))
	var sz: Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(sz.x + 64, sz.y + 64))
	printerr("SHOT: mark=window shown=0 taskbar=%d" % [1 if taskbar_on() else 0])


static func attach_dungeon(host: Node) -> void:
	if not active():
		return
	hide_window()
	printerr("SHOT: mark=attach seed=%d floor=%d scale=%d out=%s" % [run_seed(), floor_n(), scale_pct(), out_path()])
	_apply_pose(host)
	var tree: SceneTree = host.get_tree()
	var sec: float = settle_sec()
	if sec <= 0.0:
		tree.process_frame.connect(func() -> void: _arm_capture(host), CONNECT_ONE_SHOT)
		return
	tree.create_timer(sec).timeout.connect(func() -> void: _arm_capture(host))


static func _arm_capture(host: Node) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	RenderingServer.frame_post_draw.connect(func() -> void: _capture(host), CONNECT_ONE_SHOT)


static func _apply_pose(host: Node) -> void:
	var player: Node3D = host.get("player") as Node3D
	if player != null and has_player_pos():
		var p: Vector3 = player.global_position
		player.global_position = Vector3(player_x(), p.y, player_z())
	var hud_n: Node = host.get("hud") as Node
	if hud_n != null:
		hud_n.visible = hud_on()
	var hint_n: Node = host.get("hint") as Node
	if hint_n != null:
		hint_n.visible = hud_on()
	var prompt_n: Node = host.get("prompt") as Node
	if prompt_n != null:
		prompt_n.visible = hud_on()
	var map_n: Node = host.get("map_layer") as Node
	if map_n != null:
		map_n.visible = hud_on()
	if not hud_on():
		_hide_label3d(host)
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam != null:
		var z: float = zoom()
		if z != 1.0:
			cam.fov = clampf(cam.fov / z, 10.0, 120.0)
		if player != null:
			var look: Vector3 = player.global_position + Vector3(cam_x(), 0.0, cam_z())
			cam.look_at(look, Vector3.UP)
	DisplayServer.register_additional_output(host)
	printerr("SHOT: mark=pose hud=%d zoom=%s px=%s pz=%s" % [1 if hud_on() else 0, str(zoom()), _arg_val("--wdb-shot-px"), _arg_val("--wdb-shot-pz")])


static func _capture(host: Node) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	var vp: Viewport = host.get_viewport()
	if vp == null:
		_fail(host, "no_viewport")
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		_fail(host, "no_texture")
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		_fail(host, "no_image")
		return
	var pct: int = scale_pct()
	if pct < 100:
		var w: int = maxi(1, int(float(img.get_width()) * (float(pct) / 100.0)))
		var h: int = maxi(1, int(float(img.get_height()) * (float(pct) / 100.0)))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var path: String = out_path()
	var err: Error = img.save_png(path)
	if err != OK:
		_fail(host, "save_%d" % int(err))
		return
	var nbytes: int = 0
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			nbytes = int(f.get_length())
	printerr("SHOT: ok=true path=%s w=%d h=%d bytes=%d" % [path, img.get_width(), img.get_height(), nbytes])
	_quit(host, 0)


static func _fail(host: Node, why: String) -> void:
	printerr("SHOT: ok=false err=%s" % why)
	_quit(host, 1)


static func _quit(host: Node, code: int) -> void:
	if not is_instance_valid(host):
		return
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	tree.create_timer(0.2).timeout.connect(func() -> void: tree.quit(code))


static func _hide_label3d(n: Node) -> void:
	if n is Label3D:
		(n as Label3D).visible = false
	var i: int = 0
	while i < n.get_child_count():
		_hide_label3d(n.get_child(i))
		i += 1
