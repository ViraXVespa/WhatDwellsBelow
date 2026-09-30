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
    var z0: float = box_size.z * 0.5 + eave + 0.02
    var z1: float = z0 + depth
    var y_back: float = box_size.y * 0.5 - 0.02
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
    var grass: Array = []
    var packed: Array = []
    var path: Array = []
    for z in gd:
        for x in gw:
            var gx: int = ox + x
            var gz: int = oz + z
            var pos := Vector3(float(gx) + 0.5, T.FLOOR_Y, float(gz) + 0.5)
            var in_yard := gx >= 2 and gx <= 30 and gz >= 4 and gz <= 24
            var on_path := (gz >= 13 and gz <= 16 and gx >= 6 and gx <= 26) or (gx >= 15 and gx <= 17 and gz >= 8 and gz <= 22)
            if not in_yard:
                grass.append(pos)
            elif on_path:
                path.append(pos)
            else:
                packed.append(pos)
    tile_layer(host, "res://assets/tiles/grass_field.png", grass, Color(0.34, 0.46, 0.24))
    tile_layer(host, "res://assets/tiles/packed_dirt.png", packed, Color(0.46, 0.42, 0.30))
    tile_layer(host, "res://assets/tiles/plaza_path.png", path, Color(0.44, 0.38, 0.28))
    _fac.outer_grass(host)


static func tile_layer(host: Node3D, tex_path: String, points: Array, fallback: Color) -> void:
	if points.is_empty():
		return
	var mat: Material = GroundShader.material(tex_path, fallback)
	var rects: Array = _points_to_rects(points)
	var i: int = 0
	while i < rects.size():
		var r: Dictionary = rects[i]
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(float(r["sx"]), float(r["sz"]))
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.position = r["c"]
		inst.material_override = mat
		host.add_child(inst)
		i += 1


static func _points_to_rects(points: Array) -> Array:
	var cells: Dictionary = {}
	var used: Dictionary = {}
	var pi: int = 0
	while pi < points.size():
		var v: Vector3 = points[pi]
		var ix: int = int(floor(v.x))
		var iz: int = int(floor(v.z))
		cells[Vector2i(ix, iz)] = v
		pi += 1
	var rects: Array = []
	var keys: Array = cells.keys()
	var ki: int = 0
	while ki < keys.size():
		var k: Vector2i = keys[ki] as Vector2i
		ki += 1
		if used.has(k):
			continue
		var base: Vector3 = cells[k]
		var w: int = 1
		while cells.has(Vector2i(k.x + w, k.y)) and not used.has(Vector2i(k.x + w, k.y)):
			w += 1
		var h: int = 1
		var grow: bool = true
		while grow:
			var x: int = 0
			while x < w:
				var ck := Vector2i(k.x + x, k.y + h)
				if not cells.has(ck) or used.has(ck):
					grow = false
					break
				x += 1
			if grow:
				h += 1
		var x2: int = 0
		while x2 < w:
			var z2: int = 0
			while z2 < h:
				used[Vector2i(k.x + x2, k.y + z2)] = true
				z2 += 1
			x2 += 1
		var sx: float = float(w) * T.TILE
		var sz: float = float(h) * T.TILE
		var c := Vector3(float(k.x) + sx * 0.5, base.y, float(k.y) + sz * 0.5)
		rects.append({"c": c, "sx": sx, "sz": sz})
	return rects


static func _points_to_rects(points: Array) -> Array:
	var cells: Dictionary = {}
	var used: Dictionary = {}
	var pi: int = 0
	while pi < points.size():
		var v: Vector3 = points[pi]
		var ix: int = int(floor(v.x))
		var iz: int = int(floor(v.z))
		cells[Vector2i(ix, iz)] = v
		pi += 1
	var rects: Array = []
	for raw_k in cells.keys():
		var k: Vector2i = raw_k
		if used.has(k):
			continue
		var base: Vector3 = cells[k]
		var w: int = 1
		while cells.has(Vector2i(k.x + w, k.y)) and not used.has(Vector2i(k.x + w, k.y)):
			w += 1
		var h: int = 1
		var grow: bool = true
		while grow:
			var x: int = 0
			while x < w:
				var ck := Vector2i(k.x + x, k.y + h)
				if not cells.has(ck) or used.has(ck):
					grow = false
					break
				x += 1
			if grow:
				h += 1
		var x2: int = 0
		while x2 < w:
			var z2: int = 0
			while z2 < h:
				used[Vector2i(k.x + x2, k.y + z2)] = true
				z2 += 1
			x2 += 1
		var sx: float = float(w) * T.TILE
		var sz: float = float(h) * T.TILE
		var c := Vector3(float(k.x) + sx * 0.5, base.y, float(k.y) + sz * 0.5)
		rects.append({"c": c, "sx": sx, "sz": sz})
	return rects


static func _points_to_rects(points: Array) -> Array:
	var used: Dictionary = {}
	var cells: Dictionary = {}
	for p in points:
		var v: Vector3 = p
		var ix: int = int(floor(v.x))
		var iz: int = int(floor(v.z))
		cells[Vector2i(ix, iz)] = v
	var rects: Array = []
	for key in cells.keys():
		var k: Vector2i = key
		if used.has(k):
			continue
		var y: float = (cells[k] as Vector3).y
		var w: int = 1
		while cells.has(Vector2i(k.x + w, k.y)) and not used.has(Vector2i(k.x + w, k.y)):
			w += 1
		var h: int = 1
		var grow: bool = true
		while grow:
			var x: int = 0
			while x < w:
				var ck := Vector2i(k.x + x, k.y + h)
				if not cells.has(ck) or used.has(ck):
					grow = false
					break
				x += 1
			if grow:
				h += 1
		var x2: int = 0
		while x2 < w:
			var z2: int = 0
			while z2 < h:
				used[Vector2i(k.x + x2, k.y + z2)] = true
				z2 += 1
			x2 += 1
		var sx: float = float(w) * T.TILE
		var sz: float = float(h) * T.TILE
		var c := Vector3(float(k.x) + sx * 0.5, y, float(k.y) + sz * 0.5)
		rects.append({"c": c, "sx": sx, "sz": sz})
	return rects


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


static func guild_roofs(host: Node3D) -> void:
    var _fac = load("res://scripts/world/camp_build.gd")
    var lay: Node3D = _fac._layout_from_build_host(host)
    var hall_at: Vector3 = lay.hall_pos() if lay else HALL_POS
    var hall_box: Vector3 = lay.hall_box if lay else HALL_SIZE
    var eave_h: float = lay.eave_for("Hall") if lay else ROOF_EAVE
    var y: float = hall_at.y + hall_box.y * 0.5 + 0.03
    var hx0: float = hall_at.x - hall_box.x * 0.5
    var hz0: float = hall_at.z - hall_box.z * 0.5
    var hall_node := Node3D.new()
    if lay:
        hall_node.global_transform = lay.roof_hall().global_transform
    else:
        hall_node.position = Vector3(hall_at.x, y, hz0 + (hall_box.z + eave_h) * 0.5)
    host.add_child(hall_node)
    var hall_uv: Vector2 = lay.hall_uv_off if lay else Vector2.ZERO
    var hall_tile: float = lay.tile_for("Hall") if lay else TILE_W
    _fac.roof_plane(
        hall_node,
        Vector3.ZERO,
        Vector2(hall_box.x, hall_box.z + eave_h),
        Vector3(hx0, 0.0, hz0),
        false,
        hall_tile,
        hall_uv
    )
    var wp: Vector3 = lay.wing_pos() if lay else _fac.wing_pos()
    var wing_box: Vector3 = lay.wing_box if lay else WING_SIZE
    var eave_w: float = lay.eave_for("Wing") if lay else ROOF_EAVE
    var wx0: float = wp.x - wing_box.x * 0.5
    var wz0: float = wp.z - wing_box.z * 0.5
    var wing_node := Node3D.new()
    if lay:
        wing_node.global_transform = lay.roof_wing().global_transform
    else:
        wing_node.position = Vector3(wx0 + wing_box.x * 0.5, y + 0.01, wz0 + (wing_box.z + eave_w) * 0.5)
    host.add_child(wing_node)
    var wing_uv: Vector2 = lay.wing_uv_off if lay else Vector2.ZERO
    var wing_tile: float = lay.tile_for("Wing") if lay else TILE_W
    _fac.roof_plane(
        wing_node,
        Vector3.ZERO,
        Vector2(wing_box.x, wing_box.z + eave_w),
        Vector3(wx0, 0.0, wz0),
        false,
        wing_tile,
        wing_uv
    )
