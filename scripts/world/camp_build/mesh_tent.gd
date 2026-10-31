extends Object

## Camp mesh tents: awnings, pitched tarps, posts, gable roofs. Sizes, colours and draw order from layout_spec.gd.

const Prim := preload("res://scripts/world/camp_build/mesh_prim.gd")
const Mat := preload("res://scripts/world/camp_build/mesh_mat.gd")

const Spec := preload("res://scripts/world/camp/layout_spec.gd")

static func attach_awning(body: Node3D, box_size: Vector3, depth: float, valance: float) -> void:
	var x0: float = -box_size.x * 0.5
	var x1: float = box_size.x * 0.5
	var z_eave: float = box_size.z * 0.5
	var z_hem: float = box_size.z * 0.5 + depth
	var y_eave: float = box_size.y * 0.5
	var y_hem: float = y_eave - valance
	var tl := Vector3(x0, y_eave, z_eave)
	var top_r := Vector3(x1, y_eave, z_eave)
	var bl := Vector3(x0, y_hem, z_eave)
	var br := Vector3(x1, y_hem, z_eave)
	var hl := Vector3(x0, y_hem, z_hem)
	var hr := Vector3(x1, y_hem, z_hem)
	var u0 := Vector2(0.0, 0.0)
	var u1 := Vector2(1.0, 0.0)
	var u2 := Vector2(1.0, 1.0)
	var u3 := Vector2(0.0, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prim._quad(st, tl, top_r, hr, hl, u0, u1, u2, u3)
	Prim._quad(st, tl, bl, br, top_r, u0, u3, u2, u1)
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var cloth := MeshInstance3D.new()
	cloth.name = "Awning"
	cloth.mesh = built
	cloth.material_override = Mat.awning_mat(Vector2(maxf(x1 - x0, 0.2), depth + valance), Vector3.ZERO)
	body.add_child(cloth)
	Prim._hit(body, built, "AwningHit")
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prim._tri(ends, tl, bl, hl, u0, u1, u2)
	Prim._tri(ends, top_r, hr, br, u0, u2, u1)
	ends.generate_normals()
	var cap := MeshInstance3D.new()
	cap.name = "AwningEnd"
	cap.mesh = ends.commit()
	var plain := StandardMaterial3D.new()
	plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plain.albedo_color = Color(0.72, 0.18, 0.12)
	plain.cull_mode = BaseMaterial3D.CULL_DISABLED
	cap.material_override = plain
	body.add_child(cap)
## The stall tarp (eave at y_eave, body-local) and its four posts at the Layout post rectangle (x, front z, rear z).
static func pitched_tarp(body: Node3D, box_size: Vector3, posts: Vector3, y_eave: float) -> void:
	var hx: float = box_size.x * 0.5
	var hz: float = box_size.z * 0.5
	var ridge: float = y_eave + float(Spec.STALL["rise"])
	var sl := Vector3(-hx, y_eave, hz)
	var sr := Vector3(hx, y_eave, hz)
	var nl := Vector3(-hx, y_eave, -hz)
	var nr := Vector3(hx, y_eave, -hz)
	var rl := Vector3(-hx, ridge, 0.0)
	var rr := Vector3(hx, ridge, 0.0)
	var drop: float = Spec.STALL["drop"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prim._quad(st, rl, rr, sr, sl, Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(1.0, 1.0), Vector2(0.0, 1.0))
	Prim._quad(st, rr, rl, nl, nr, Vector2(1.0, 0.5), Vector2(0.0, 0.5), Vector2(0.0, 0.0), Vector2(1.0, 0.0))
	Prim._quad(st, sl, sr, sr + Vector3(0.0, -drop, 0.04), sl + Vector3(0.0, -drop, 0.04), Vector2(0.0, 0.82), Vector2(1.0, 0.82), Vector2(1.0, 1.0), Vector2(0.0, 1.0))
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "StallPitch"
	inst.mesh = built
	var tarp_mat: Material = Mat.tarp_mat(Vector2(box_size.x, box_size.z), Vector3.ZERO)
	inst.material_override = tarp_mat
	if tarp_mat is ShaderMaterial:
		(tarp_mat as ShaderMaterial).set_shader_parameter("ignore_actor_shadow", 1.0)
		(tarp_mat as ShaderMaterial).render_priority = Spec.DRAW["tarp"]
	inst.sorting_offset = Spec.DRAW["tarp_sort"]
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	body.add_child(inst)
	Prim._hit(body, built, "StallPitchHit")
	var top: float = y_eave - 0.01
	for c: Vector2 in [Vector2(-posts.x, posts.y), Vector2(posts.x, posts.y), Vector2(-posts.x, posts.z), Vector2(posts.x, posts.z)]:
		_post(body, Vector3(c.x, top, c.y), box_size.y)
static func _post(body: Node3D, top: Vector3, box_h: float) -> void:
	var foot: float = -box_h * 0.5 - 0.02  # FLOOR_Y
	var x: float = Spec.STALL["post_half"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(top.x - x, foot, top.z - x)
	var b := Vector3(top.x + x, foot, top.z - x)
	var c := Vector3(top.x + x, foot, top.z + x)
	var d := Vector3(top.x - x, foot, top.z + x)
	var e := Vector3(top.x - x, top.y, top.z - x)
	var f := Vector3(top.x + x, top.y, top.z - x)
	var g := Vector3(top.x + x, top.y, top.z + x)
	var h := Vector3(top.x - x, top.y, top.z + x)
	var u := Vector2.ZERO
	Prim._quad(st, d, c, g, h, u, u, u, u)
	Prim._quad(st, a, e, f, b, u, u, u, u)
	Prim._quad(st, a, d, h, e, u, u, u, u)
	Prim._quad(st, b, f, g, c, u, u, u, u)
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "StallPost"
	inst.mesh = built
	var post_mat = Prim._timber(Spec.STALL["post_col"])
	if post_mat is BaseMaterial3D:
		(post_mat as BaseMaterial3D).render_priority = Spec.DRAW["post"]
	inst.material_override = post_mat
	inst.sorting_offset = Spec.DRAW["post_sort"]
	body.add_child(inst)
	Prim._hit(body, built, "StallPostHit")
static func gable_on(body: Node3D, box_size: Vector3, eave: float, rise: float, tile: float, uv_off: Vector2) -> void:
	var wx: float = box_size.x * 0.5
	var wz: float = box_size.z * 0.5
	var hx: float = wx + eave
	var hz: float = wz + eave
	var y0: float = box_size.y * 0.5
	var ridge: float = y0 + rise
	var sl := Vector3(-hx, y0, hz)
	var sr := Vector3(hx, y0, hz)
	var nl := Vector3(-hx, y0, -hz)
	var nr := Vector3(hx, y0, -hz)
	var rl := Vector3(-hx, ridge, 0.0)
	var rr := Vector3(hx, ridge, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prim._quad(st, rl, rr, sr, sl, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0))
	Prim._quad(st, rr, rl, nl, nr, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0))
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "Gable"
	inst.mesh = built
	var span: float = sqrt(hz * hz + rise * rise)
	inst.material_override = Mat.roof_mat(Vector2(hx * 2.0, span), body.global_position, tile, uv_off)
	body.add_child(inst)
	Prim._hit(body, built, "GableHit")
	_ridge_cap(body, hx, ridge, hz, rise)
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	Prim._tri(ends, Vector3(-wx, y0, wz), Vector3(-wx, y0, -wz), Vector3(-wx, ridge, 0.0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	Prim._tri(ends, Vector3(wx, y0, -wz), Vector3(wx, y0, wz), Vector3(wx, ridge, 0.0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	ends.generate_normals()
	var end_mesh: ArrayMesh = ends.commit()
	var cap := MeshInstance3D.new()
	cap.name = "GableEnd"
	cap.mesh = end_mesh
	cap.material_override = Prim._timber(Spec.TIMBER)
	body.add_child(cap)
	Prim._hit(body, end_mesh, "GableEndHit")

## Timber cap over the ridge line: hides where the two slopes' shingle rows meet (their tile edges never line up).
static func _ridge_cap(body: Node3D, hx: float, ridge: float, hz: float, rise: float) -> void:
	var d: Vector2 = Vector2(hz, -rise).normalized() * 0.14
	var up: float = 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_l := Vector3(-hx - 0.02, ridge + up, 0.0)
	var top_r := Vector3(hx + 0.02, ridge + up, 0.0)
	for s: float in [1.0, -1.0]:
		var bl := Vector3(-hx - 0.02, ridge + up + d.y, d.x * s)
		var br := Vector3(hx + 0.02, ridge + up + d.y, d.x * s)
		if s > 0.0:
			Prim._quad(st, top_l, top_r, br, bl, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
		else:
			Prim._quad(st, top_r, top_l, bl, br, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN)
	st.generate_normals()
	var cap := MeshInstance3D.new()
	cap.name = "RidgeCap"
	cap.mesh = st.commit()
	cap.material_override = Prim._timber(Spec.TIMBER)
	body.add_child(cap)
