extends RefCounted

## Shot flow op "sweep": photograph the whole dungeon floor as overlapping tiles. The play camera is orthographic and
## never yaws, so a tile is the same picture shifted: tools/run_shots.py --full-map stitches them from sweep.json.
## Per tile: teleport the (hidden, frozen) player so geometry and the light window are built around it, move the rig
## there, grab the frame. Enemies are hidden and frozen, the HUD and map stay off. Only the centre of each tile is kept
## (keep_x / keep_y cells around the player, multiples of 8 px): lights are chosen by distance to the player, so the
## picture edge is not lit as in play. Step keys: margin (cells), frames (settle frames per tile), keep_x, keep_y.

const Args := preload("res://scripts/debug/shot_tool/tool_args.gd")
const Capture := preload("res://scripts/debug/shot_tool/capture.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")

static func _bounds(host: Node, margin: int) -> Rect2i:
	var w: int = host.data.w
	var h: int = host.data.h
	var grid: PackedByteArray = host.data.grid
	var x0: int = w
	var y0: int = h
	var x1: int = -1
	var y1: int = -1
	for y in h:
		for x in w:
			if grid[Gen.idx(x, y, w)] == Gen.FLOOR:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	x0 = maxi(0, x0 - margin)
	y0 = maxi(0, y0 - margin)
	x1 = mini(w, x1 + 1 + margin)
	y1 = mini(h, y1 + 1 + margin)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

static func _hide_actors(host: Node) -> void:
	var player: Node3D = host.get("player") as Node3D
	if player != null:
		player.visible = false
	for n: Node in host.get_tree().get_nodes_in_group("enemies"):
		if n is Node3D:
			(n as Node3D).visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED

static func _frames(host: Node, n: int, stream: GDScript) -> void:
	var i: int = 0
	while i < n:
		stream.call("tick", host, 1.0)
		await host.get_tree().process_frame
		i += 1

static func run(st: Dictionary, step: Dictionary) -> void:
	var host: Node = st.host
	var player: Node3D = host.get("player") as Node3D
	var rig: Node = host.get_tree().get_first_node_in_group("camera_rig")
	var cam: Camera3D = host.get_viewport().get_camera_3d()
	if rig == null and cam != null and cam.get_parent().has_method("follow"):
		rig = cam.get_parent()
	if player == null or rig == null or cam == null or host.get("data") == null:
		printerr("SHOT: fail op=sweep why=needs a dungeon floor with player and camera")
		st.fail = "sweep: needs a dungeon floor with player and camera"
		return
	var stream: GDScript = load("res://scripts/world/dungeon_stream.gd") as GDScript
	var margin: int = int(step.get("margin", 3))
	var frames: int = int(step.get("frames", 8))
	var area: Rect2i = _bounds(host, margin)
	host.stream_all = true
	stream.call("force_all", host)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var size: Vector2 = host.get_viewport().get_visible_rect().size
	var ppu: float = size.y / cam.size
	var up: Vector3 = cam.global_transform.basis.y
	var sinp: float = absf(up.z)
	var base: Vector3 = player.global_position
	rig.call("follow", base)
	await _frames(host, 4, stream)
	var c0: float = cam.unproject_position(Vector3(base.x, 0.0, base.z)).y - size.y * 0.5
	var mx: int = maxi(0, int(round((size.x * 0.5 - float(step.get("keep_x", 12)) * ppu) / 8.0)) * 8)
	var my: int = maxi(0, int(round((size.y * 0.5 - float(step.get("keep_y", 8)) * sinp * ppu) / 8.0)) * 8)
	var sx: int = int(size.x) - 2 * mx
	var sy: int = int(size.y) - 2 * my
	var cw: int = int(ceil(float(area.size.x) * ppu))
	var ch: int = int(ceil(float(area.size.y) * sinp * ppu))
	var cols: int = maxi(1, int(ceil(float(cw - 2 * mx) / float(sx))))
	var rows: int = maxi(1, int(ceil(float(ch - 2 * my) / float(sy))))
	var dir: String = Args.frames_dir().path_join("tiles")
	DirAccess.make_dir_recursive_absolute(dir)
	var tiles: Array = []
	for r in rows:
		for c in cols:
			var px: float = float(area.position.x) + (float(c * sx + mx) + (size.x - 2.0 * mx) * 0.5) / ppu
			var pz: float = float(area.position.y) + (float(r * sy + my) + (size.y - 2.0 * my) * 0.5 + c0) / (sinp * ppu)
			var at := Vector3(px, base.y, pz)
			player.global_position = at
			rig.call("follow", at)
			await _frames(host, frames if tiles.size() > 0 else frames * 4, stream)
			_hide_actors(host)
			rig.call("follow", at)
			await host.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = Capture._read_frame(host)
			if img == null:
				st.fail = "sweep: no_image"
				return
			img.convert(Image.FORMAT_RGB8)
			var name: String = "t%02d-%02d.png" % [r, c]
			img.save_png(dir.path_join(name))
			var u: Vector2 = cam.unproject_position(Vector3(at.x, 0.0, at.z))
			tiles.append({"file": name, "r": r, "c": c, "px": px, "pz": pz, "ux": u.x, "uy": u.y})
	var meta: Dictionary = {"x0": area.position.x, "z0": area.position.y, "w": area.size.x, "h": area.size.y, "ppu": ppu,
		"sinp": sinp, "tile_w": int(size.x), "tile_h": int(size.y), "crop_x": mx, "crop_y": my, "cols": cols, "rows": rows, "tiles": tiles}
	var f: FileAccess = FileAccess.open(Args.frames_dir().path_join("sweep.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "  "))
	printerr("SHOT: sweep tiles=%d cols=%d rows=%d canvas=%dx%d" % [tiles.size(), cols, rows, cw, ch])
