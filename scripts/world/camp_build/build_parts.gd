extends Object

## Camp build buildings from the Layout spec (layout_spec.gd): guild hall and wing, the stall's walls, posts, tarp and collision.

const Lamps := preload("res://scripts/world/camp/lamps.gd")
const MeshS := preload("res://scripts/world/camp_build/mesh.gd")
const Tent := preload("res://scripts/world/camp_build/mesh_tent.gd")
const Util := preload("res://scripts/world/camp_build/build_util.gd")
const Prim := preload("res://scripts/world/camp_build/mesh_prim.gd")
const LayoutS := preload("res://scripts/world/camp/layout.gd")
const Spec := preload("res://scripts/world/camp/layout_spec.gd")

static func guild_hall(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	_guild(host, lay, "Hall", lay.hall_pos(), lay.hall_box, lay.hall_uv_off)

static func guild_wing(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	_guild(host, lay, "Wing", lay.wing_pos(), lay.wing_box, lay.wing_uv_off)

## One guild building: walls seated to its face art, slide collision, cropped face with its lamps, awning, gable.
static func _guild(host: Node3D, lay: Node3D, which: String, at: Vector3, box_size: Vector3, uv_off: Vector2) -> void:
	var row: Dictionary = LayoutS.body(which)
	var tex: String = row["face"]
	var body: StaticBody3D = Util.box(host, at, box_size, row["wall"])
	var fit: Vector3 = Util.seat(body, box_size, tex)
	MeshS.wall_box(body, fit, row["wall"])
	Util._slide(body, fit)
	Util.face(body, fit, tex, 0.0, fit.x, row["crop"])
	Lamps.on_face(body.get_child(body.get_child_count() - 1) as Sprite3D, row["crop"], row["lamps"])
	var valance: float = fit.y * lay.awning_valance(which)
	Tent.attach_awning(body, fit, lay.awning_depth(which), valance)
	Tent.gable_on(body, fit, 0.0, row["rise"], lay.tile_for(which), uv_off)

## The stall: tarp and posts, face, counter, one collision block over the post rectangle, and timber walls just
## outside the posts (so the posts sort in front) from the floor to the post tops.
static func stall(host: Node3D) -> void:
	var lay: Node3D = LayoutS.of(host)
	var pos: Vector3 = lay.stall_pos()
	var box_size: Vector3 = lay.stall_box
	var body: StaticBody3D = Util.box(host, pos, box_size, Spec.STALL["wall"])
	var posts: Vector3 = lay.stall_posts()
	Tent.pitched_tarp(body, box_size, posts, lay.stall_eave_y())
	Util.face(body, box_size, Spec.STALL["face"], 0.0, box_size.x * float(Spec.STALL["face_w"]))
	Util._counter(body, box_size)
	var front_z: float = posts.y
	var rear_z: float = posts.z
	var coll := CollisionShape3D.new()
	coll.name = "StallUniform"
	var block := BoxShape3D.new()
	block.size = Vector3(posts.x * 2.0, box_size.y, front_z - rear_z)
	coll.shape = block
	coll.position = Vector3(0.0, 0.0, (front_z + rear_z) * 0.5)
	body.add_child(coll)
	var hx: float = posts.x + float(Spec.STALL["post_half"]) - 0.001
	var foot: float = -pos.y + -0.02  # world FLOOR_Y
	var top: float = lay.stall_eave_y() - 0.01  # the post tops
	_wall(body, "StallRightWall", "StallRightHit", [Vector3(hx, foot, front_z), Vector3(hx, foot, rear_z), Vector3(hx, top, rear_z), Vector3(hx, top, front_z)])
	_wall(body, "StallLeftWall", "StallLeftHit", [Vector3(-hx, foot, rear_z), Vector3(-hx, foot, front_z), Vector3(-hx, top, front_z), Vector3(-hx, top, rear_z)])
	_wall(body, "StallBackWall", "StallBackHit", [Vector3(-hx, foot, rear_z), Vector3(hx, foot, rear_z), Vector3(hx, top, rear_z), Vector3(-hx, top, rear_z)])
	var fz: float = front_z - 0.001  # just behind the face sprite, sealing the opening
	_wall(body, "StallFrontWall", "", [Vector3(-hx, foot - 0.5, fz), Vector3(hx, foot - 0.5, fz), Vector3(hx, top, fz), Vector3(-hx, top, fz)])

static func _wall(body: StaticBody3D, mesh_name: String, hit: String, q: Array) -> void:
	var w := MeshInstance3D.new()
	w.name = mesh_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u := Vector2.ZERO
	Prim._quad(st, q[0], q[1], q[2], q[3], u, u, u, u)
	st.generate_normals()
	w.mesh = st.commit()
	w.material_override = Prim._timber(Spec.TIMBER)
	body.add_child(w)
	if hit != "":
		Prim._hit(body, w.mesh, hit)
