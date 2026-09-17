extends Object

const T := preload("res://scripts/data/tunables.gd")
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

static var _wrap_sh: Shader


static func wrap_shader() -> Shader:
	if _wrap_sh != null:
		return _wrap_sh
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_off = vec2(0.0);
uniform vec3 tint = vec3(1.0);
uniform float russet = 0.0;
void fragment() {
	vec2 uv = fract(UV * uv_scale + uv_off);
	vec3 c = texture(albedo_tex, uv).rgb;
	if (russet > 0.5) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 dark = vec3(0.18, 0.07, 0.05);
		vec3 mid = vec3(0.50, 0.16, 0.10);
		vec3 hi = vec3(0.74, 0.32, 0.18);
		c = mix(dark, mid, smoothstep(0.12, 0.46, l));
		c = mix(c, hi, smoothstep(0.46, 0.80, l));
	} else {
		c *= tint;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	ALPHA = 1.0;
}
"""
	_wrap_sh = sh
	return sh


static func roof_mat(dim: Vector2, world_min: Vector3) -> Material:
	return wrap_mat(
		"res://assets/tiles/plaza_roof.png",
		dim,
		world_min,
		Color(0.42, 0.16, 0.10),
		Color.WHITE,
		false,
		true
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
	russet: bool = false
) -> Material:
	if not ResourceLoader.exists(path):
		var fb := StandardMaterial3D.new()
		fb.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		fb.albedo_color = fallback
		return fb
	var src: Texture2D = load(path)
	var mat := ShaderMaterial.new()
	mat.shader = wrap_shader()
	mat.set_shader_parameter("albedo_tex", src)
	if single_sheet:
		mat.set_shader_parameter("uv_scale", Vector2.ONE)
		mat.set_shader_parameter("uv_off", Vector2.ZERO)
	else:
		mat.set_shader_parameter("uv_scale", Vector2(dim.x / TILE_W, dim.y / TILE_W))
		mat.set_shader_parameter("uv_off", Vector2(world_min.x / TILE_W, world_min.z / TILE_W))
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("russet", 1.0 if russet else 0.0)
	return mat


static func attach_awning(body: Node3D, box_size: Vector3) -> void:
	var half_w: float = box_size.x * 0.5 + 0.04
	var z0: float = box_size.z * 0.5 + ROOF_EAVE + 0.02
	var z1: float = z0 + AWNING_DEPTH
	var y_back: float = box_size.y * 0.5 - 0.02
	var y_ft: float = y_back - AWNING_SLOPE
	var y_fb: float = y_ft - AWNING_VALANCE
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
	cloth.material_override = awning_mat(Vector2(box_size.x, AWNING_DEPTH), Vector3.ZERO)
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
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(float(GROUND_W), 0.4, float(GROUND_D))
	cs.shape = sh
	cs.position = Vector3(16.0, -0.2, 14.0)
	body.add_child(cs)
	var grass: Array = []
	var packed: Array = []
	var path: Array = []
	for z in GROUND_D:
		for x in GROUND_W:
			var gx := GROUND_OX + x
			var gz := GROUND_OZ + z
			var pos := Vector3(float(gx) + 0.5, T.FLOOR_Y, float(gz) + 0.5)
			var in_yard := gx >= 2 and gx <= 30 and gz >= 4 and gz <= 24
			var on_path := (gz >= 13 and gz <= 16 and gx >= 6 and gx <= 26) or (gx >= 15 and gx <= 17 and gz >= 8 and gz <= 22)
			if not in_yard:
				grass.append(pos)
			elif on_path:
				path.append(pos)
			else:
				packed.append(pos)
	tile_layer(host, "res://assets/tiles/plaza_grass.png", grass, Color(0.34, 0.46, 0.24))
	tile_layer(host, "res://assets/tiles/plaza_ground.png", packed, Color(0.46, 0.42, 0.30))
	tile_layer(host, "res://assets/tiles/plaza_path.png", path, Color(0.44, 0.38, 0.28))
	_fac.outer_grass(host)

static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	if points.is_empty():
		return
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(T.TILE, T.TILE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var xf := Transform3D.IDENTITY
		xf.origin = points[i]
		mm.set_instance_transform(i, xf)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color.WHITE
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = fallback
	inst.material_override = mat
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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color.WHITE
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		mat.albedo_color = fallback
	mat.uv1_scale = Vector3(dim.x / T.TILE, dim.y / T.TILE, 1.0)
	inst.material_override = mat
	host.add_child(inst)


static func guild_roofs(host: Node3D) -> void:
	var _fac = load("res://scripts/world/camp_build.gd")
	var y: float = HALL_POS.y + HALL_SIZE.y * 0.5 + 0.03
	var hx0: float = HALL_POS.x - HALL_SIZE.x * 0.5
	var hz0: float = HALL_POS.z - HALL_SIZE.z * 0.5
	var hall_node := Node3D.new()
	hall_node.position = Vector3(HALL_POS.x, y, hz0 + (HALL_SIZE.z + ROOF_EAVE) * 0.5)
	host.add_child(hall_node)
	_fac.roof_plane(hall_node, Vector3.ZERO, Vector2(HALL_SIZE.x, HALL_SIZE.z + ROOF_EAVE), Vector3(hx0, 0.0, hz0))
	var wp: Vector3 = _fac.wing_pos()
	var wx0: float = HALL_POS.x + HALL_SIZE.x * 0.5
	var wz0: float = wp.z - WING_SIZE.z * 0.5
	var wing_node := Node3D.new()
	wing_node.position = Vector3(wx0 + WING_SIZE.x * 0.5, y + 0.01, wz0 + (WING_SIZE.z + ROOF_EAVE) * 0.5)
	host.add_child(wing_node)
	_fac.roof_plane(wing_node, Vector3.ZERO, Vector2(WING_SIZE.x, WING_SIZE.z + ROOF_EAVE), Vector3(wx0, 0.0, wz0))
