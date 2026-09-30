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
	var ViewS: GDScript = load("res://scripts/world/camp_view.gd") as GDScript
	ViewS.fence(bucket)
static func world(host: Node3D) -> void:
	EnvKit.apply(host, Color(0.45, 0.58, 0.62), Color(0.95, 0.86, 0.7), 1.15, Vector3(-50.0, 30.0, 0.0), 0.9)


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
	wing_box.y = maxf(wing_box.y, 3.8)
	var hall_body: StaticBody3D = box(host, hall_at, hall_box, Color(0.45, 0.32, 0.22))
	var wing_body: StaticBody3D = box(host, wing_at, wing_box, Color(0.5, 0.38, 0.28))
	face(hall_body, hall_box, "res://assets/sprites/buildings/guild.png", 0.0, hall_box.x)
	face(wing_body, wing_box, "res://assets/sprites/buildings/guild_reception.png", 0.0, wing_box.x)
	var hd: float = lay.awning_depth("Hall") if lay else 0.48
	var hs: float = lay.awning_slope("Hall") if lay else 0.10
	var hv: float = lay.awning_valance("Hall") if lay else 0.16
	var he: float = lay.eave_for("Hall") if lay else ROOF_EAVE
	var we: float = lay.eave_for("Wing") if lay else ROOF_EAVE
	awning(hall_body, hall_box, hd, hs, hv, he)
	var hall_tile: float = lay.tile_for("Hall") if lay else TILE_W
	var wing_tile: float = lay.tile_for("Wing") if lay else TILE_W
	var hall_uv: Vector2 = lay.hall_uv_off if lay else Vector2.ZERO
	var wing_uv: Vector2 = lay.wing_uv_off if lay else Vector2.ZERO
	var hx0: float = hall_at.x - hall_box.x * 0.5
	var hz0: float = hall_at.z - hall_box.z * 0.5
	var wx0: float = wing_at.x - wing_box.x * 0.5
	var wz0: float = wing_at.z - wing_box.z * 0.5
	MeshS.pitched_roof(hall_body, hall_box, he, 1.15, Vector3(hx0, 0.0, hz0), hall_tile, hall_uv)
	MeshS.pitched_roof(wing_body, wing_box, we, 1.05, Vector3(wx0, 0.0, wz0), wing_tile, wing_uv)
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
	var eave: float = ROOF_EAVE
	var lay: Node3D = _layout_from_build_host(host)
	if lay:
		eave = lay.eave_for("Stall")
	if tarp:
		MeshS.rumpled_tarp(body, box_size, eave, Vector3(x0, 0.0, z0))
	else:
		roof_plane(
			body,
			Vector3(0.0, box_size.y * 0.5 + 0.03, eave * 0.5),
			Vector2(box_size.x + 0.06, box_size.z + eave),
			Vector3(x0, 0.0, z0),
			false,
			lay.tile_for("Stall") if lay else TILE_W,
			lay.stall_uv_off if lay else Vector2.ZERO
		)
	face(body, box_size, tex, 0.0, box_size.x)
static func face(body: Node3D, box_size: Vector3, tex: String, x_off: float, face_w: float) -> void:
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
	spr.pixel_size = minf(face_w / tw, box_size.y / th)
	spr.position = Vector3(x_off, 0.0, box_size.z * 0.5 + 0.05)
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


static func awning(
	body: Node3D,
	box_size: Vector3,
	depth: float = 0.48,
	slope: float = 0.10,
	valance: float = 0.16,
	eave: float = ROOF_EAVE
) -> void:
	MeshS.attach_awning(body, box_size, depth, slope, valance, eave)


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
