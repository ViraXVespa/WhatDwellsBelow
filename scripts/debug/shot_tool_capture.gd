extends RefCounted

## Postcard shot capture: arm, warm, grab frames, write strips, quit.

const Args := preload("res://scripts/debug/shot_tool_args.gd")
const Pose := preload("res://scripts/debug/shot_tool_pose.gd")

static var _pose_i: int = 0
static var _strips: Array[Image] = []
static var _warm_left: int = 0
static var _atlas_left: int = 0
static var _token: String = ""

static func _arm_capture(host: Node) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	Pose._apply_pose(host)
	var list: PackedStringArray = Args.poses()
	if list.is_empty():
		RenderingServer.frame_post_draw.connect(func() -> void: _capture(host), CONNECT_ONE_SHOT)
		return
	_pose_i = 0
	_strips.clear()
	_kick_pose(host)
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
	var pct: int = Args.scale_pct()
	if pct < 100:
		var w: int = maxi(1, int(float(img.get_width()) * (float(pct) / 100.0)))
		var h: int = maxi(1, int(float(img.get_height()) * (float(pct) / 100.0)))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var path: String = Args.out_path()
	var err: Error = img.save_png(path)
	if err != OK:
		_fail(host, "save_%d" % int(err))
		return
	var nbytes: int = 0
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			nbytes = int(f.get_length())
	printerr("SHOT: atlas bound=%s" % str(_hub_atlas_bound()))
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


static func _kick_pose(host: Node) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	var list: PackedStringArray = Args.poses()
	if _pose_i >= list.size():
		_write_strip()
		_quit(host, 0)
		return
	var token: String = list[_pose_i]
	_token = token
	_warm_left = 3
	_atlas_left = 40
	Pose._apply_pose_token(host, token)
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
	var rt = load("res://scripts/graphics/light_rt/light_rt.gd")
	if rt == null or not rt.has_method("texture"):
		return false
	var tex: Texture2D = rt.texture()
	return tex != null and tex.get_width() >= 1088
static func _on_warm(host: Node, token: String) -> void:
	if not is_instance_valid(host):
		printerr("SHOT: ok=false err=host_gone")
		return
	Pose._apply_pose_token(host, token)
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
	printerr("SHOT: atlas bound=%s" % str(_hub_atlas_bound()))
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
	var pct: int = Args.scale_pct()
	if pct < 100:
		var w: int = maxi(1, int(float(img.get_width()) * (float(pct) / 100.0)))
		var h: int = maxi(1, int(float(img.get_height()) * (float(pct) / 100.0)))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img

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
	var err: Error = out.save_png(Args.out_path())
	if err != OK:
		printerr("SHOT: ok=false err=strip_%d" % int(err))
		return
	printerr("SHOT: ok=true path=%s w=%d h=%d frames=%d" % [Args.out_path(), out.get_width(), out.get_height(), _strips.size()])
	printerr("SHOT: strip frames=%d bytes_path=%s" % [_strips.size(), Args.out_path()])

static func _grid_shape(n: int) -> Vector2i:
	var rows: int = maxi(1, ceili(sqrt(float(n))))
	var cols: int = maxi(1, ceili(float(n) / float(rows)))
	return Vector2i(cols, rows)
