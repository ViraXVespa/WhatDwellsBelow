extends Object

## 3D world: 1 tile = 1 world unit, 64px = 1u, Y-up, XZ ground.
const TILE := 1.0
const PX := 64.0
const WALL_H := 1.45
const CAM_PITCH := -58.0
const CAM_HEIGHT := 14.0
const INTERACT_R := 72.0 / 64.0
const PLAYER_R := 12.0 / 64.0


static func _game() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/Game")


static func painted() -> bool:
	var g := _game()
	return g != null and bool(g.call("using_experiment_art"))


static func a(kind: String, file: String) -> String:
	if painted():
		return "res://assets/3d/%s/%s" % [kind, file]
	if kind == "tiles":
		return "res://assets/tiles/%s" % file
	return "res://assets/sprites/%s/%s" % [kind, file]


static func filter() -> BaseMaterial3D.TextureFilter:
	if painted():
		return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return BaseMaterial3D.TEXTURE_FILTER_NEAREST

static var _mats: Dictionary = {}
static var _box_mesh: BoxMesh
static var _plane_mesh: PlaneMesh


static func u(px: float) -> float:
	return px / PX


static func xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


static func from_xz(v: Vector2, y := 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)


static func to_px(p: Vector3) -> Vector2:
	return Vector2(p.x * PX, p.z * PX)


static func tile_center(tx: int, ty: int, y := 0.0) -> Vector3:
	return Vector3((float(tx) + 0.5) * TILE, y, (float(ty) + 0.5) * TILE)


static func los(grid: PackedByteArray, from3: Vector3, to3: Vector3) -> bool:
	return DungeonGen.world_has_los(grid, to_px(from3), to_px(to3))


static func cam_back() -> float:
	return CAM_HEIGHT / tan(deg_to_rad(absf(CAM_PITCH)))


static func ortho_size() -> float:
	var z := 1.0
	if Engine.get_main_loop():
		var g: Node = Engine.get_main_loop().root.get_node_or_null("/root/Game")
		if g and g.get("save") and g.save:
			z = float(g.save.cam_zoom)
	return 1080.0 / PX / maxf(0.5, z)


static func apply_cam(cam: Camera3D) -> void:
	cam.add_to_group("wdb_cam")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_size()
	cam.near = 0.05
	cam.far = 140.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.current = true


static func follow_cam(cam: Camera3D, target: Vector3) -> void:
	if cam == null:
		return
	cam.global_position = target + Vector3(0.0, CAM_HEIGHT, cam_back())
	var look := target + Vector3(0.0, 0.42, 0.0)
	if cam.global_position.distance_squared_to(look) > 0.0001:
		cam.look_at(look, Vector3.UP)


static func mouse_xz(cam: Camera3D, origin: Vector3) -> Vector2:
	if cam == null:
		return Vector2.DOWN
	var mouse: Vector2 = cam.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector2.DOWN
	var t: float = -from.y / dir.y
	if t < 0.0:
		return Vector2.DOWN
	var hit := from + dir * t
	var d := Vector2(hit.x - origin.x, hit.z - origin.z)
	if d.length_squared() < 0.0004:
		return Vector2.DOWN
	return d.normalized()


static func mat(path: String, unshaded := true) -> StandardMaterial3D:
	var key := "%s|%s" % [path, str(unshaded)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.texture_filter = filter()
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path) as Texture2D
	m.uv1_scale = Vector3(1, 1, 1)
	_mats[key] = m
	return m


static func mat_color(col: Color, unshaded := true) -> StandardMaterial3D:
	var key := "col:%s|%s" % [str(col), str(unshaded)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.texture_filter = filter()
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mats[key] = m
	return m


static func plane() -> PlaneMesh:
	if _plane_mesh == null:
		_plane_mesh = PlaneMesh.new()
		_plane_mesh.size = Vector2(TILE, TILE)
	return _plane_mesh


static func box() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3(TILE, WALL_H, TILE)
	return _box_mesh


static func add_world(host: Node3D, dungeon: bool) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	var paint := painted()
	if paint:
		e.background_color = Color(0.03, 0.04, 0.055) if dungeon else Color(0.07, 0.11, 0.12)
		e.ambient_light_color = Color(0.72, 0.62, 0.48) if dungeon else Color(0.95, 0.78, 0.55)
	else:
		e.background_color = Color(0.03, 0.035, 0.05) if dungeon else Color(0.22, 0.38, 0.48)
		e.ambient_light_color = Color(0.78, 0.74, 0.68) if dungeon else Color(0.92, 0.9, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	if paint:
		sun.light_energy = 0.75 if dungeon else 1.05
		sun.light_color = Color(1.0, 0.72, 0.42) if not dungeon else Color(0.75, 0.88, 0.95)
	else:
		sun.light_energy = 0.7 if dungeon else 0.95
		sun.light_color = Color(1.0, 0.94, 0.82) if not dungeon else Color(0.85, 0.88, 0.95)
	sun.shadow_enabled = false
	host.add_child(sun)


static func plant(s: Node3D, xz: Vector2) -> void:
	var keep_y := s.position.y
	s.position = Vector3(xz.x, keep_y, xz.y)


static func sprite(tex: Texture2D, world_h: float, y_billboard: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.centered = true
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.alpha_scissor_threshold = 0.35
	s.texture_filter = filter()
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if y_billboard else BaseMaterial3D.BILLBOARD_DISABLED
	s.render_priority = 1
	if tex:
		s.texture = tex
		var th := float(maxi(1, tex.get_height()))
		s.pixel_size = world_h / th
		s.position.y = world_h * 0.5
	else:
		s.pixel_size = world_h / 64.0
		s.position.y = world_h * 0.5
	return s


static func apply_sprite_tex(s: Sprite3D, tex: Texture2D, world_h: float) -> void:
	if s == null or tex == null:
		return
	s.texture = tex
	var th := float(maxi(1, tex.get_height()))
	s.pixel_size = world_h / th
	s.position.y = world_h * 0.5


static func tex_height(path: String, scale := 1.0) -> float:
	var tex := Art.load_tex(path)
	if tex == null:
		return 1.0 * scale
	return float(tex.get_height()) / PX * scale


static func add_box(host: CollisionObject3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	host.add_child(cs)
	return cs


static func add_cyl(host: CollisionObject3D, radius: float, height: float, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = offset
	host.add_child(cs)
	return cs


static func wall_body(host: Node3D, name := "Walls") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	host.add_child(body)
	return body


static func block_px(body: StaticBody3D, foot_xz: Vector2, size_px: Vector2, local_px: Vector2 = Vector2.ZERO, h := 1.2) -> void:
	var center := foot_xz + Vector2(local_px.x, local_px.y) / PX
	var sz := size_px / PX
	add_box(body, Vector3(sz.x, h, sz.y), Vector3(center.x, h * 0.5, center.y))


static func tile_mm(tex_path: String, positions: Array, y: float, unshaded := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane()
	mm.instance_count = positions.size()
	for i in positions.size():
		var p: Vector3 = positions[i]
		var xf := Transform3D.IDENTITY
		xf.origin = Vector3(p.x, y, p.z)
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat_ref := mat(tex_path, unshaded)
	inst.material_override = mat_ref
	return inst


static func wall_mm(tex_path: String, positions: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box()
	mm.instance_count = positions.size()
	for i in positions.size():
		var p: Vector3 = positions[i]
		var xf := Transform3D.IDENTITY
		xf.origin = Vector3(p.x, WALL_H * 0.5, p.z)
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat(tex_path, false)
	return inst


static func spawn_float(parent: Node, pos: Vector3, amount: float) -> void:
	if parent == null:
		return
	var n := Label3D.new()
	n.text = str(int(round(amount)))
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.font_size = 42
	n.outline_size = 10
	n.outline_modulate = Color(0.05, 0.04, 0.06)
	n.modulate = Color(0.98, 0.88, 0.78)
	n.pixel_size = 0.012
	n.position = pos + Vector3(0.0, 1.15, 0.0)
	n.no_depth_test = true
	parent.add_child(n)
	n.set_script(load("res://scripts/view3d/float_3d.gd"))
