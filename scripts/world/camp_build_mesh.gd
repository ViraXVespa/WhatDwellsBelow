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



const TILE_W := 3.2



const HALL_SIZE := Vector3(5.6, 3.4, 4.2)



const WING_SIZE := Vector3(3.8, 2.7, 3.2)



const HALL_POS := Vector3(8.2, 1.7, 6.0)



const PATH_X := 16.5



const PATH_Z := 15.0











static func roof_mat(



	dim: Vector2, world_min: Vector3, tile: float = TILE_W, uv_off: Vector2 = Vector2.ZERO



) -> Material:



	return wrap_mat(



		"res://assets/tiles/plaza_roof.png",



		dim,



		world_min,



		Color(0.42, 0.16, 0.10),



		Color.WHITE,



		false,



		true,



		tile,



		uv_off



	)











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



	eave: float = ROOF_EAVE



) -> void:



	var half_w: float = box_size.x * 0.5 + 0.04



	var z0: float = box_size.z * 0.5 + eave



	var z1: float = z0 + depth



	var y_back: float = box_size.y * 0.5 + 0.02



	var y_ft: float = y_back - slope



	var y_fb: float = y_ft - valance



	var bl := Vector3(-half_w, y_back, z0)



	var br := Vector3(half_w, y_back, z0)



	var fl := Vector3(-half_w, y_ft, z1)



	var fr := Vector3(half_w, y_ft, z1)



	var vl := Vector3(-half_w, y_fb, z1)



	var vr := Vector3(half_w, y_fb, z1)



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



	cloth.material_override = awning_mat(Vector2(box_size.x, depth), Vector3.ZERO)



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
	var mat: Material = roof_mat(Vector2(hx * 2.0, fall_len), world_min, tile, uv_off)
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		sm.set_shader_parameter("shade_use", 1.0)
		sm.set_shader_parameter("shade_lo", 0.76)
		sm.set_shader_parameter("shade_hi", 1.08)
	var mi := MeshInstance3D.new()
	mi.name = "PitchedRoof"
	mi.mesh = st.commit()
	mi.material_override = mat
	body.add_child(mi)
static func rumpled_tarp(body: Node3D, box_size: Vector3, eave: float, world_min: Vector3) -> void:
	var cols: int = 9
	var rows: int = 7
	var hx: float = box_size.x * 0.5 + 0.03
	var zn: float = -box_size.z * 0.5
	var zs: float = box_size.z * 0.5 + eave
	var y0: float = box_size.y * 0.5 + 0.04
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: int = 0
	while r < rows:
		var c: int = 0
		while c < cols:
			var u0: float = float(c) / float(cols)
			var u1: float = float(c + 1) / float(cols)
			var v0: float = float(r) / float(rows)
			var v1: float = float(r + 1) / float(rows)
			var p00 := Vector3(-hx + 2.0 * hx * u0, _tarp_y(u0, v0, y0), zn + (zs - zn) * v0)
			var p10 := Vector3(-hx + 2.0 * hx * u1, _tarp_y(u1, v0, y0), zn + (zs - zn) * v0)
			var p11 := Vector3(-hx + 2.0 * hx * u1, _tarp_y(u1, v1, y0), zn + (zs - zn) * v1)
			var p01 := Vector3(-hx + 2.0 * hx * u0, _tarp_y(u0, v1, y0), zn + (zs - zn) * v1)
			_quad(st, p00, p01, p11, p10, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0))
			c += 1
		r += 1
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
static func guild_roofs(host: Node3D) -> void:
	pass
