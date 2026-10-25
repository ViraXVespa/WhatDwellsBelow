extends Object

const LayoutS := preload("res://scripts/world/camp/layout.gd")
const Spec := preload("res://scripts/world/camp/layout_spec.gd")

static var _fence_mat: StandardMaterial3D

static func _slab(host: Node3D) -> Vector4i:
    var lay: Node3D = LayoutS.of(host)
    return Vector4i(int(lay.ground_ox), int(lay.ground_oz), int(lay.ground_w), int(lay.ground_d))

static func fence(host: Node3D) -> void:
    var slab: Vector4i = _slab(host)
    var ox: int = slab.x
    var oz: int = slab.y
    var gw: int = slab.z
    var gd: int = slab.w
    var f: Dictionary = Spec.FENCE
    var y: float = f["y"]
    var h: float = f["h"]
    var t: float = f["t"]
    var i: float = f["inset"]
    fence_run(host, Vector3(float(ox) + float(gw) * 0.5, y, float(oz) + i), Vector3(float(gw), h, t), true)
    fence_run(host, Vector3(float(ox) + float(gw) * 0.5, y, float(oz + gd) - i), Vector3(float(gw), h, t), true)
    fence_run(host, Vector3(float(ox) + i, y, float(oz) + float(gd) * 0.5), Vector3(t, h, float(gd)), false)
    fence_run(host, Vector3(float(ox + gw) - i, y, float(oz) + float(gd) * 0.5), Vector3(t, h, float(gd)), false)

static func fence_run(host: Node3D, pos: Vector3, box_size: Vector3, along_x: bool) -> void:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.position = pos
    host.add_child(body)
    body.add_to_group("hub_fence")
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = box_size
    cs.shape = sh
    body.add_child(cs)
    var span: float = box_size.x if along_x else box_size.z
    var f: Dictionary = Spec.FENCE
    var n: int = maxi(2, int(round(span / float(f["post_step"]))) + 1)
    var wood: StandardMaterial3D = fence_mat()
    var rail_len: float = span - float(f["trim"])
    var rail: Vector2 = f["rail"]
    for ry: float in f["rails"]:
        fence_box(body, fence_rail_size(along_x, rail_len, rail.x, rail.y), Vector3(0.0, ry, 0.0), wood)
    var pw: float = f["post"]
    var py: float = f["post_y"]
    for i in n:
        var u: float = 0.0 if n <= 1 else (float(i) / float(n - 1)) - 0.5
        var off: float = u * (span - float(f["trim"]))
        var ppos: Vector3 = Vector3(off, py, 0.0) if along_x else Vector3(0.0, py, off)
        fence_box(body, Vector3(pw, box_size.y, pw), ppos, wood)

static func fence_rail_size(along_x: bool, length: float, thick: float, tall: float) -> Vector3:
    if along_x:
        return Vector3(length, tall, thick)
    return Vector3(thick, tall, length)

static func fence_box(host: Node3D, box_size: Vector3, local: Vector3, mat: StandardMaterial3D) -> void:
    var vis := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = box_size
    vis.mesh = box_mesh
    vis.position = local
    vis.material_override = mat
    vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    host.add_child(vis)

static func fence_mat() -> StandardMaterial3D:
    if _fence_mat != null:
        return _fence_mat
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.albedo_color = Spec.FENCE["col"]
    if ResourceLoader.exists(Spec.FENCE["tex"]):
        mat.albedo_texture = load(Spec.FENCE["tex"])
        mat.albedo_color = Color.WHITE
    _fence_mat = mat
    return mat
