extends RefCounted

## Postcard shot camera pose: apply a pose and its token.

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")

static func _apply_pose(host: Node) -> void:
	var player: Node3D = host.get("player") as Node3D
	if player != null and Args.has_player_pos():
		var p: Vector3 = player.global_position
		player.global_position = Vector3(Args.player_x(), p.y, Args.player_z())
	elif player != null and str(host.scene_file_path).contains("camp"):
		var p2: Vector3 = player.global_position
		player.global_position = Vector3(15.2, p2.y, 7.6)
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
		map_n.visible = false  # the full-screen map is toggled by the player, never part of the HUD (HUD on used to open it over the scene)
	var z: float = Args.zoom()
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
			var look: Vector3 = player.global_position + Vector3(Args.cam_x(), 0.0, Args.cam_z())
			cam.look_at(look, Vector3.UP)
	DisplayServer.register_additional_output(host)
	printerr("SHOT: mark=pose hud=%d zoom=%s px=%s pz=%s" % [1 if Args.hud_on() else 0, str(Args.zoom()), Args._arg_val("--wdb-shot-px"), Args._arg_val("--wdb-shot-pz")])

static func _apply_pose_token(host: Node, token: String) -> void:
	var bits: PackedStringArray = token.split(",")
	var kind: String = bits[0] if bits.size() > 0 else "play"
	var cx: float = float(bits[1]) if bits.size() > 1 else 16.5
	var cz: float = float(bits[2]) if bits.size() > 2 else 15.0
	var ox: float = float(bits[3]) if bits.size() > 3 else 0.0
	var oz: float = float(bits[4]) if bits.size() > 4 else 0.0
	var zoom: float = float(bits[5]) if bits.size() > 5 else 1.0
	var px: float = float(bits[6]) if bits.size() > 6 else cx
	var pz: float = float(bits[7]) if bits.size() > 7 else cz
	var face: String = bits[8] if bits.size() > 8 else "down"
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if cam == null:
		printerr("SHOT: token=%s err=no_cam" % token)
		return
	var rt = load("res://scripts/graphics/light_rt.gd")
	if rt != null and rt.get("hub_crystal") == Vector2.ZERO:
		rt.set("hub_crystal", Vector2(16.475, 10.2))
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
	var persp := look + Vector3(ox, 4.2, oz)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 42.0
	cam.global_position = persp
	cam.look_at(look, Vector3.UP)
	printerr("SHOT: token=%s at=%s look=%s" % [token, str(cam.global_position), str(look)])
