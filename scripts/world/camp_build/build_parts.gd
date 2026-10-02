extends Object

## Camp build buildings: guild hall and wings, stall solids, awnings, roof planes.

const MeshS := preload("res://scripts/world/camp_build/mesh.gd")
const Util := preload("res://scripts/world/camp_build/build_util.gd")

const ROOF_EAVE := 0.42
const TILE_W := 3.2
const HALL_SIZE := Vector3(5.6, 3.4, 4.2)
const WING_SIZE := Vector3(3.8, 2.7, 3.2)
const HALL_POS := Vector3(8.2, 1.7, 6.0)

static func wing_pos() -> Vector3:
	var back: float = HALL_POS.z - HALL_SIZE.z * 0.5
	return Vector3(HALL_POS.x + HALL_SIZE.x * 0.5 + WING_SIZE.x * 0.5 - 0.12, WING_SIZE.y * 0.5, back + WING_SIZE.z * 0.5)

static func guild(host: Node3D) -> void:
	var lay: Node3D = Util._layout_from_build_host(host)
	var hall_at: Vector3 = lay.hall_pos() if lay else HALL_POS
	var hall_box: Vector3 = lay.hall_box if lay else HALL_SIZE
	var wing_at: Vector3 = lay.wing_pos() if lay else wing_pos()
	var wing_box: Vector3 = lay.wing_box if lay else WING_SIZE
	var hall_body: StaticBody3D = Util.box(host, hall_at, hall_box, Color(0.45, 0.32, 0.22))
	var wing_body: StaticBody3D = Util.box(host, wing_at, wing_box, Color(0.5, 0.38, 0.28))
	var hall_fit: Vector3 = Util.seat(hall_body, hall_box, "res://assets/sprites/buildings/guild.png")
	var wing_fit: Vector3 = Util.seat(wing_body, wing_box, "res://assets/sprites/buildings/guild_reception.png")
	MeshS.wall_box(hall_body, hall_fit, Color(0.45, 0.32, 0.22))
	Util._slide(hall_body, hall_fit)
	MeshS.wall_box(wing_body, wing_fit, Color(0.5, 0.38, 0.28))
	Util._slide(wing_body, wing_fit)
	Util.face(hall_body, hall_fit, "res://assets/sprites/buildings/guild.png", 0.0, hall_fit.x, 0.32)
	Util.face(wing_body, wing_fit, "res://assets/sprites/buildings/guild_reception.png", 0.0, wing_fit.x, 0.32)
	var hs: float = lay.awning_slope("Hall") if lay else 0.08
	var ws: float = lay.awning_slope("Wing") if lay else 0.08
	awning(hall_body, hall_fit, 0.42, hs, hall_fit.y * 0.16, 0.0, 0.0, 0.0)
	awning(wing_body, wing_fit, 0.36, ws, wing_fit.y * 0.16, 0.0, 0.0, 0.0)
	var hall_tile: float = lay.tile_for("Hall") if lay else TILE_W
	var wing_tile: float = lay.tile_for("Wing") if lay else TILE_W
	var hall_uv: Vector2 = lay.hall_uv_off if lay else Vector2.ZERO
	var wing_uv: Vector2 = lay.wing_uv_off if lay else Vector2.ZERO
	MeshS.gable_on(hall_body, hall_fit, 0.0, 0.55, hall_tile, hall_uv)
	MeshS.gable_on(wing_body, wing_fit, 0.0, 0.48, wing_tile, wing_uv)
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
static func solid(
	host: Node3D, pos: Vector3, box_size: Vector3, col: Color, tex: String, tarp: bool = false
) -> void:
	var body: StaticBody3D = Util.box(host, pos, box_size, col)
	var x0: float = pos.x - box_size.x * 0.5
	var z0: float = pos.z - box_size.z * 0.5
	var lay: Node3D = Util._layout_from_build_host(host)
	if tarp:
		MeshS.pitched_tarp(body, box_size, 0.0, Vector3(x0, 0.0, z0))
		Util.face(body, box_size, tex, 0.0, box_size.x * 0.92)
		Util._counter(body, box_size)
		Util._stall_walls(body, box_size)
		Util._blob(body, Vector3(0.0, 0.0, box_size.z * 0.2))
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
		Util.face(body, box_size, tex, 0.0, box_size.x)
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
