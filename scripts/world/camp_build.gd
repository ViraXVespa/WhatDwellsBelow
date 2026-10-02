extends Object

const T := preload("res://scripts/data/tunables.gd")
const MeshS := preload("res://scripts/world/camp_build_mesh.gd")
const Roof := preload("res://scripts/world/camp_build_roof.gd")
const EnvKit := preload("res://scripts/graphics/env_kit.gd")
const LayoutS := preload("res://scripts/world/camp_layout.gd")

const GROUND_W := 36
const GROUND_D := 32
const GROUND_OX := -2
const GROUND_OZ := -2
const GRASS_PAD := 16
const ROOF_EAVE := 0.42
const TILE_W := 3.2
const HALL_SIZE := Vector3(5.6, 3.4, 4.2)
const WING_SIZE := Vector3(3.8, 2.7, 3.2)
const HALL_POS := Vector3(8.2, 1.7, 6.0)
const PATH_X := 16.5
const PATH_Z := 15.0
const STALL_SIZE := Vector3(4.6, 2.4, 3.4)


static func layout_of(host: Node3D) -> Node3D:
	var n: Node = host.get_node_or_null("Layout")
	if n is Node3D:
		return n as Node3D
	return LayoutS.on_camp(host)


static func generated(host: Node3D) -> Node3D:
	var n: Node = host.get_node_or_null("Generated")
	if n is Node3D:
		return n as Node3D
	var node: Node3D = Node3D.new()
	node.name = "Generated"
	host.add_child(node)
	return node


static func clear_generated(host: Node3D) -> Node3D:
	var node: Node3D = generated(host)
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	return node


static func realize_editor(host: Node3D, layout: Node3D) -> void:
	host.set_meta("wdb_layout", layout)
	var bucket: Node3D = clear_generated(host)
	bucket.set_meta("wdb_layout", layout)
	ground(bucket)
	buildings(bucket)
	strip_building_cubes(host)
	dump_meshes(host)
	var ViewS: GDScript = load("res://scripts/world/camp_view.gd") as GDScript
	ViewS.fence(bucket)
static func world(host: Node3D) -> void:
	EnvKit.apply(host, Color(0.45, 0.58, 0.62), Color(0.95, 0.86, 0.7), 1.15, Vector3(-18.0, 34.0, -42.0), 0.9)


static func ground(host: Node3D) -> void:
	MeshS.ground(host)


static func outer_grass(host: Node3D) -> void:
	var lay: Node3D = _layout_from_build_host(host)
	var x0: float = float(lay.ground_ox - lay.grass_pad) if lay else float(GROUND_OX - GRASS_PAD)
	var z0: float = float(lay.ground_oz - lay.grass_pad) if lay else float(GROUND_OZ - GRASS_PAD)
	var x1: float = float(lay.ground_ox + lay.ground_w + lay.grass_pad) if lay else float(GROUND_OX + GROUND_W + GRASS_PAD)
	var z1: float = float(lay.ground_oz + lay.ground_d + lay.grass_pad) if lay else float(GROUND_OZ + GROUND_D + GRASS_PAD)
	var ix0: float = float(lay.ground_ox) if lay else float(GROUND_OX)
	var iz0: float = float(lay.ground_oz) if lay else float(GROUND_OZ)
	var ix1: float = float(lay.ground_ox + lay.ground_w) if lay else float(GROUND_OX + GROUND_W)
	var iz1: float = float(lay.ground_oz + lay.ground_d) if lay else float(GROUND_OZ + GROUND_D)
	var y: float = T.FLOOR_Y
	var tex := "res://assets/tiles/grass_field.png"
	var fb := Color(0.34, 0.46, 0.24)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (z0 + iz0) * 0.5), Vector2(x1 - x0, iz0 - z0), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + x1) * 0.5, y, (iz1 + z1) * 0.5), Vector2(x1 - x0, z1 - iz1), tex, fb)
	MeshS.grass_pad(host, Vector3((x0 + ix0) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(ix0 - x0, iz1 - iz0), tex, fb)
	MeshS.grass_pad(host, Vector3((ix1 + x1) * 0.5, y, (iz0 + iz1) * 0.5), Vector2(x1 - ix1, iz1 - iz0), tex, fb)


static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	MeshS.tile_layer(host, tex_path, points, fallback)


static func buildings(host: Node3D) -> void:
	guild(host)
	var lay: Node3D = _layout_from_build_host(host)
	var stall_at: Vector3 = lay.stall_pos() if lay else Vector3(25.0, 1.2, 8.0)
	var stall_box: Vector3 = lay.stall_box if lay else STALL_SIZE
	solid(host, stall_at, stall_box, Color(0.55, 0.35, 0.2), "res://assets/sprites/buildings/stall.png", true)


static func wing_pos() -> Vector3:
	var back: float = HALL_POS.z - HALL_SIZE.z * 0.5
	return Vector3(HALL_POS.x + HALL_SIZE.x * 0.5 + WING_SIZE.x * 0.5 - 0.12, WING_SIZE.y * 0.5, back + WING_SIZE.z * 0.5)


static func guild(host: Node3D) -> void:
	var lay: Node3D = _layout_from_build_host(host)
	var hall_at: Vector3 = lay.hall_pos() if lay else HALL_POS
	var hall_box: Vector3 = lay.hall_box if lay else HALL_SIZE
	var wing_at: Vector3 = lay.wing_pos() if lay else wing_pos()
	var wing_box: Vector3 = lay.wing_box if lay else WING_SIZE
	var hall_body: StaticBody3D = box(host, hall_at, hall_box, Color(0.45, 0.32, 0.22))
	var wing_body: StaticBody3D = box(host, wing_at, wing_box, Color(0.5, 0.38, 0.28))
	var hall_fit: Vector3 = seat(hall_body, hall_box, "res://assets/sprites/buildings/guild.png")
	var wing_fit: Vector3 = seat(wing_body, wing_box, "res://assets/sprites/buildings/guild_reception.png")
	MeshS.wall_box(hall_body, hall_fit, Color(0.45, 0.32, 0.22))
	MeshS.wall_box(wing_body, wing_fit, Color(0.5, 0.38, 0.28))
	face(hall_body, hall_fit, "res://assets/sprites/buildings/guild.png", 0.0, hall_fit.x, 0.34)
	face(wing_body, wing_fit, "res://assets/sprites/buildings/guild_reception.png", 0.0, wing_fit.x, 0.34)
	var hd: float = lay.awning_depth("Hall") if lay else 0.72
	var hs: float = lay.awning_slope("Hall") if lay else 0.08
	var wd: float = lay.awning_depth("Wing") if lay else 0.64
	var ws: float = lay.awning_slope("Wing") if lay else 0.08
	awning(hall_body, hall_fit, hd, hs, hall_fit.y * 0.34, 0.0, 0.0, 0.0)
	awning(wing_body, wing_fit, wd, ws, wing_fit.y * 0.34, 0.0, 0.0, 0.0)
	var hall_tile: float = lay.tile_for("Hall") if lay else TILE_W
	var wing_tile: float = lay.tile_for("Wing") if lay else TILE_W
	var hall_uv: Vector2 = lay.hall_uv_off if lay else Vector2.ZERO
	var wing_uv: Vector2 = lay.wing_uv_off if lay else Vector2.ZERO
	MeshS.gable_on(hall_body, hall_fit, 0.0, 0.55, hall_tile, hall_uv)
	MeshS.gable_on(wing_body, wing_fit, 0.0, 0.48, wing_tile, wing_uv)
static func guild_roofs(host: Node3D) -> void:
	MeshS.guild_roofs(host)


static func box(host: Node3D, pos: Vector3, box_size: Vector3, col: Color) -> StaticBody3D:
	return Roof.box(host, pos, box_size, col)


static func solid(
	host: Node3D, pos: Vector3, box_size: Vector3, col: Color, tex: String, tarp: bool = false
) -> void:
	var body: StaticBody3D = box(host, pos, box_size, col)
	var x0: float = pos.x - box_size.x * 0.5
	var z0: float = pos.z - box_size.z * 0.5
	var lay: Node3D = _layout_from_build_host(host)
	if tarp:
		MeshS.pitched_tarp(body, box_size, 0.0, Vector3(x0, 0.0, z0))
	else:
		roof_plane(
			body,
			Vector3(0.0, box_size.y * 0.5 + 0.03, 0.0),
			Vector2(box_size.x, box_size.z),
			Vector3(x0, 0.0, z0),
			false,
			lay.tile_for("Stall") if lay else TILE_W,
			lay.stall_uv_off if lay else Vector2.ZERO
		)
		face(body, box_size, tex, 0.0, box_size.x)
static func face(
	body: Node3D, box_size: Vector3, tex: String, x_off: float, face_w: float, crop_top: float = 0.0
) -> void:
	if not ResourceLoader.exists(tex):
		return
	var spr := Sprite3D.new()
	spr.texture = load(tex)
	spr.centered = true
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tw := float(maxi(1, spr.texture.get_width()))
	var th := float(maxi(1, spr.texture.get_height()))
	var cap: float = clampf(crop_top, 0.0, 0.6)
	var rh: float = maxf(th * (1.0 - cap), 1.0)
	if cap > 0.01:
		spr.region_enabled = true
		spr.region_rect = Rect2(0.0, th * cap, tw, rh)
	var fw: float = maxf(face_w, 0.2)
	var room: float = maxf(box_size.y * (1.0 - cap), 0.4)
	spr.pixel_size = minf(fw / tw, room / rh)
	var sh: float = spr.pixel_size * rh
	var hem: float = box_size.y * 0.5 - box_size.y * cap
	spr.position = Vector3(x_off, hem - sh * 0.5, box_size.z * 0.5 + 0.01)
	body.add_child(spr)
static func roof_mat(dim: Vector2, world_min: Vector3, tile: float = TILE_W, uv_off: Vector2 = Vector2.ZERO) -> Material:
	return MeshS.roof_mat(dim, world_min, tile, uv_off)


static func roof_plane(
	host: Node3D,
	local: Vector3,
	dim: Vector2,
	world_min: Vector3,
	tarp: bool = false,
	tile: float = TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> void:
	var roof := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dim
	roof.mesh = plane
	roof.position = local
	if tarp:
		roof.material_override = MeshS.tarp_mat(dim, world_min)
	else:
		roof.material_override = roof_mat(dim, world_min, tile, uv_off)
	host.add_child(roof)


static func quiet_shadows(host: Node3D) -> void:
	var stack: Array[Node] = [host]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is DirectionalLight3D:
			var sun := n as DirectionalLight3D
			sun.shadow_enabled = false
		if n is GeometryInstance3D:
			var geo := n as GeometryInstance3D
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for c in n.get_children():
			stack.append(c)

static func awning(
	body: Node3D,
	box_size: Vector3,
	depth: float = 0.48,
	slope: float = 0.10,
	valance: float = 0.16,
	eave: float = ROOF_EAVE,
	inset_l: float = 0.0,
	inset_r: float = 0.0
) -> void:
	MeshS.attach_awning(body, box_size, depth, slope, valance, eave, inset_l, inset_r)
static func _layout_from_build_host(host: Node3D) -> Node3D:
	var n: Node = host
	while n != null:
		if n.has_meta("wdb_layout"):
			var tagged: Node = n.get_meta("wdb_layout") as Node
			if tagged is Node3D:
				return tagged as Node3D
		var lay: Node = n.get_node_or_null("Layout")
		if lay is Node3D:
			return lay as Node3D
		n = n.get_parent()
	return null

static func strip_building_cubes(root: Node) -> int:
	var cut: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		var mi := n as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		print(
			"CAMP_MESH box parent=",
			n.get_parent().name if n.get_parent() else "?",
			" size=",
			sz
		)
		if sz.x < 2.0 or sz.z < 2.0 or sz.y < 1.0:
			continue
		var parent: Node = n.get_parent()
		if parent == null:
			continue
		parent.remove_child(n)
		n.free()
		cut += 1
	print("CAMP_MESH stripped_building_cubes=", cut)
	return cut


static func dump_meshes(root: Node) -> void:
	var stack: Array[Node] = [root]
	var boxes: int = 0
	var sprites: int = 0
	var other: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		if n is Sprite3D:
			sprites += 1
			var spr := n as Sprite3D
			print("CAMP_MESH sprite parent=", n.get_parent().name if n.get_parent() else "?", " pos=", spr.position, " px=", spr.pixel_size)
			continue
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is BoxMesh:
			boxes += 1
			print("CAMP_MESH keep_box parent=", n.get_parent().name if n.get_parent() else "?", " size=", (mi.mesh as BoxMesh).size)
		else:
			other += 1
			print("CAMP_MESH other name=", n.name, " mesh=", mi.mesh.get_class() if mi.mesh else "null")
	print("CAMP_MESH totals boxes=", boxes, " sprites=", sprites, " other=", other)

static func face_height(tex: String, face_w: float) -> float:
	if not ResourceLoader.exists(tex):
		return 3.2
	var img: Texture2D = load(tex)
	var tw: float = float(maxi(1, img.get_width()))
	var th: float = float(maxi(1, img.get_height()))
	return maxf(face_w * th / tw, 1.2)


static func seat(body: StaticBody3D, box_size: Vector3, tex: String) -> Vector3:
	var h: float = face_height(tex, box_size.x) * 0.82
	body.position.y = h * 0.5
	return Vector3(box_size.x, h, box_size.z)
