extends RefCounted

## Postcard shot camera pose: apply a pose and its token.

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")

static func _apply_pose(host: Node) -> void:
	# Shot window: borderless + exact 1920x1080 so client area is not reduced by title bar.
	if not Args.show_window():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		var sz: Vector2i = Args.win_size()
		if sz.x <= 0 or sz.y <= 0:
			sz = Vector2i(1920, 1080)
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(Vector2i(-32000, -32000))
	var player: Node3D = host.get("player") as Node3D
	if player != null and Args.has_player_pos():
		var p: Vector3 = player.global_position
		player.global_position = Vector3(Args.player_x(), p.y, Args.player_z())
	elif player != null and str(host.scene_file_path).contains("camp"):
		var p2: Vector3 = player.global_position
		player.global_position = Vector3(15.2, p2.y, 7.6)  # shot default stand, not a layout point
	var hud_n: Node = host.get("hud") as Node
	if hud_n != null:
		hud_n.visible = Args.hud_on()
	var hint_n: Node = host.get("hint") as Node
	if hint_n != null:
		hint_n.visible = Args.hud_on()
	var prompt_n: Node = host.get("prompt") as Node
	if prompt_n != null:
		prompt_n.visible = Args.hud_on()
	var map_n: Node = host.get("map_layer") as Node
	if map_n != null:
		map_n.visible = false
	var z: float = Args.zoom()
	App.cam_zoom = z
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	if rig == null and player != null:
		rig = player.get_node_or_null("CameraRig")
	var T = load("res://scripts/data/tunables.gd")
	if rig != null and rig.has_method("apply_size"):
		rig.warm_hold = true
		# Pin it: camp warm-up ends in restore_user, whose apply_zoom clamps to ZOOM_MIN (1.0) and undid zoom < 1.
		rig.set("size_pin", T.base_size().y / float(T.PX) / maxf(0.01, z))
		rig.call("apply_size", T.base_size().y / float(T.PX) / maxf(0.01, z))
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam != null:
		cam.size = T.base_size().y / float(T.PX) / maxf(0.01, z)
		cam.far = maxf(cam.far, cam.size * 3.0)
		printerr("SHOT: mark=camsize size=%s zoom=%s" % [str(cam.size), str(z)])
	if cam != null and false:
		if z != 1.0:
			cam.fov = clampf(cam.fov / z, 1.0, 170.0)
			if rig == null or not rig.has_method("apply_size"):
				cam.size = maxf(0.05, cam.size / z)
		if player != null:
			var look: Vector3 = player.global_position + Vector3(Args.cam_x(), 0.0, Args.cam_z())
			cam.look_at(look, Vector3.UP)
	DisplayServer.register_additional_output(host)
	printerr("SHOT: mark=pose hud=%d zoom=%s px=%s pz=%s" % [1 if Args.hud_on() else 0, str(Args.zoom()), Args._arg_val("--wdb-shot-px"), Args._arg_val("--wdb-shot-pz")])

static func _apply_pose_token(host: Node, token: String) -> void:
	var bits: PackedStringArray = token.split(",")
	var kind: String = bits[0] if bits.size() > 0 else "play"
	var c: Vector2 = _look(host, bits[1] if bits.size() > 1 else "", bits[2] if bits.size() > 2 else "")
	var cx: float = c.x
	var cz: float = c.y
	var ox: float = float(bits[3]) if bits.size() > 3 else 0.0
	var oz: float = float(bits[4]) if bits.size() > 4 else 0.0
	var zoom: float = float(bits[5]) if bits.size() > 5 else 1.0
	var px: float = float(bits[6]) if bits.size() > 6 and bits[6] != "" else cx + (float(bits[10]) if bits.size() > 10 else 0.0)
	var pz: float = float(bits[7]) if bits.size() > 7 and bits[7] != "" else cz + (float(bits[11]) if bits.size() > 11 else 0.0)
	var face: String = bits[8] if bits.size() > 8 else "down"
	var cy: float = float(bits[9]) if bits.size() > 9 else 4.2
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam == null:
		printerr("SHOT: token=%s err=no_cam" % token)
		return
	var rt = load("res://scripts/graphics/light_rt.gd")
	if rt != null and rt.get("hub_crystal") == Vector2.ZERO:
		var cp: Vector3 = load("res://scripts/world/camp/layout_spec.gd").SPOTS["Crystal"]
		rt.set("hub_crystal", Vector2(cp.x, cp.z))
	var crystal: Vector2 = rt.get("hub_crystal") if rt != null else Vector2.ZERO
	var player: Node = host.get("player")
	if player == null:
		player = host.get_tree().get_first_node_in_group("player")
	if player != null and player is Node3D:
		var body: Node3D = player as Node3D
		body.global_position = Vector3(px, body.global_position.y, pz)
		var aim := Vector2.DOWN
		if face == "up":
			aim = Vector2.UP
		elif face == "left":
			aim = Vector2.LEFT
		elif face == "right":
			aim = Vector2.RIGHT
		player.set("aim_dir", aim)
		player.set("facing_key", face)
	if kind == "play":
		if rig != null:
			cam.global_transform = rig.global_transform
		cam.current = true
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.875 / maxf(zoom, 0.2)
		printerr("SHOT: token=play face=%s crystal=%s rot=%s" % [face, str(crystal), str(cam.global_rotation_degrees)])
		if rig != null:
			rig.set("warm_hold", true)
			rig.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if rig != null:
		rig.set("warm_hold", true)
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	cam.current = true
	cam.top_level = true
	var look := Vector3(cx, 1.6, cz)
	var persp := look + Vector3(ox, cy, oz)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 42.0
	cam.global_position = persp
	cam.look_at(look, Vector3.UP)
	printerr("SHOT: token=%s at=%s look=%s" % [token, str(cam.global_position), str(look)])

## Recipe look point: numbers, a Layout name (Hall, Wing, Stall or a spot), or empty (the path crossing).
static func _look(host: Node, a: String, b: String) -> Vector2:
	if a.is_valid_float():
		return Vector2(a.to_float(), b.to_float())
	var layout_s: GDScript = load("res://scripts/world/camp/layout.gd")
	if a == "":
		return layout_s.path_cross()
	var lay: Node3D = layout_s.of(host)
	var p: Vector3 = lay.call(a.to_lower() + "_pos") if a in ["Hall", "Wing", "Stall"] else lay.spot_pos(a)
	return Vector2(p.x, p.z)
