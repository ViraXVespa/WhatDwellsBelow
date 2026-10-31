extends Object

## Camp build buildings from the Layout spec (layout_spec.gd): guild hall and wing, the stall's walls, posts, tarp and collision.

const T := preload("res://scripts/data/tunables.gd")
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
	# Wall tall enough that, seen from the gameplay pitch, the awning hem (awning depth in front) lines up with the
	# cropped face top: the whole painted face shows and the extra wall above it stays behind the awning.
	var face_top: float = Util.face_height(tex, box_size.x) * (1.0 - float(row["crop"])) - 0.08
	# The face sprite stands FACE_Z of the depth forward of the wall plane the awning hangs from: only the rest is ahead.
	var ahead: float = (lay.awning_depth(which) - box_size.z * (Spec.FACE_Z - 0.5)) * tan(deg_to_rad(absf(T.CAM_PITCH)))
	var fit: Vector3 = Util.seat(body, box_size, tex, (face_top + ahead - Spec.AWNING_TUCK) / (1.0 - lay.awning_valance(which)))
	MeshS.wall_box(body, fit, row["wall"])
	Util._slide(body, fit)
	Util.face(body, fit, tex, 0.0, fit.x, row["crop"])
	var face := body.get_child(body.get_child_count() - 1) as Sprite3D  # before the collider: it would be the last child
	# Thin collider on the painted front so the player cannot walk through the wall
	var front_col := CollisionShape3D.new()
	front_col.name = "FrontFaceCollider"
	var front_box := BoxShape3D.new()
	front_box.size = Vector3(fit.x, fit.y, 0.08)
	front_col.shape = front_box
	# Centred on the body (mid-wall): spans ground to wall top, so the player stops in front of the face sprite.
	front_col.position = Vector3(0.0, 0.0, fit.z * 0.5 + 0.04)
	body.add_child(front_col)
	var valance: float = fit.y * lay.awning_valance(which)
	var hem := Vector3(fit.y * 0.5 - valance, fit.z * 0.5 + lay.awning_depth(which), float(row.get("hang_x", 0.0)))
	Lamps.on_face(face, row["crop"], row["lamps"], row.get("hang", Rect2()), hem)
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
	var hx: float = posts.x + float(Spec.STALL["post_half"]) - 0.08  # pull sides in to avoid trap
	var foot: float = -pos.y + -0.02  # world FLOOR_Y
	var top: float = lay.stall_eave_y() - 0.01  # the post tops
	_wall(body, "StallRightWall", "StallRightHit", [Vector3(hx, foot, front_z), Vector3(hx, foot, rear_z), Vector3(hx, top, rear_z), Vector3(hx, top, front_z)])
	_wall(body, "StallLeftWall", "StallLeftHit", [Vector3(-hx, foot, rear_z), Vector3(-hx, foot, front_z), Vector3(-hx, top, front_z), Vector3(-hx, top, rear_z)])
	_wall(body, "StallBackWall", "StallBackHit", [Vector3(-hx, foot, rear_z), Vector3(hx, foot, rear_z), Vector3(hx, top, rear_z), Vector3(-hx, top, rear_z)])
	var fz: float = front_z - 0.001
	_wall(body, "StallFrontWall", "", [Vector3(-hx, foot - 0.5, fz), Vector3(hx, foot - 0.5, fz), Vector3(hx, top, fz), Vector3(-hx, top, fz)])
	# The face art is the front: the wall only casts (live and baked shadow), it is never drawn, so nothing z-fights it.
	var front_wall := body.get_node("StallFrontWall") as MeshInstance3D
	front_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	front_wall.visible = false  # never draw the wood; face sprite is the visible front
	(body.get_node("StallFrontWall") as MeshInstance3D).position.z += 0.005  # bias to stop any residual z-fight

## One stall wall quad (q: bottom-left, bottom-right, top-right, top-left), sun-lit planks like the guild walls.
static func _wall(body: StaticBody3D, mesh_name: String, hit: String, q: Array) -> void:
	var w := MeshInstance3D.new()
	w.name = mesh_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k: float = float(Spec.STALL["plank_m"])
	var uw: float = (q[1] - q[0]).length() / k
	var vh: float = (q[3] - q[0]).length() / k
	Prim._quad(st, q[0], q[1], q[2], q[3], Vector2(0.0, vh), Vector2(uw, vh), Vector2(uw, 0.0), Vector2.ZERO)
	st.generate_normals()
	w.mesh = st.commit()
	w.material_override = _planks()
	body.add_child(w)
	if hit != "":
		Prim._hit(body, w.mesh, hit)

static var _plank_mat: StandardMaterial3D

## Lit timber with vertical plank seams (one texture repeat = Spec.STALL plank_m metres).
static func _planks() -> StandardMaterial3D:
	if _plank_mat != null:
		return _plank_mat
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in 16:
		var board: int = x / 4
		var tone: float = [1.0, 0.9, 1.06, 0.95][board]
		for y in 16:
			var c: Color = Spec.TIMBER * (0.76 if x % 4 == 0 else tone * (0.96 if (x * 7 + y * 3) % 11 == 0 else 1.0))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	_plank_mat = StandardMaterial3D.new()
	_plank_mat.albedo_texture = ImageTexture.create_from_image(img)
	_plank_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plank_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return _plank_mat
