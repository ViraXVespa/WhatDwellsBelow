extends Object

## Camp build buildings: guild hall and wings, stall solids, awnings, roof planes.

const MeshS := preload("res://scripts/world/camp_build/mesh.gd")
const Util := preload("res://scripts/world/camp_build/build_util.gd")
const Prim := preload("res://scripts/world/camp_build/mesh_prim.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")

const ROOF_EAVE := 0.42
const TILE_W := 3.2

static func guild_hall(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	var hall_at: Vector3 = lay.hall_pos()
	var hall_box: Vector3 = lay.hall_box
	var hall_body: StaticBody3D = Util.box(host, hall_at, hall_box, Color(0.45, 0.32, 0.22))
	var hall_fit: Vector3 = Util.seat(hall_body, hall_box, "res://assets/sprites/buildings/guild.png")
	MeshS.wall_box(hall_body, hall_fit, Color(0.45, 0.32, 0.22))
	Util._slide(hall_body, hall_fit)
	Util.face(hall_body, hall_fit, "res://assets/sprites/buildings/guild.png", 0.0, hall_fit.x, 0.32)
	var hall_valance: float = hall_fit.y * lay.awning_valance("Hall")
	awning(hall_body, hall_fit, lay.awning_depth("Hall"), lay.awning_slope("Hall"), hall_valance, 0.0, 0.0, 0.0)
	MeshS.gable_on(hall_body, hall_fit, 0.0, 0.55, lay.tile_for("Hall"), lay.hall_uv_off)

static func guild_wing(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	var wing_at: Vector3 = lay.wing_pos()
	var wing_box: Vector3 = lay.wing_box
	var wing_body: StaticBody3D = Util.box(host, wing_at, wing_box, Color(0.5, 0.38, 0.28))
	var wing_fit: Vector3 = Util.seat(wing_body, wing_box, "res://assets/sprites/buildings/guild_reception.png")
	MeshS.wall_box(wing_body, wing_fit, Color(0.5, 0.38, 0.28))
	Util._slide(wing_body, wing_fit)
	Util.face(wing_body, wing_fit, "res://assets/sprites/buildings/guild_reception.png", 0.0, wing_fit.x, 0.32)
	var wing_valance: float = wing_fit.y * lay.awning_valance("Wing")
	awning(wing_body, wing_fit, lay.awning_depth("Wing"), lay.awning_slope("Wing"), wing_valance, 0.0, 0.0, 0.0)
	MeshS.gable_on(wing_body, wing_fit, 0.0, 0.48, lay.tile_for("Wing"), lay.wing_uv_off)
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
	if tarp:
		MeshS.pitched_tarp(body, box_size, 0.0, Vector3(x0, 0.0, z0))
		Util.face(body, box_size, tex, 0.0, box_size.x * 0.92)
		Util._counter(body, box_size)
		Util._stall_walls(body, box_size)
		# Full front collision plane
		var front := CollisionShape3D.new()
		front.name = "StallFront"
		var fblock := BoxShape3D.new()
		fblock.size = Vector3(box_size.x * 0.92, box_size.y * 0.75, 0.18)
		front.shape = fblock
		front.position = Vector3(0.0, box_size.y * 0.32, box_size.z * 0.46)
		body.add_child(front)
		# Right wall mesh so bake can shadow it (matches left/right collision)
		var rw := MeshInstance3D.new()
		rw.name = "StallRightWall"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hx := box_size.x * 0.49
		var hy := box_size.y * 0.72
		var hz := box_size.z * 0.49
		var a := Vector3(hx, -box_size.y * 0.5, -hz)
		var b := Vector3(hx, -box_size.y * 0.5, hz)
		var c := Vector3(hx, -box_size.y * 0.5 + hy, hz)
		var d := Vector3(hx, -box_size.y * 0.5 + hy, -hz)
		Prim._quad(st, a, b, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		st.generate_normals()
		rw.mesh = st.commit()
		rw.material_override = Prim._timber(Color(0.42, 0.28, 0.16))
		body.add_child(rw)
		Prim._hit(body, rw.mesh, "StallRightHit")
		Util._blob(body, Vector3(0.0, 0.0, box_size.z * 0.2))
	else:
		roof_plane(
			body,
			Vector3(0.0, box_size.y * 0.5 + 0.03, 0.0),
			Vector2(box_size.x, box_size.z),
			Vector3(x0, 0.0, z0),
			false,
			LayoutS.of(host).tile_for("Stall"),
			LayoutS.of(host).stall_uv_off
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
