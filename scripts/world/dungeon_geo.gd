extends Object

const T := preload("res://scripts/data/tunables.gd")
const Gen := preload("res://scripts/dungeon/gen.gd")
const Rooms := preload("res://scripts/dungeon/gen_rooms.gd")
const Threat := preload("res://scripts/combat/threat.gd")


static func world(host: Node) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.68, 0.74)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_energy = 0.65
	sun.light_color = Color(0.82, 0.88, 0.95)
	sun.shadow_enabled = false
	host.add_child(sun)


static func collision_walls(host: Node) -> void:
	host.walls = StaticBody3D.new()
	host.walls.collision_layer = 1
	host.walls.collision_mask = 0
	host.add_child(host.walls)


static func box(body: StaticBody3D, size: Vector3, offset: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	body.add_child(cs)


static func build_visuals(host: Node) -> void:
	host.floor_mat = make_mat("res://assets/tiles/foundation_floor.png", Color(0.18, 0.2, 0.24), true)
	host.wall_mat = make_mat("res://assets/tiles/foundation_wall.png", Color(0.22, 0.22, 0.26), false)
	var StreamGeo = load("res://scripts/world/dungeon_geo_stream.gd")
	StreamGeo.setup(host)


static func make_mat(tex_path: String, fallback: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.albedo_color = Color(0.75, 0.82, 0.9) if unshaded else fallback
	else:
		mat.albedo_color = fallback
	return mat


static func mm_planes(positions: Array, tex_path: String, fallback: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var xf := Transform3D.IDENTITY
		xf.origin = positions[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = make_mat(tex_path, fallback, true)
	return inst


static func mm_boxes(positions: Array, tex_path: String, fallback: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(T.TILE, T.WALL_H, T.TILE)
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var xf := Transform3D.IDENTITY
		xf.origin = positions[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = make_mat(tex_path, fallback, false)
	return inst


static func build_travel(host: Node) -> void:
	var sp: Vector2i = host.data.get("spawn", Vector2i.ZERO)
	host.travel_dist = Rooms.bfs(host.data.grid, int(host.data.w), int(host.data.h), sp)
	var vals: Array[int] = []
	for i in host.travel_dist.size():
		if host.travel_dist[i] >= 0:
			vals.append(host.travel_dist[i])
	if vals.is_empty():
		host.travel_cap = 1
		return
	vals.sort()
	var pct := clampf(float(App.bal.enemy_cl_end_pct), 0.72, 0.96)
	var idx := clampi(int(round(float(vals.size() - 1) * pct)), 0, vals.size() - 1)
	host.travel_cap = maxi(1, vals[idx])


static func enemy_combat_lv(host: Node, pos: Vector3) -> int:
	return Threat.level_at(App.floor_n, host._world_cell(pos), host.travel_dist, int(host.data.w), host.travel_cap)


static func cell_color(host: Node, x: int, y: int) -> Color:
	var w: int = host.data.w
	if host.visited[Gen.idx(x, y, w)] == 0:
		return Color(0.02, 0.02, 0.03, 1)
	if host.data.grid[Gen.idx(x, y, w)] == Gen.FLOOR:
		return Color(0.22, 0.24, 0.28)
	return Color(0.08, 0.08, 0.1)


static func paint_cell(host: Node, x: int, y: int) -> void:
	if host.map_img == null:
		return
	if x < 0 or y < 0 or x >= host.data.w or y >= host.data.h:
		return
	host.map_img.set_pixel(x, y, cell_color(host, x, y))


static func reveal_around(host: Node, c: Vector2i, rad: int) -> bool:
	var w: int = host.data.w
	var h: int = host.data.h
	var r2 := rad * rad
	var grew := false
	for y in range(maxi(0, c.y - rad), mini(h, c.y + rad + 1)):
		for x in range(maxi(0, c.x - rad), mini(w, c.x + rad + 1)):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= r2:
				var i := Gen.idx(x, y, w)
				if host.visited[i] == 0:
					host.visited[i] = 1
					grew = true
					paint_cell(host, x, y)
	return grew


static func make_map(host: Node) -> void:
	host.map_layer = CanvasLayer.new()
	host.map_layer.layer = 30
	host.map_layer.visible = false
	host.add_child(host.map_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	host.map_layer.add_child(dim)
	host.map_img = Image.create(int(host.data.w), int(host.data.h), false, Image.FORMAT_RGBA8)
	host.map_img.fill(Color(0.02, 0.02, 0.03, 1))
	host.map_tex = ImageTexture.create_from_image(host.map_img)
	host.map_rect = TextureRect.new()
	host.map_rect.texture = host.map_tex
	host.map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.map_rect.position = Vector2(560, 140)
	host.map_rect.size = Vector2(800, 800)
	host.map_layer.add_child(host.map_rect)
	host.set_meta("map_pc", Vector2i(-999, -999))
	redraw_map(host)


static func redraw_map(host: Node) -> void:
	if host.map_img == null:
		return
	var old: Vector2i = host.get_meta("map_pc", Vector2i(-999, -999))
	if old.x >= 0:
		paint_cell(host, old.x, old.y)
	dot(host, host.data.crystal, Color(0.3, 0.9, 1.0), true)
	dot(host, host.data.stairs, Color(0.95, 0.75, 0.25), true)
	var marked := false
	for o in host.data.get("openings", []):
		for raw in o.get("cells", []):
			dot(host, Vector2i(raw), Color(0.9, 0.2, 0.15), true)
			marked = true
	if not marked:
		dot(host, host.data.door, Color(0.9, 0.2, 0.15), true)
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			var k := str(n.get("kind"))
			var cell := Vector2i(int((n as Node3D).global_position.x), int((n as Node3D).global_position.z))
			if k.begins_with("clerk"):
				dot(host, cell, Color(0.95, 0.82, 0.35), true)
			elif k == "shop":
				dot(host, cell, Color(0.55, 0.85, 1.0), true)
	if host.player:
		var pc := Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))
		host.set_meta("map_pc", pc)
		dot(host, pc, Color(1, 1, 1), false)
	host.map_tex.update(host.map_img)


static func dot(host: Node, p: Vector2i, col: Color, need_seen := false) -> void:
	if p.x < 0 or p.y < 0 or p.x >= host.data.w or p.y >= host.data.h:
		return
	if need_seen and host.visited[Gen.idx(p.x, p.y, host.data.w)] == 0:
		return
	host.map_img.set_pixel(p.x, p.y, col)
