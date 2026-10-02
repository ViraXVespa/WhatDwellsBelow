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
	for a: String in args():
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


static func poses() -> PackedStringArray:
	var raw: String = _arg_val("--wdb-shot-poses")
	if raw.is_empty():
		return PackedStringArray()
	return raw.split(";")

static func zoom() -> float:
	var raw: String = _arg_val("--wdb-shot-zoom")
	if raw.is_empty():
		return 1.0
	return maxf(0.01, raw.to_float())


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
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var ww: int = win_w()
	var hh: int = win_h()
	if ww > 0 and hh > 0:
		DisplayServer.window_set_size(Vector2i(ww, hh))
	var sz: Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(-32000, -32000))
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
	_apply_pose(host)
	var list: PackedStringArray = poses()
	if list.is_empty():
		RenderingServer.frame_post_draw.connect(func() -> void: _capture(host), CONNECT_ONE_SHOT)
		return
	_pose_i = 0
	_strips.clear()
	_kick_pose(host)
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
	var z: float = zoom()
	App.cam_zoom = z
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	if rig == null and player != null:
		rig = player.get_node_or_null("CameraRig")
	if rig != null and rig.has_method("apply_size"):
		var T = load("res://scripts/data/tunables.gd")
		rig.warm_hold = true
		rig.call("apply_size", 1080.0 / float(T.PX) / maxf(0.01, z))
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam != null:
		cam.size = 1080.0 / 64.0 / maxf(0.01, z)
		cam.far = maxf(cam.far, cam.size * 3.0)
		printerr("SHOT: mark=camsize size=%s zoom=%s" % [str(cam.size), str(z)])
	if cam != null and false:
		if z != 1.0:
			cam.fov = clampf(cam.fov / z, 1.0, 170.0)
			if rig == null or not rig.has_method("apply_size"):
				cam.size = maxf(0.05, cam.size / z)
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
	var cam_now: Camera3D = host.get_viewport().get_camera_3d()
	var at: String = str(cam_now.global_position) if cam_now != null else "none"
	printerr("SHOT: grab at=%s" % at)
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

static var _pose_i: int = 0
static var _strips: Array[Image] = []
static var _warm_left: int = 0
static var _atlas_left: int = 0

static var _token: String = ""

static func _kick_pose(host: Node) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	var list: PackedStringArray = poses()
	if _pose_i >= list.size():
		_write_strip()
		_quit(host, 0)
		return
	var token: String = list[_pose_i]
	_token = token
	_warm_left = 3
	_atlas_left = 40
	_apply_pose_token(host, token)
	host.get_tree().process_frame.connect(_on_warm.bind(host, token), CONNECT_ONE_SHOT)
static func _hub_atlas_bound() -> bool:
	var abs_path: String = ProjectSettings.globalize_path("res://assets/baked/hub_light.png")
	if not FileAccess.file_exists(abs_path):
		return false
	var img := Image.new()
	if img.load(abs_path) != OK:
		return false
	if img.get_width() < 1088 or img.get_height() < 1024:
		return false
	var rt = load("res://scripts/graphics/light_rt.gd")
	if rt == null or not rt.has_method("texture"):
		return false
	var tex: Texture2D = rt.texture()
	return tex != null and tex.get_width() >= 1088
static func _on_warm(host: Node, token: String) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	_apply_pose_token(host, token)
	_warm_left -= 1
	if _warm_left > 0:
		host.get_tree().process_frame.connect(_on_warm.bind(host, token), CONNECT_ONE_SHOT)
		return
	if _pose_i == 0 and _atlas_left > 0 and not _hub_atlas_bound():
		_atlas_left -= 1
		host.get_tree().process_frame.connect(_on_warm.bind(host, token), CONNECT_ONE_SHOT)
		return
	if _pose_i == 0:
		printerr("SHOT: atlas bound=%s left=%d" % [str(_hub_atlas_bound()), _atlas_left])
	RenderingServer.frame_post_draw.connect(_on_post_draw.bind(host, token), CONNECT_ONE_SHOT)
static func _on_post_draw(host: Node, token: String) -> void:
	RenderingServer.force_sync()
	_grab_pose(host, token)


static func _grab_pose(host: Node, token: String) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	var img: Image = _read_frame(host)
	if img == null:
		_fail(host, "no_image")
		return
	var copy: Image = img.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	_strips.append(copy)
	var cam_now: Camera3D = host.get_viewport().get_camera_3d()
	var at: String = str(cam_now.global_position) if cam_now != null else "none"
	printerr("SHOT: grab token=%s frame=%d at=%s w=%d h=%d" % [token, _pose_i, at, copy.get_width(), copy.get_height()])
	_pose_i += 1
	_kick_pose(host)


static func _read_frame(host: Node) -> Image:
	var vp: Viewport = host.get_viewport()
	if vp == null:
		return null
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	var pct: int = scale_pct()
	if pct < 100:
		var w: int = maxi(1, int(float(img.get_width()) * (float(pct) / 100.0)))
		var h: int = maxi(1, int(float(img.get_height()) * (float(pct) / 100.0)))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img

static func _apply_pose_token(host: Node, token: String) -> void:
	var bits: PackedStringArray = token.split(",")
	var kind: String = bits[0] if bits.size() > 0 else "play"
	var cx: float = float(bits[1]) if bits.size() > 1 else 16.5
	var cz: float = float(bits[2]) if bits.size() > 2 else 15.0
	var ox: float = float(bits[3]) if bits.size() > 3 else 0.0
	var oz: float = float(bits[4]) if bits.size() > 4 else 0.0
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	if rig != null:
		rig.set("warm_hold", true)
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		rig.set_process(false)
		rig.set_physics_process(false)
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam == null:
		printerr("SHOT: token=%s err=no_cam" % token)
		return
	cam.current = true
	cam.top_level = true
	if kind == "play":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1080.0 / 64.0 / 0.69
		cam.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
		var back: float = 14.0 / tan(deg_to_rad(58.0))
		cam.global_position = Vector3(cx, 14.0, cz + back)
		printerr("SHOT: token=%s at=%s" % [token, str(cam.global_position)])
		return
	var look := Vector3(cx, 1.6, cz)
	var at := look + Vector3(ox, 4.2, oz)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 42.0
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	printerr("SHOT: token=%s at=%s look=%s" % [token, str(cam.global_position), str(look)])

static func _grid_shape(n: int) -> Vector2i:
	var rows: int = maxi(1, ceili(sqrt(float(n))))
	var cols: int = maxi(1, ceili(float(n) / float(rows)))
	return Vector2i(cols, rows)


static func _write_strip() -> void:
	if _strips.is_empty():
		return
	var fw: int = 1
	var fh: int = 1
	for frame in _strips:
		fw = maxi(fw, frame.get_width())
		fh = maxi(fh, frame.get_height())
	var shape: Vector2i = _grid_shape(_strips.size())
	var cols: int = shape.x
	var rows: int = shape.y
	var out: Image = Image.create(cols * fw, rows * fh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.15, 0.12, 0.1))
	var i: int = 0
	while i < _strips.size():
		var frame: Image = _strips[i]
		var col: int = i % cols
		var row: int = int(float(i) / float(cols))
		out.blit_rect(frame, Rect2i(0, 0, frame.get_width(), frame.get_height()), Vector2i(col * fw, row * fh))
		i += 1
	printerr("SHOT: grid cols=%d rows=%d" % [cols, rows])
	var err: Error = out.save_png(out_path())
	if err != OK:
		printerr("SHOT: ok=false err=strip_%d" % int(err))
		return
	printerr("SHOT: ok=true path=%s w=%d h=%d frames=%d" % [out_path(), out.get_width(), out.get_height(), _strips.size()])
	printerr("SHOT: strip frames=%d bytes_path=%s" % [_strips.size(), out_path()])
