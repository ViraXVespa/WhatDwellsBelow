extends Object







const T := preload("res://scripts/data/tunables.gd")



const WrapShader := preload("res://scripts/graphics/wrap_shader.gd")



const GroundShader := preload("res://scripts/graphics/ground_shader.gd")



const GROUND_W := 36



const GROUND_D := 32



const GROUND_OX := -2



const GROUND_OZ := -2



const GRASS_PAD := 16



const ROOF_EAVE := 0.42



const AWNING_DEPTH := 0.48



const AWNING_SLOPE := 0.10



const AWNING_VALANCE := 0.16



const LightRt := preload("res://scripts/graphics/light_rt.gd")
const TILE_W := 3.2



const HALL_SIZE := Vector3(5.6, 3.4, 4.2)



const WING_SIZE := Vector3(3.8, 2.7, 3.2)



const HALL_POS := Vector3(8.2, 1.7, 6.0)



const PATH_X := 16.5



const PATH_Z := 15.0











static func roof_mat(
	dim: Vector2,
	world_min: Vector3,
	tile: float = TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> Material:
	var mat := wrap_mat(
		"res://assets/tiles/plaza_roof.png",
		dim,
		world_min,
		Color(0.55, 0.14, 0.08),
		Color(1.0, 1.0, 1.0),
		false,
		true,
		tile,
		uv_off
	)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("shade_use", 1.0)
		mat.set_shader_parameter("shade_lo", 1.16)
		mat.set_shader_parameter("shade_hi", 0.58)
		var tile_px: float = tile if tile > 0.05 else 0.62
		if tile_px > 0.7:
			tile_px = 0.62
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / tile_px, dim.y / tile_px))
	return mat
static func tarp_mat(dim: Vector2, world_min: Vector3) -> Material:



	return wrap_mat(



		"res://assets/tiles/plaza_tarp.png",



		dim,



		world_min,



		Color(0.40, 0.46, 0.28),



		Color.WHITE,



		true,



		false



	)











static func awning_mat(dim: Vector2, world_min: Vector3) -> Material:



	return wrap_mat(



		"res://assets/tiles/plaza_awning.png",



		dim,



		world_min,



		Color(0.62, 0.22, 0.16),



		Color.WHITE,



		true,



		false



	)











static func wrap_mat(
	path: String,
	dim: Vector2,
	world_min: Vector3,
	fallback: Color,
	tint: Color,
	single_sheet: bool = false,
	russet: bool = false,
	tile: float = TILE_W,
	uv_off: Vector2 = Vector2.ZERO
) -> Material:
	if not ResourceLoader.exists(path):
		var fb := StandardMaterial3D.new()
		fb.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		fb.albedo_color = fallback
		return fb
	var src: Texture2D = load(path)
	var mat := ShaderMaterial.new()
	mat.shader = WrapShader.wrap_shader()
	mat.set_shader_parameter("albedo_tex", src)
	var use_tile: float = tile if tile > 0.05 else TILE_W
	if single_sheet:
		mat.set_shader_parameter("uv_scale", Vector2.ONE)
		mat.set_shader_parameter("uv_off", Vector2.ZERO)
	else:
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / use_tile, dim.y / use_tile))
		mat.set_shader_parameter(
			"uv_off",
			Vector2(world_min.x / use_tile, world_min.z / use_tile) + uv_off
		)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("russet", 1.0 if russet else 0.0)
	mat.set_shader_parameter("shade_use", 0.0)
	mat.set_shader_parameter("shade_lo", 1.0)
	mat.set_shader_parameter("shade_hi", 1.0)
	return mat
static func attach_awning(
	body: Node3D,
	box_size: Vector3,
	depth: float = AWNING_DEPTH,
	slope: float = AWNING_SLOPE,
	valance: float = AWNING_VALANCE,
	eave: float = ROOF_EAVE,
	inset_l: float = 0.0,
	inset_r: float = 0.0
) -> void:
	var x0: float = -box_size.x * 0.5 + inset_l
	var x1: float = box_size.x * 0.5 + 0.04 - inset_r
	var z0: float = box_size.z * 0.5 + eave + 0.04
	var z1: float = z0 + depth
	var y_back: float = box_size.y * 0.5 + 0.0
	var y_ft: float = y_back - slope
	var y_fb: float = y_ft - valance
	var bl := Vector3(x0, y_back, z0)
	var br := Vector3(x1, y_back, z0)
	var fl := Vector3(x0, y_ft, z1)
	var fr := Vector3(x1, y_ft, z1)
	var vl := Vector3(x0, y_fb, z1)
	var vr := Vector3(x1, y_fb, z1)
	var u0 := Vector2(0.0, 0.0)
	var u1 := Vector2(1.0, 0.0)
	var u2 := Vector2(1.0, 1.0)
	var u3 := Vector2(0.0, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, bl, fl, fr, br, u0, u3, u2, u1)
	_quad(st, fl, fr, vr, vl, u0, u1, u2, u3)
	_tri(st, bl, fl, vl, u0, u1, u2)
	_tri(st, br, vr, fr, u0, u2, u1)
	st.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.mesh = st.commit()
	cloth.material_override = awning_mat(Vector2(maxf(x1 - x0, 0.2), depth), Vector3.ZERO)
	body.add_child(cloth)
	var und := SurfaceTool.new()
	und.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(und, br, fr, fl, bl, u0, u1, u2, u3)
	und.generate_normals()
	var cave := MeshInstance3D.new()
	cave.mesh = und.commit()
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.10, 0.04, 0.03)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	cave.material_override = dark
	body.add_child(cave)
static func _quad(



	st: SurfaceTool,



	p0: Vector3,



	p1: Vector3,



	p2: Vector3,



	p3: Vector3,



	t0: Vector2,



	t1: Vector2,



	t2: Vector2,



	t3: Vector2



) -> void:



	_tri(st, p0, p1, p2, t0, t1, t2)



	_tri(st, p0, p2, p3, t0, t2, t3)











static func _tri(



	st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, t0: Vector2, t1: Vector2, t2: Vector2



) -> void:



	st.set_uv(t0)



	st.add_vertex(p0)



	st.set_uv(t1)



	st.add_vertex(p1)



	st.set_uv(t2)



	st.add_vertex(p2)











static func ground(host: Node3D) -> void:
	var _fac = load("res://scripts/world/camp_build.gd")
	var lay: Node3D = _fac._layout_from_build_host(host)
	var gw: int = int(lay.ground_w) if lay else GROUND_W
	var gd: int = int(lay.ground_d) if lay else GROUND_D
	var ox: int = int(lay.ground_ox) if lay else GROUND_OX
	var oz: int = int(lay.ground_oz) if lay else GROUND_OZ
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(gw), 0.4, float(gd))
	cs.shape = sh
	cs.position = Vector3(float(ox) + float(gw) * 0.5, -0.2, float(oz) + float(gd) * 0.5)
	body.add_child(cs)
	var y: float = T.FLOOR_Y
	# grass frame
	_band(host, ox, oz, ox + gw - 1, 3, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, ox, 25, ox + gw - 1, oz + gd - 1, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, ox, 4, 1, 24, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	_band(host, 31, 4, ox + gw - 1, 24, y, "res://assets/tiles/grass_field.png", Color(0.34, 0.46, 0.24))
	# yard dirt + path plus
	_band(host, 2, 4, 30, 24, y, "res://assets/tiles/packed_dirt.png", Color(0.46, 0.42, 0.30))
	_band(host, 6, 13, 26, 16, y + 0.02, "res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28))
	_band(host, 15, 8, 17, 22, y + 0.02, "res://assets/tiles/plaza_path.png", Color(0.44, 0.38, 0.28))
	_fac.outer_grass(host)


static func _band(host: Node3D, x0: int, z0: int, x1: int, z1: int, y: float, tex_path: String, fallback: Color) -> void:
	if x1 < x0 or z1 < z0:
		return
	var sx: float = float(x1 - x0 + 1) * T.TILE
	var sz: float = float(z1 - z0 + 1) * T.TILE
	var c := Vector3(float(x0) + sx * 0.5, y, float(z0) + sz * 0.5)
	grass_pad(host, c, Vector2(sx, sz), tex_path, fallback)


static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	if points.is_empty():
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	var i: int = 0
	while i < points.size():
		var xf := Transform3D.IDENTITY
		xf.origin = points[i]
		mm.set_instance_transform(i, xf)
		i += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = GroundShader.material(tex_path, fallback)
	host.add_child(inst)


static func grass_pad(



	host: Node3D, center: Vector3, dim: Vector2, tex_path: String, fallback: Color



) -> void:



	if dim.x <= 0.05 or dim.y <= 0.05:



		return



	var mesh := PlaneMesh.new()



	mesh.size = dim



	var inst := MeshInstance3D.new()



	inst.mesh = mesh



	inst.position = center



	inst.material_override = GroundShader.material(tex_path, fallback)



	host.add_child(inst)











static func pitched_roof(
	body: Node3D,
	box_size: Vector3,
	eave: float,
	rise: float,
	world_min: Vector3,
	tile: float,
	uv_off: Vector2
) -> void:
	var hx: float = box_size.x * 0.5 + 0.04
	var zn: float = -box_size.z * 0.5
	var zs: float = box_size.z * 0.5 + eave
	var y_lid: float = box_size.y * 0.5 + 0.03
	var y_ridge: float = y_lid + rise
	var nl := Vector3(-hx, y_ridge, zn)
	var nr := Vector3(hx, y_ridge, zn)
	var sl := Vector3(-hx, y_lid, zs)
	var sr := Vector3(hx, y_lid, zs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := Vector2(0.0, 0.0)
	var u1 := Vector2(0.0, 1.0)
	var u2 := Vector2(1.0, 1.0)
	var u3 := Vector2(1.0, 0.0)
	_quad(st, nl, sl, sr, nr, u0, u1, u2, u3)
	st.generate_normals()
	var fall_h: float = zs - zn
	var fall_len: float = sqrt(fall_h * fall_h + rise * rise)
	var mi := MeshInstance3D.new()
	mi.name = "PitchedRoof"
	mi.mesh = st.commit()
	mi.material_override = roof_mat(Vector2(hx * 2.0, fall_len), world_min, tile, uv_off)
	body.add_child(mi)
static func rumpled_tarp(body: Node3D, box_size: Vector3, eave: float, world_min: Vector3) -> void:
	var hx: float = box_size.x * 0.5 + 0.03
	var zn: float = -box_size.z * 0.5
	var zs: float = box_size.z * 0.5 + eave
	var y0: float = box_size.y * 0.5 + 0.04
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(
		st,
		Vector3(-hx, y0, zn),
		Vector3(-hx, y0, zs),
		Vector3(hx, y0, zs),
		Vector3(hx, y0, zn),
		Vector2(0.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0)
	)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "RumpledTarp"
	mi.mesh = st.commit()
	mi.material_override = tarp_mat(Vector2(box_size.x + eave, box_size.z + eave), world_min)
	body.add_child(mi)
static func _tarp_y(u: float, v: float, y0: float) -> float:
	return (
		y0
		+ 0.045 * sin(u * 9.42478) * sin(v * 6.28318)
		+ 0.02 * sin(u * 18.8496 + 0.7)
		+ 0.015 * sin(v * 12.5664 + 1.1)
	)

static func shed_roof(
	body: Node3D,
	x0: float,
	x1: float,
	zn: float,
	zs: float,
	y_lid: float,
	rise: float,
	world_min: Vector3,
	tile: float,
	uv_off: Vector2
) -> void:
	var y_ridge: float = y_lid + rise
	var nl := Vector3(x0, y_ridge, zn)
	var nr := Vector3(x1, y_ridge, zn)
	var sl := Vector3(x0, y_lid, zs)
	var sr := Vector3(x1, y_lid, zs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := Vector2(0.0, 0.0)
	var u1 := Vector2(0.0, 1.0)
	var u2 := Vector2(1.0, 1.0)
	var u3 := Vector2(1.0, 0.0)
	_quad(st, nl, sl, sr, nr, u0, u1, u2, u3)
	st.generate_normals()
	var fall_h: float = zs - zn
	var fall_len: float = sqrt(fall_h * fall_h + rise * rise)
	var mi := MeshInstance3D.new()
	mi.name = "PitchedRoof"
	mi.mesh = st.commit()
	mi.material_override = roof_mat(Vector2(x1 - x0, fall_len), world_min, tile, uv_off)
	body.add_child(mi)


static func shed_pair(
	body: Node3D,
	spans: Array,
	y_lid: float,
	rise: float,
	world_min: Vector3,
	tile: float,
	uv_off: Vector2
) -> void:
	var y_ridge: float = y_lid + rise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := Vector2(0.0, 0.0)
	var u1 := Vector2(0.0, 1.0)
	var u2 := Vector2(1.0, 1.0)
	var u3 := Vector2(1.0, 0.0)
	var width: float = 0.2
	var fall_len: float = rise
	var xmin: float = 1.0e9
	var xmax: float = -1.0e9
	for raw in spans:
		var s: Dictionary = raw
		xmin = minf(xmin, float(s["x0"]))
		xmax = maxf(xmax, float(s["x1"]))
	for raw2 in spans:
		var sp: Dictionary = raw2
		var x0: float = float(sp["x0"])
		var x1: float = float(sp["x1"])
		var zn: float = float(sp["zn"])
		var zs: float = float(sp["zs"])
		var nl := Vector3(x0, y_ridge, zn)
		var nr := Vector3(x1, y_ridge, zn)
		var sl := Vector3(x0, y_lid, zs)
		var sr := Vector3(x1, y_lid, zs)
		_quad(st, nl, sl, sr, nr, u0, u1, u2, u3)
		width = maxf(width, x1 - x0)
		var fh: float = zs - zn
		fall_len = maxf(fall_len, sqrt(fh * fh + rise * rise))
		var drop: float = 0.22
		_quad(
			trim,
			Vector3(x0, y_lid, zs),
			Vector3(x0, y_lid - drop, zs),
			Vector3(x1, y_lid - drop, zs),
			Vector3(x1, y_lid, zs),
			u0, u1, u2, u3
		)
		_quad(
			trim,
			Vector3(x0, y_ridge, zn),
			Vector3(x0, y_ridge - 0.16, zn),
			Vector3(x1, y_ridge - 0.16, zn),
			Vector3(x1, y_ridge, zn),
			u0, u1, u2, u3
		)
		if absf(x0 - xmin) < 0.05:
			_quad(
				trim,
				Vector3(x0 - 0.06, y_ridge, zn),
				Vector3(x0 - 0.06, y_lid, zs),
				Vector3(x0 - 0.06, y_lid - drop, zs),
				Vector3(x0 - 0.06, y_ridge - 0.14, zn),
				u0, u1, u2, u3
			)
		if absf(x1 - xmax) < 0.05:
			_quad(
				trim,
				Vector3(x1 + 0.06, y_ridge - 0.14, zn),
				Vector3(x1 + 0.06, y_lid - drop, zs),
				Vector3(x1 + 0.06, y_lid, zs),
				Vector3(x1 + 0.06, y_ridge, zn),
				u0, u1, u2, u3
			)
	st.generate_normals()
	trim.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "PitchedRoof"
	mi.mesh = st.commit()
	mi.material_override = roof_mat(Vector2(width, fall_len), world_min, tile, uv_off)
	body.add_child(mi)
	var edge := MeshInstance3D.new()
	edge.name = "RoofTrim"
	edge.mesh = trim.commit()
	var board := StandardMaterial3D.new()
	board.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.albedo_color = Color(0.24, 0.13, 0.08)
	board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	edge.material_override = board
	body.add_child(edge)
static func guild_roofs(_host: Node3D) -> void:
	pass


static func gable_on(body: Node3D, box_size: Vector3, eave: float, rise: float, tile: float, uv_off: Vector2) -> void:
	var hx: float = box_size.x * 0.5
	var hz: float = box_size.z * 0.5
	var y0: float = box_size.y * 0.5
	var ridge: float = y0 + rise
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sl := Vector3(-hx, y0, hz + eave)
	var sr := Vector3(hx, y0, hz + eave)
	var nl := Vector3(-hx, y0, -hz - eave)
	var nr := Vector3(hx, y0, -hz - eave)
	var rl := Vector3(-hx, ridge, 0.0)
	var rr := Vector3(hx, ridge, 0.0)
	st.add_vertex(sl)
	st.add_vertex(sr)
	st.add_vertex(rr)
	st.add_vertex(sl)
	st.add_vertex(rr)
	st.add_vertex(rl)
	st.add_vertex(nr)
	st.add_vertex(nl)
	st.add_vertex(rl)
	st.add_vertex(nr)
	st.add_vertex(rl)
	st.add_vertex(rr)
	st.add_vertex(sl)
	st.add_vertex(rl)
	st.add_vertex(nl)
	st.add_vertex(sr)
	st.add_vertex(nr)
	st.add_vertex(rr)
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "Gable"
	inst.mesh = built
	inst.material_override = roof_mat(Vector2(box_size.x, box_size.z + rise), body.global_position, tile, uv_off)
	body.add_child(inst)
	var hit := CollisionShape3D.new()
	hit.name = "GableHit"
	hit.shape = built.create_trimesh_shape()
	body.add_child(hit)


static func pitched_tarp(body: Node3D, box_size: Vector3, _eave: float, world_min: Vector3) -> void:
	var hx: float = box_size.x * 0.5
	var hz: float = box_size.z * 0.5
	var y_post: float = box_size.y * 0.42
	var ridge: float = y_post + 1.15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sl := Vector3(-hx, y_post, hz + 0.9)
	var sr := Vector3(hx, y_post, hz + 0.9)
	var nl := Vector3(-hx, y_post, -hz)
	var nr := Vector3(hx, y_post, -hz)
	var rl := Vector3(-hx, ridge, 0.15)
	var rr := Vector3(hx, ridge, 0.15)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(sl)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(sr)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(rr)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(sl)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(rr)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(rl)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(nr)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(nl)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(rl)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(nr)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(rl)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(rr)
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "StallPitch"
	inst.mesh = built
	inst.material_override = tarp_mat(Vector2(box_size.x, box_size.z), world_min)
	body.add_child(inst)
	var hit := CollisionShape3D.new()
	hit.name = "StallPitchHit"
	hit.shape = built.create_trimesh_shape()
	body.add_child(hit)


static func wall_box(body: Node3D, box_size: Vector3, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = box_size.x * 0.5
	var hy: float = box_size.y * 0.5
	var hz: float = box_size.z * 0.5
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, -hy, hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(-hx, -hy, -hz))
	st.add_vertex(Vector3(-hx, hy, hz))
	st.add_vertex(Vector3(-hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, -hy, -hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(hx, -hy, hz))
	st.add_vertex(Vector3(hx, hy, -hz))
	st.add_vertex(Vector3(hx, hy, hz))
	st.generate_normals()
	var built: ArrayMesh = st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "Walls"
	inst.mesh = built
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	inst.material_override = mat
	body.add_child(inst)
	var hit := CollisionShape3D.new()
	hit.name = "WallHit"
	hit.shape = built.create_trimesh_shape()
	body.add_child(hit)
